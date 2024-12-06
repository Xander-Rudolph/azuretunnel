
function Test-AzCliLogin {
    try {
        az account show --output none 2>$null
        if ($LASTEXITCODE -ne 0) {
            throw
        }
    } catch {
        Write-Error "Please log in to Azure CLI first using 'az login'."
        return $false
    }
    return $true
}