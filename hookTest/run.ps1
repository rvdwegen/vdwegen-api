using namespace System.Net

# Input bindings are passed in via param block.
param($Request, $TriggerMetadata)

$StatusCode = [HttpStatusCode]::OK

if ($Request.Query.validationToken) {
    $response = $Request.Query.validationToken
} else {
    Write-Host "####################################"
    Write-Host "####################################"
    Write-Host $Request
    Write-Host "####################################"
    Write-Host "####################################"
}

# Associate values to output bindings by calling 'Push-OutputBinding'.
Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
    StatusCode = $StatusCode
    Body       = $response
})
