using namespace System.Net

# Input bindings are passed in via param block.
param($Request, $TriggerMetadata)

$APIName = $TriggerMetadata.FunctionName
$StatusCode = [HttpStatusCode]::OK

# Write to the Azure Functions log stream.
Write-Host "PowerShell HTTP trigger function processed a request."

# Interact with query parameters or the body of the request.
$addon = $Request.Query.addon

try {

$addonDetails = Invoke-RestMethod -Method GET -Uri "https://microsoftedge.microsoft.com/addons/getproductdetailsbycrxid/$($addon)" | Select-Object name,shortDescription,thumbnail

}
catch {
    $ErrorMessage = $_.Exception.Message
    $StatusCode = [HttpStatusCode]::BadRequest
    $addonDetails = "$($ErrorMessage)"
}

# Associate values to output bindings by calling 'Push-OutputBinding'.
Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
    StatusCode = $StatusCode
    Body       = $addonDetails
})
