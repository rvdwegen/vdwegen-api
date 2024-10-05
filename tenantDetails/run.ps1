using namespace System.Net

# Input bindings are passed in via param block.
param($Request, $TriggerMetadata)

$StatusCode = [HttpStatusCode]::OK

# Write to the Azure Functions log stream.
Write-Host "PowerShell HTTP trigger function processed a request."

# Interact with query parameters or the body of the request.
$tenant = $Request.Query.tenant

try {
    Connect-AzAccount -Identity
    $context = [Microsoft.Azure.Commands.Common.Authentication.Abstractions.AzureRmProfileProvider]::Instance.Profile.DefaultContext
    $graphToken = [Microsoft.Azure.Commands.Common.Authentication.AzureSession]::Instance.AuthenticationFactory.Authenticate($context.Account, $context.Environment, $context.Tenant.Id.ToString(), $null, [Microsoft.Azure.Commands.Common.Authentication.ShowDialog]::Never, $null, "https://graph.microsoft.com").AccessToken

    $header = @{
        Authorization = 'bearer {0}' -f $graphToken
        Accept        = "application/json"
    }
} catch {
    Write-Error $_
    $ErrorMessage = $_.Exception.Message
    $StatusCode = [HttpStatusCode]::BadRequest
    $fullDetails = "Error: $($ErrorMessage)"
}

try {

    try {
        $tenantId = (Invoke-RestMethod -Method GET "https://login.windows.net/$tenant/.well-known/openid-configuration").token_endpoint.Split('/')[3]
    } catch {
        throw "Tenant $($tenantDomain) could not be found"
    }

    if ($TenantId) {
        $TenantInformation = Invoke-RestMethod -Method 'GET' -Headers $header -Uri "https://graph.microsoft.com/beta/tenantRelationships/findTenantInformationByTenantId(tenantId='$TenantId')"
    }

    if ($TenantInformation) {
        try {
            $mailProvider = ((Invoke-RestMethod -Method GET -Uri "https://dns.google/resolve?name=$($TenantInformation.defaultDomainName)&type=mx").Answer.data | ForEach-Object { $Priority, $Hostname = $_.Split(' '); @{ prio = $Priority; Host = $hostname } }).Host
            $MailproviderData = switch -Wildcard ($mailProvider) {
                "*.mail.protection.outlook.com." { "Microsoft 365" }
                "*.google.com." { "Google" }
                "*.sophos.com." { "Sophos" }
                "*.googlemail.com." { "Google" }
                "*.transip.email." { "TransIP" }
                "*.premiumantispam.nl." { "TransIP" }
                "*.basenet.nl." { "BaseNet" }
                "*.ppe-hosted.com." { "ProofPoint" }
                "*.pphosted.com." { "ProofPoint" }
                "*.onlinespamfilter.com." { "Onlinespamfilter.nl" }
                "*.onlinespamfilter.nl." { "Onlinespamfilter.nl" }
                "*.fortimailcloud.com." { "FortiMail" }
                "*.mailprotect.be." { "Combell" }
                "*.mtaroutes.com." { "Mail Assure (N-Able)" }
                "*.spamexperts.net." { "N-Able SpamExperts" }
                "*.spamexperts.com." { "N-Able SpamExperts" }
                "*.antispamcloud.com." { "N-Able SpamExperts" }
                "*.spamexperts.eu." { "N-Able SpamExperts" }
                "*.messagelabs.com." { "Symantec Messaging Security" }
                Default { $_ }
            }
        } catch {
            Write-Warning "Failed to get mailprovider"
        }
    
    }
    
    if ($TenantInformation) {
        $domainsBody = "<?xml version=`"1.0`" encoding=`"utf-8`"?><soap:Envelope xmlns:exm=`"http://schemas.microsoft.com/exchange/services/2006/messages`" xmlns:ext=`"http://schemas.microsoft.com/exchange/services/2006/types`" xmlns:a=`"http://www.w3.org/2005/08/addressing`" xmlns:soap=`"http://schemas.xmlsoap.org/soap/envelope/`" xmlns:xsi=`"http://www.w3.org/2001/XMLSchema-instance`" xmlns:xsd=`"http://www.w3.org/2001/XMLSchema`"><soap:Header><a:Action soap:mustUnderstand=`"1`">http://schemas.microsoft.com/exchange/2010/Autodiscover/Autodiscover/GetFederationInformation</a:Action><a:To soap:mustUnderstand=`"1`">https://autodiscover-s.outlook.com/autodiscover/autodiscover.svc</a:To><a:ReplyTo><a:Address>http://www.w3.org/2005/08/addressing/anonymous</a:Address></a:ReplyTo></soap:Header><soap:Body><GetFederationInformationRequestMessage xmlns=`"http://schemas.microsoft.com/exchange/2010/Autodiscover`"><Request><Domain>$($TenantInformation.defaultDomainName)</Domain></Request></GetFederationInformationRequestMessage></soap:Body></soap:Envelope>"

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
    }
    
    # New API call to retrieve branding details
    $brandingBody = @{
        username = "completelymadeupdoesnthavetobevalid@$($TenantInformation.defaultDomainName)"
    } | ConvertTo-Json

    $brandingHeaders = @{
        "Content-Type" = "application/json"
    }

    $brandingResponse = Invoke-RestMethod -Method Post -Uri "https://login.microsoftonline.com/common/GetCredentialType" -Body $brandingBody -Headers $brandingHeaders

    # Extract UserTenantBranding from the response
    $userTenantBranding = $brandingResponse.EstsProperties.UserTenantBranding
    
    # Check for customCssUrl and load its content
    $aitm = $false
    if ($userTenantBranding.CustomizationFiles.customCssUrl) {
        try {
            $cssContentHeaders = @{
                "Referer" = "https://login.microsoftonline.com"
                "User-Agent" = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36"
            }

            $cssContent = Invoke-WebRequest -Uri $userTenantBranding.CustomizationFiles.customCssUrl -Headers $cssContentHeaders -UseBasicParsing | Select-Object -ExpandProperty Content
            
            # Array of patterns to check
            # $patterns = @(
            #     $TenantInformation.tenantId, # CIPP or equivalent
            #     "dscm.li", # Zolder.io
            #     "catch.eye.security", # eye.security
            #     "dakg4cmpuclai.cloudfront.net" # canarytokens.org
            #     # Add more patterns here as needed, e.g.:
            #     # "another-pattern-to-check",
            #     # "yet-another-pattern"
            # )

            $patterns = @(
                @{
                    detection = $TenantInformation.tenantId
                    friendlyName = "CIPP or CIPP-like"
                },
                @{
                    detection = "dscm.li"
                    friendlyName = "Zolder.io"
                },
                @{
                    detection = "catch.eye.security"
                    friendlyName = "Eye.security"
                },
                @{
                    detection = "dakg4cmpuclai.cloudfront.net"
                    friendlyName = "Canarytokens.org"
                }
            )

            # Check if any pattern matches
            $aitm = $patterns | Where-Object { $cssContent -like "*$($_.detection)*" }

            if ($aitm) {
                Write-Host "AITM detected: $aitm"
            } else {
                Write-Host "AITM not detected"
                Write-Host "CSS Content: $cssContent"
            }
        } catch {
            Write-Warning "Failed to retrieve or process custom CSS content: $_"
        }
    }
    
    $fullDetails = @{
        displayName = $TenantInformation.displayName
        tenantId = $TenantInformation.tenantId
        defaultDomainName = $TenantInformation.defaultDomainName
        mailProvider = ($mailProviderData | Select-Object -Unique)
        tenantDomains = $TenantDomains
        userTenantBranding = $userTenantBranding
        aitm = $aitm.friendlyName
    }

}
catch {
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
