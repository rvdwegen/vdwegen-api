using namespace System.Net

# Input bindings are passed in via param block.
param($Request, $TriggerMetadata)

$StatusCode = [HttpStatusCode]::OK

# Write to the Azure Functions log stream.
Write-Host "PowerShell HTTP trigger function processed a request."

# Interact with query parameters or the body of the request.
$tenant = $Request.Query.tenant

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
    } elseif ($Tenant -like "www.*" -OR $Tenant -like "http*" -OR $Tenant -like "*/*" -OR $Tenant -like "*@*") {
        throw "Please input just the domain.tld section of $Tenant"
    } else {
        $TenantInformation = Invoke-RestMethod -Method 'GET' -Headers $header -Uri "https://graph.microsoft.com/beta/tenantRelationships/findTenantInformationByDomainName(domainName='$Tenant')" 
    }

    $domainsBody = "<?xml version=`"1.0`" encoding=`"utf-8`"?><soap:Envelope xmlns:exm=`"http://schemas.microsoft.com/exchange/services/2006/messages`" xmlns:ext=`"http://schemas.microsoft.com/exchange/services/2006/types`" xmlns:a=`"http://www.w3.org/2005/08/addressing`" xmlns:soap=`"http://schemas.xmlsoap.org/soap/envelope/`" xmlns:xsi=`"http://www.w3.org/2001/XMLSchema-instance`" xmlns:xsd=`"http://www.w3.org/2001/XMLSchema`"><soap:Header><a:Action soap:mustUnderstand=`"1`">http://schemas.microsoft.com/exchange/2010/Autodiscover/Autodiscover/GetFederationInformation</a:Action><a:To soap:mustUnderstand=`"1`">https://autodiscover-s.outlook.com/autodiscover/autodiscover.svc</a:To><a:ReplyTo><a:Address>http://www.w3.org/2005/08/addressing/anonymous</a:Address></a:ReplyTo></soap:Header><soap:Body><GetFederationInformationRequestMessage xmlns=`"http://schemas.microsoft.com/exchange/2010/Autodiscover`"><Request><Domain>$Tenant</Domain></Request></GetFederationInformationRequestMessage></soap:Body></soap:Envelope>"

    # Create the headers
    $domainsHeaders = @{
        "Content-Type" = "text/xml; charset=utf-8"
        "SOAPAction" =   '"http://schemas.microsoft.com/exchange/2010/Autodiscover/Autodiscover/GetFederationInformation"'
        "User-Agent" =   "AutodiscoverClient"
    }
    # Invoke
    $response = Invoke-RestMethod -UseBasicParsing -Method Post -uri "https://autodiscover-s.outlook.com/autodiscover/autodiscover.svc" -Body $domainsBody -Headers $domainsHeaders

    # Return
    $TenantDomains = $response.Envelope.body.GetFederationInformationResponseMessage.response.Domains.Domain | Sort-Object

    $fullDetails = @{
        displayName = $TenantInformation.displayName
        tenantId = $TenantInformation.tenantId
        defaultDomainName = $TenantInformation.defaultDomainName
        tenantDomains = $TenantDomains
    }

}
catch {
Write-Host $_
Write-Error $_
    $ErrorMessage = $_.Exception.Message
    $StatusCode = [HttpStatusCode]::BadRequest
    $fullDetails = "Error: $($ErrorMessage)"
}

# Associate values to output bindings by calling 'Push-OutputBinding'.
Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
    StatusCode = $StatusCode
    Body       = $fullDetails
})
