function Test-KubeLogin {
    try {
        kubelogin --help 2>$null
        if ($LASTEXITCODE -ne 0) {
            throw
        }
    } catch {
        Write-Error "kubelogin is not installed. Please install kubelogin: https://github.com/Azure/kubelogin"
        return $false
    }
    return $true
}