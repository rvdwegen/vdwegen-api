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

    $CloudAssignedAadServerData = @{
        ZeroTouchConfig = @{
            ForcedEnrollment = 1
            CloudAssignedTenantDomain = $TenantInformation.defaultDomainName
            CloudAssignedTenantUpn = ""
        }
    } | ConvertTo-Json -Compress
    
    $Profile = [pscustomobject]@{
        Version = 2049
        CloudAssignedTenantId = $TenantInformation.tenantId
        CloudAssignedForcedEnrollment = 1
        CloudAssignedDomainJoinMethod = 0
        CloudAssignedAutopilotUpdateDisabled = 1
        CloudAssignedAutopilotUpdateTimeout = 1800000
        CloudAssignedOobeConfig = 1310
        CloudAssignedAadServerData = $CloudAssignedAadServerData
        CloudAssignedTenantDomain = $TenantInformation.defaultDomainName
        ZtdCorrelationId = (New-Guid).Guid
        CloudAssignedDeviceName = '%SERIAL%'
        Comment_File = "Profile Default"
    }

}
catch {
    Write-Error $_
    $ErrorMessage = $_.Exception.Message
    $StatusCode = [HttpStatusCode]::BadRequest
    $Profile = "Error: $($ErrorMessage)"
}

# Associate values to output bindings by calling 'Push-OutputBinding'.
Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
    StatusCode = $StatusCode
    Body       = $Profile
})
