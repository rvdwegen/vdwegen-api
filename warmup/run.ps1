# warmup/run.ps1
param($Request, $TriggerMetadata)

## 1. Define the parameters for the token request
$resourceURI = "https://management.azure.com/" # Target resource for the token (ARM)
$miEndpoint = "http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=$($resourceURI)"

## 2. Request the token from the MI endpoint (IMDS)
# Note: The 'Metadata: true' header is mandatory for this internal endpoint
$tokenResponse = Invoke-RestMethod -Method Get -Headers @{"Metadata"="true"} -Uri $miEndpoint

## 3. Extract the actual access token
$accessToken = $tokenResponse.access_token

Write-Host "Successfully obtained access token."



Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
    StatusCode = [HttpStatusCode]::OK
    Body = $accessToken
})
