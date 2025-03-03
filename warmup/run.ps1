# warmup/run.ps1
param($Request, $TriggerMetadata)

# Minimal processing to establish connection
# This can also pre-initialize any expensive operations
$connectionStatus = "ready"

# Optional: Pre-initialize connections or state
# $global:myDbConnection = New-DatabaseConnection

Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
    StatusCode = [HttpStatusCode]::OK
    Headers = @{
        "Content-Type" = "application/json"
        "Cache-Control" = "no-store"
    }
    Body = @{ status = $connectionStatus } | ConvertTo-Json
})
