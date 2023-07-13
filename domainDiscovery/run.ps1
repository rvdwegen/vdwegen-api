using namespace System.Net

# Input bindings are passed in via param block.
param($Request, $TriggerMetadata)

$APIName = $TriggerMetadata.FunctionName
$StatusCode = [HttpStatusCode]::OK

# Write to the Azure Functions log stream.
Write-Host "PowerShell HTTP trigger function processed a request."

# Interact with query parameters or the body of the request.
$domains = $Request.body

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
    # Process data
    $results = $domains | ForEach-Object {
        try {
            $tenantDetails = Invoke-RestMethod -Method GET -Uri "https://api.officegrip.nl/api/tenantDetails?tenant=$($_)"
        } catch {
            $tenantDetails = $null 
        }

        try {
            $mailProvider = ((Invoke-RestMethod -Method GET -Uri "https://dns.google/resolve?name=$($_)&type=mx").Answer.data | ForEach-Object { $Priority, $Hostname = $_.Split(' '); @{ prio = $Priority; Host = $hostname } }).Host
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

        try {
            $exchangeOnline = if ((Invoke-RestMethod -Method GET -Uri "https://dns.google/resolve?name=autodiscover.$($_)&type=cname").Answer.data -eq "autodiscover.outlook.com.") { $true } else { $false }
            $intune = if ((Invoke-RestMethod -Method GET -Uri "https://dns.google/resolve?name=enterpriseregistration.$($_)&type=cname").Answer.data -eq "enterpriseregistration.windows.net.") { $true } else { $false }    
        } catch {
            Write-Warning "Failed to get exo or intune"
        }

        try {
            $kitterman = Invoke-RestMethod -Method POST -Uri 'https://www.kitterman.com/spf/getspf3.py' -Body @{ "serial" = "fred12" ; "domain" = $_ } -ContentType "application/x-www-form-urlencoded"
        } catch {
            Write-Warning "Failed to get kitterman"
        }

        [pscustomobject]@{ 
            domain = $_
            tenantDisplayName = if ($tenantDetails) {$tenantDetails.displayName} else { "N/A" }
            tenantId = if ($tenantDetails) {$tenantDetails.tenantId} else { "N/A" }
            MailProvider = ($mailProviderData | Select-Object -Unique) -join "|"
            spfKitterman = if (($kitterman | select-string "SPF record passed validation test" | Select-Object -First 1)) { "PASS" } else { "FAIL" }
            exchangeOnline = $exchangeOnline
            intune = $intune
            spfKittermanResults = "https://www.kitterman.com/spf/getspf3.py?serial=fred12&domain=$($_)"
            tenantDomains = if ($tenantDetails) {$tenantDetails.tenantDomains -join "|"} else { "N/A" }
        }

        Write-Host "$($_) has been processed"
    }
}
catch {
    $ErrorMessage = $_.Exception.Message
    Write-Warning $_.Exception.Message
    $StatusCode = [HttpStatusCode]::OK
    $Results = "lol $($ErrorMessage)"
}

# Associate values to output bindings by calling 'Push-OutputBinding'.
Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
    StatusCode = $StatusCode
    Body       = @($Results)
})
