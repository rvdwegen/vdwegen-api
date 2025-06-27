using namespace System.Net

# Input bindings are passed in via param block.
param($Request, $TriggerMetadata)

$StatusCode = [HttpStatusCode]::OK

$env:WEBSITE_HOSTNAME
$env:WEBSITE_HOSTNAME
$env:WEBSITE_HOSTNAME

# Associate values to output bindings by calling 'Push-OutputBinding'.
Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
    StatusCode = $StatusCode
    Body       = ($TriggerMetaData.Headers.'CLIENT-IP').Split(':')[0]
})
