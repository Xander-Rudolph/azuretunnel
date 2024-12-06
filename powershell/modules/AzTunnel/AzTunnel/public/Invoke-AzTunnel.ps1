<#
.SYNOPSIS
    Invoke-AzTunnel is a PowerShell function for establishing a tunnel or managing AKS cluster redirection and kubectl contexts.

.DESCRIPTION
    This function allows you to establish a bastion tunnel to Azure resources, redirect to an AKS cluster, or update the kubectl context.
    
    Subcommands:
        - tunnel: Establishes a bastion tunnel to an Azure resource.
        - aks: Redirects to an AKS cluster and sets up credentials.
        - update-kubectl: Updates the kubectl context for the specified environment.

.PARAMETER Subcommand
    Specifies the subcommand to execute. Valid values are:
    - tunnel: Establish a bastion tunnel.
    - aks: Redirect to an AKS cluster.
    - update-kubectl: Update the kubectl context.

.PARAMETER Context
    Specifies the environment context to use. Valid values are:
    - npd: NPD environment.
    - dev: Development environment.
    - prd: Production environment.

.PARAMETER ClusterName
    Optional parameter used with the 'aks' subcommand in the 'dev' environment. Specifies the AKS cluster name.

.EXAMPLE
    Invoke-AzTunnel -Subcommand tunnel -Context dev
    Establishes a bastion tunnel for the development environment.

.EXAMPLE
    Invoke-AzTunnel -Subcommand aks -Context dev -ClusterName aks1
    Redirects to the 'aks1' cluster in the development environment and sets up credentials.

.EXAMPLE
    Invoke-AzTunnel -Subcommand update-kubectl -Context prd
    Updates the kubectl context for the production environment.
#>
function Invoke-AzTunnel {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet("tunnel", "aks", "update-kubectl")]
        [string]$Subcommand,

        [Parameter(Mandatory = $false)]
        [ValidateSet("npd", "dev", "prd")]
        [string]$Context,

        [Parameter(Mandatory = $false)]
        [string]$ClusterName
    )

    if (($Subcommand -ne "install-cert") -and (-not $Context)) {
        Write-Error "Usage: aztunnel <subcommand> <env> [cluster]"
        return
    }

    if (-not (Test-KubeLogin)) { return }
    if (-not (Test-Kubectl)) { return }
    if (-not (Test-AzCliLogin)) { return }

    $envConfig = $configData.$Context

    if (-not $envConfig) {
        Write-Error "Unknown environment: $Context"
        return
    }

    switch ($Subcommand) {
        "tunnel" {
            az account set --subscription $envConfig.target_subscription_id
            az network bastion tunnel --name $envConfig.bastion_name `
                --resource-group $envConfig.resource_group `
                --target-resource-id $envConfig.target_resource_id `
                --resource-port $envConfig.resource_port `
                --port $envConfig.port
        }
        "aks" {
            az account set --subscription $envConfig.target_subscription_id

            if ($Context -eq "dev" -and $ClusterName) {
                $selectedCluster = $envConfig.clusters | Where-Object { $_.name -eq $ClusterName }
                if (-not $selectedCluster) {
                    Write-Error "Cluster '$ClusterName' not found in environment '$Context'"
                    return
                }
            } else {
                $selectedCluster = $envConfig.clusters[0]
            }

            az aks get-credentials --resource-group $selectedCluster.aks_resource_group `
                --name $selectedCluster.aks_name --overwrite-existing

            kubelogin convert-kubeconfig -l azurecli

            Update-KubectlContext -Context $Context

            $query = "$($envConfig.aks_port):$($selectedCluster.aks_host):443"

            ssh -L $query -N -p $($envConfig.port) aksrelay@localhost
        }
        "update-kubectl" {
            Update-KubectlContext -Context $Context
        }
        default {
            Write-Error "Unknown subcommand: $Subcommand"
            return
        }
    }
}
