function Update-KubectlContext {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet("npd", "dev", "prd")]
        [string]$Context,
        [Parameter(Mandatory = $false)]
        [string]$configFilePath
    )

    $envConfig = $configData.$Context

    if (-not $envConfig) {
        Write-Error "Environment '$Context' not found in configuration."
        return
    }

    $aksPort = $envConfig.aks_port

    $newUrl = "https://localhost:$aksPort"

    # Retrieve the current context
    $currentContext = kubectl config current-context

    if (-not $currentContext) {
        Write-Error "No current kubectl context found. Please set a context first."
        return
    }

    # Update the cluster server URL for the current context
    kubectl config set-cluster "$currentContext" --server="$newUrl" | Out-Null

    Write-Host "Updated kubectl context '$currentContext' to use $newUrl"
}