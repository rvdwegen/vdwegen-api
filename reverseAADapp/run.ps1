using namespace System.Net

# Input bindings are passed in via param block.
param($Request, $TriggerMetadata)

$StatusCode = [HttpStatusCode]::OK

# Write to the Azure Functions log stream.
Write-Host "PowerShell HTTP trigger function processed a request."

# Interact with query parameters or the body of the request.
$appId = $Request.Query.appId

Connect-AzAccount -Identity

$context = [Microsoft.Azure.Commands.Common.Authentication.Abstractions.AzureRmProfileProvider]::Instance.Profile.DefaultContext
$graphToken = [Microsoft.Azure.Commands.Common.Authentication.AzureSession]::Instance.AuthenticationFactory.Authenticate($context.Account, $context.Environment, $context.Tenant.Id.ToString(), $null, [Microsoft.Azure.Commands.Common.Authentication.ShowDialog]::Never, $null, "https://graph.microsoft.com").AccessToken

$headers = @{
    Authorization = 'bearer {0}' -f $graphToken
    Accept        = "application/json"
}

try {
    try {
        $appDetailsRAW = Invoke-RestMethod -Method POST -Headers $headers -Uri "https://graph.microsoft.com/v1.0/servicePrincipals" -Body "{ 'appId': '$($appId)' }" -ContentType "application/Json"
        Invoke-RestMethod -Method DELETE -Headers $headers -Uri "https://graph.microsoft.com/v1.0/servicePrincipals('appId=$($appId)')"
    } catch {
        $appDetailsRAW = Invoke-RestMethod -Method GET -Headers $headers -Uri "https://graph.microsoft.com/v1.0/servicePrincipals('appId=$($appId)')"
    }

    if ($appDetailsRAW) {
        Write-Host "app found"
        $appDetails = @{
            appDisplayName              = $appDetailsRAW.appDisplayName
            appDescription              = $appDetailsRAW.appDescription
            appId                       = $appDetailsRAW.appId
            appOwnerTenantId            = $appDetailsRAW.appOwnerOrganizationId
            #appOwnerDefaultDomainName   =
            #appOwnerDisplayName         = $appDetailsRAW) {} else { '' }
            homepage                    = $appDetailsRAW.homepage
            verifiedPublisherName       = $appDetailsRAW.verifiedPublisherName
        }
    } else {
        $StatusCode = [HttpStatusCode]::NotFound
        $appDetails = "No app found123"
    }
}
catch {
    $ErrorMessage = $_.Exception.Message
    $StatusCode = [HttpStatusCode]::BadRequest
    $appDetails = "lol $($ErrorMessage)"
}

# Associate values to output bindings by calling 'Push-OutputBinding'.
Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
    StatusCode = $StatusCode
    Body       = @($appDetails)
})
