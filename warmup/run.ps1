# warmup/run.ps1
using namespace System.Net
param($Request, $TriggerMetadata)



Write-Host "Successfully obtained access token. $($accessToken)"

Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
    StatusCode = [HttpStatusCode]::OK
    Body = $accessToken
})
