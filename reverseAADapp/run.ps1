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
        $appDetailsRAW = Invoke-RestMethod -Method POST -Headers $headers -Uri "https://graph.microsoft.com/v1.0/servicePrincipals" -Body "{ `"appId`": `"$($appId)`" }" -ContentType "application/Json"
        Invoke-RestMethod -Method DELETE -Headers $headers -Uri "https://graph.microsoft.com/v1.0/servicePrincipals(appId='$($appId)')"
    } catch {
        $appDetailsRAW = Invoke-RestMethod -Method GET -Headers $headers -Uri "https://graph.microsoft.com/v1.0/servicePrincipals(appId='$($appId)')"
    }

    if ($appDetailsRAW) {
    
        $ownerTenantDetails = Invoke-RestMethod -Method "GET" -Headers $headers -Uri "https://graph.microsoft.com/beta/tenantRelationships/findTenantInformationByTenantId(tenantId='$($appDetailsRAW.appOwnerOrganizationId)')"
    
        $microsoftTenants = "72f988bf-86f1-41af-91ab-2d7cd011db47|a942cf59-f3c6-4338-acac-d26c18783a46|73da091f-a58d-405f-9015-9bd386425255|f8cdef31-a31e-4b4a-93e4-5f571e91255a"
    
        $appDetails = [ordered]@{
            appDisplayName              = $appDetailsRAW.appDisplayName
            appDescription              = $appDetailsRAW.appDescription
            appId                       = $appDetailsRAW.appId
            appOwnerTenantId            = $appDetailsRAW.appOwnerOrganizationId
            appOwnerDefaultDomainName   = $ownerTenantDetails.defaultDomainName
            appOwnerDisplayName         = $ownerTenantDetails.displayName
            appOwnerMicrosoft           = if ($appDetailsRAW.appOwnerOrganizationId -match $microsoftTenants) { $true } else { $false }
            homepage                    = $appDetailsRAW.homepage
            verifiedPublisherName       = $appDetailsRAW.verifiedPublisherName
        }
    } else {
        $StatusCode = [HttpStatusCode]::NotFound
        $appDetails = "No app found"
    }
}
catch {
    $ErrorMessage = $_.Exception.Message
    $StatusCode = [HttpStatusCode]::BadRequest
    $appDetails = "$($ErrorMessage)"
}

# Associate values to output bindings by calling 'Push-OutputBinding'.
Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
    StatusCode = $StatusCode
    Body       = @($appDetails)
})
