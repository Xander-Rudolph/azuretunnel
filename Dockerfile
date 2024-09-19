# Use the latest Azure CLI alpine based image
FROM mcr.microsoft.com/azure-cli 

# Install required tools using apk
RUN apk update && apk add --no-cache \
    net-tools \
    jq \
    openssh-client

# Install aks tools
RUN az aks install-cli
# when querying bastion another extension is required
RUN az config set extension.use_dynamic_install=yes_without_prompt 
RUN az extension add --upgrade -n bastion

# Add the entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Default environment variables
ENV ENVIRONMENT=""
ENV REGION=""
ENV VM_PREFIX=""
ENV PORT=50081
ENV ROUTING_PORT=50080
ENV RESOURCE_SSH_PORT=22
ENV AZURE_CLIENT_ID=""
ENV AZURE_TENANT_ID=""
ENV AZURE_CLIENT_SECRET=""
ENV SUBSCRIPTION_ID=""

EXPOSE ${PORT} ${ROUTING_PORT}
# Set the entrypoint script to run when the container starts
ENTRYPOINT ["/entrypoint.sh"]
