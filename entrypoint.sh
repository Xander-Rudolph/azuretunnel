#!/bin/bash
# Exit on any error
set -e

# Function to check if logged into az cli
az account show &> /dev/null
if [ $? -eq 0 ]; then
  echo "Already logged in..."
elif [[ -n "$AZURE_CLIENT_ID" && -n "$AZURE_CLIENT_SECRET" && -n "$AZURE_TENANT_ID" ]]; then
  # Attempt to login using a service principal
  az login --service-principal -u "$AZURE_CLIENT_ID" -p "$AZURE_CLIENT_SECRET" --tenant "$AZURE_TENANT_ID"
  if [ $? -ne 0 ]; then
    echo "ERROR: Service principal login failed."
    exit 1
  fi
else
  echo "No service principal provided... attempting device code login"
  # Set a timeout duration, e.g., 300 seconds (5 minutes)
  timeout 300 az login --use-device-code --allow-no-subscriptions
  if [ $? -eq 124 ]; then
    echo "ERROR: Login timed out."
    exit 1
  elif [ $? -ne 0 ]; then
    echo "ERROR: Device code login failed."
    exit 1
  else 
    echo "ERROR: I dunno... $?."
    exit 1
  fi
fi

if [[ -n "$SUBSCRIPTION_ID" ]]; then
    az account set --subscription "$SUBSCRIPTION_ID"
    echo "Subscription set to: $SUBSCRIPTION_ID"
else
    echo "Subscription ID is not set. Setting to current subscription."
    SUBSCRIPTION_ID=$(az account show --query "id" -o tsv)
    echo "Subscription set to: $SUBSCRIPTION_ID"
fi

# Find a jump box within the specified environment and region
echo "Getting jump host..."
VM_FILTER=$(echo "$VM_PREFIX" | tr '[:upper:]' '[:lower:]')  # Convert to lowercase
vmData=$(az vm list --query "[?tags.environment == '$ENVIRONMENT' && location == '$REGION' && contains(name, '$VM_FILTER')] | [0].{name: name, id: id}" --output tsv)
VM_NAME=$(echo "$vmData" | cut -f1)
VM_ID=$(echo "$vmData" | cut -f2)

# Check if a VM was found
if [ -z "$VM_NAME" ]; then
  echo "No suitable VM found for environment $ENVIRONMENT and region $REGION."
  exit 1
fi

# Find a bastion within the specified environment and region
echo "Getting bastion..."
bastionData=$(az network bastion list --query "[?tags.environment == '$ENVIRONMENT' && location == '$REGION'] | [0].{name: name, resourceGroup: resourceGroup}" --output tsv)
BASTION_NAME=$(echo "$bastionData" | cut -f1)
BASTION_RESOURCE_GROUP=$(echo "$bastionData" | cut -f2)

# Check if a Bastion host was found
if [ -z "$BASTION_NAME" ]; then
  echo "No suitable Azure Bastion found for environment $ENVIRONMENT and region $REGION."
  exit 1
fi

# Check if .kube directory exists
if [ -d "$HOME/.kube" ]; then
  echo ".kube directory found. Updating mapping..."

  # Find the AKS clusters with the specified environment and region
  clusterData=$(az aks list --query "[?tags.environment == '$ENVIRONMENT' && location == '$REGION'] | [0].{name: name, resourceGroup:resourceGroup}" --output tsv)
  CLUSTER_NAME=$(echo "$clusterData" | cut -f1)
  CLUSTER_RESOURCE_GROUP=$(echo "$clusterData" | cut -f2)

  # Check if an AKS cluster was found
  if [ -z "$CLUSTER_NAME" ]; then
    echo "No suitable AKS cluster found for environment $ENVIRONMENT and region $REGION."
    exit 1
  fi

  # Retrieve the current context
  current_context=$(kubectl config current-context 2>/dev/null)
  if [ -z "$current_context" ]; then
    echo "No current kubectl context found. Setting context for $CLUSTER_NAME."
    az aks get-credentials --name "$CLUSTER_NAME" --resource-group $CLUSTER_RESOURCE_GROUP --overwrite-existing
  else
    echo "Current context is $current_context."
  fi

  # Get the current user's Azure AD token
  echo "Checking permissions for user..."
  aadToken=$(az account get-access-token --resource https://management.azure.com --query accessToken -o tsv)
  username=$(az ad signed-in-user show --query userPrincipalName -o tsv)

  # Check Kubernetes access for the current user
  az role assignment list --subscription $SUBSCRIPTION_ID --query '[].{Scope:scope, Role:roleDefinitionName}' -o table

  # Update the cluster server URL for the current context
  new_url="https://localhost:$ROUTING_PORT"
  kubectl config set-cluster "$current_context" --server="$new_url"
  echo "Updated kubectl context '$current_context' to use $new_url"
fi

echo "Preparing connection..."
az network bastion tunnel --name "$BASTION_NAME" \
                                --resource-group "$BASTION_RESOURCE_GROUP" \
                                --target-resource-id "$VM_ID" \
                                --resource-port "$RESOURCE_SSH_PORT" \
                                --port "$PORT" &

# do I need to wait a few seconds?
sleep 5

# Setup the SSH tunnel to redirect requests to Kubernetes API server
# ROUTING_PORT=8080
RESOURCE_SSH_PORT=8081
echo "About to run the command:"$'\n\t'"ssh -o StrictHostKeyChecking=no -L 127.0.0.1:$ROUTING_PORT:$CLUSTER_NAME:443 -N -p $RESOURCE_SSH_PORT $USER@localhost"
ssh -o StrictHostKeyChecking=no -L 127.0.0.1:$ROUTING_PORT:$CLUSTER_NAME:443 -N -p $RESOURCE_SSH_PORT $USER@localhost

# Keep the tunnel open; use CTRL+C to close
while true; do sleep 30; done;
