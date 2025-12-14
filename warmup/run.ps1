# warmup/run.ps1
using namespace System.Net
param($Request, $TriggerMetadata)

# 1. Check for the IDENTITY_ENDPOINT environment variable provided by the Azure host
$miEndpoint = $env:IDENTITY_ENDPOINT
$miSecret = $env:IDENTITY_HEADER
$resourceURI = "https://management.azure.com/"

if (-not $miEndpoint -or -not $miSecret) {
    throw "Managed Identity environment variables (IDENTITY_ENDPOINT/IDENTITY_HEADER) not found. Is Managed Identity enabled on the Function App?"
}

# 2. Construct the Uri for the token request
$tokenUri = "$($miEndpoint)?resource=$($resourceURI)&api-version=2019-08-01"

# 3. Prepare headers using the required secret/header provided by the host
# Note: The 'X-IDENTITY-HEADER' replaces the 'Metadata: true' from the IMDS call
$headers = @{
    "X-IDENTITY-HEADER" = $miSecret
}

# 4. Request the token using the host-provided endpoint and secret
$tokenResponse = Invoke-RestMethod -Method Get -Headers $headers -Uri $tokenUri

# 5. Extract the access token
$accessToken = $tokenResponse.access_token

Write-Host "Successfully obtained access token. $($accessToken)"

Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
    StatusCode = [HttpStatusCode]::OK
    Body = $accessToken
})
