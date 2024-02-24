using namespace System.Net

# Input bindings are passed in via param block.
param($Request, $TriggerMetadata)

$APIName = $TriggerMetadata.FunctionName
$StatusCode = [HttpStatusCode]::OK

# Write to the Azure Functions log stream.
Write-Host "PowerShell HTTP trigger function processed a request."

# Interact with query parameters or the body of the request.
$Tenant = $Request.Query.Tenant

# previous versions of Microsoft.Graph.Authentication module
Connect-AzAccount -Identity

    $context = [Microsoft.Azure.Commands.Common.Authentication.Abstractions.AzureRmProfileProvider]::Instance.Profile.DefaultContext
    $graphToken = [Microsoft.Azure.Commands.Common.Authentication.AzureSession]::Instance.AuthenticationFactory.Authenticate($context.Account, $context.Environment, $context.Tenant.Id.ToString(), $null, [Microsoft.Azure.Commands.Common.Authentication.ShowDialog]::Never, $null, "https://graph.microsoft.com").AccessToken

#Connect-MgGraph -AccessToken $graphToken

$header = @{
    Authorization = 'bearer {0}' -f $graphToken
    Accept        = "application/json"
}

try {
    if ($Tenant -match '(^([0-9A-Fa-f]{8}[-]?[0-9A-Fa-f]{4}[-]?[0-9A-Fa-f]{4}[-]?[0-9A-Fa-f]{4}[-]?[0-9A-Fa-f]{12})$)') {
        $TenantInformation = Invoke-RestMethod -Method 'GET' -Headers $header -Uri "https://graph.microsoft.com/beta/tenantRelationships/findTenantInformationByTenantId(tenantId='$Tenant')"
        #$TenantInformation = Invoke-MgGraphRequest -Method 'GET' -Uri "https://graph.microsoft.com/beta/tenantRelationships/findTenantInformationByTenantId(tenantId='$Tenant')"
    } elseif ($Tenant -like "www.*" -OR $Tenant -like "http*" -OR $Tenant -like "*/*" -OR $Tenant -like "*@*") {
        throw "Please input just the domain.tld section of $Tenant"
    } else {
        $TenantInformation = Invoke-RestMethod -Method 'GET' -Headers $header -Uri "https://graph.microsoft.com/beta/tenantRelationships/findTenantInformationByDomainName(domainName='$Tenant')" 
        #$TenantInformation = Invoke-MgGraphRequest -Method 'GET' -Uri "https://graph.microsoft.com/beta/tenantRelationships/findTenantInformationByDomainName(domainName='$Tenant')" 
    }
}
catch {
    $ErrorMessage = $_.Exception.Message
    $StatusCode = [HttpStatusCode]::BadRequest
    $TenantInformation = "$($ErrorMessage)"
}

# Associate values to output bindings by calling 'Push-OutputBinding'.
Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
    StatusCode = $StatusCode
    Body       = $TenantInformation
})
