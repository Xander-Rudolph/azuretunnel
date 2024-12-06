function Test-Kubectl {
    try {
        kubectl --help 2>$null
        if ($LASTEXITCODE -ne 0) {
            throw
        }
    } catch {
        Write-Error "kubectl is not installed. Please install kubectl: az aks install-cli"
        return $false
    }
    return $true
}