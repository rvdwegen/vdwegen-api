using namespace System.Net

# Input bindings are passed in via param block.
param($Request, $TriggerMetadata)

$StatusCode = [HttpStatusCode]::OK

# Write to the Azure Functions log stream.
Write-Host "PowerShell HTTP trigger function processed a request."

# Interact with query parameters or the body of the request.
$aadPermission = $Request.Query.aadPermission

Connect-AzAccount -Identity

$context = [Microsoft.Azure.Commands.Common.Authentication.Abstractions.AzureRmProfileProvider]::Instance.Profile.DefaultContext
$graphToken = [Microsoft.Azure.Commands.Common.Authentication.AzureSession]::Instance.AuthenticationFactory.Authenticate($context.Account, $context.Environment, $context.Tenant.Id.ToString(), $null, [Microsoft.Azure.Commands.Common.Authentication.ShowDialog]::Never, $null, "https://graph.microsoft.com").AccessToken

$headers = @{
    Authorization = 'bearer {0}' -f $graphToken
    Accept        = "application/json"
}

try {

    $allRoleDetails = (Invoke-RestMethod -Method GET -Uri "https://graph.microsoft.com/beta/roleManagement/directory/roleDefinitions?`$top=500&`$filter=(isBuiltIn eq true)" -Headers $headers).value

    $roleDetails = $allRoleDetails | Where-Object { $_.rolePermissions.allowedResourceActions -eq $aadPermission }

    if (!($roleDetails)) {
        $StatusCode = [HttpStatusCode]::NotFound
        $roleDetails = "No license information found"
    }
}
catch {
    $ErrorMessage = $_.Exception.Message
    $StatusCode = [HttpStatusCode]::BadRequest
    $roleDetails = "$($ErrorMessage)"
}

# Associate values to output bindings by calling 'Push-OutputBinding'.
Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
    StatusCode = $StatusCode
    Body       = @($roleDetails)
})
