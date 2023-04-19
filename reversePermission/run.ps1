using namespace System.Net

# Input bindings are passed in via param block.
param($Request, $TriggerMetadata)

$StatusCode = [HttpStatusCode]::OK

# Write to the Azure Functions log stream.
Write-Host "PowerShell HTTP trigger function processed a request."

# Interact with query parameters or the body of the request.
$permission = $Request.Query.permission

Connect-AzAccount -Identity

    $context = [Microsoft.Azure.Commands.Common.Authentication.Abstractions.AzureRmProfileProvider]::Instance.Profile.DefaultContext
    $graphToken = [Microsoft.Azure.Commands.Common.Authentication.AzureSession]::Instance.AuthenticationFactory.Authenticate($context.Account, $context.Environment, $context.Tenant.Id.ToString(), $null, [Microsoft.Azure.Commands.Common.Authentication.ShowDialog]::Never, $null, "https://graph.microsoft.com").AccessToken

#Connect-MgGraph -AccessToken $graphToken

$header = @{
    Authorization = 'bearer {0}' -f $graphToken
    Accept        = "application/json"
}

try {

    $permissionsData = (Invoke-RestMethod -Method GET -Headers $header -Uri "https://graph.microsoft.com/v1.0/servicePrincipals?`$filter=appId eq '00000003-0000-0000-c000-000000000000'&`$select=approles,oauth2PermissionScopes").value

    $oauth2PermissionsData = $permissionsData.oauth2PermissionScopes | Select-Object @{N='id'; E={$_.id}}, @{N='friendlyName'; E={$_.value}}, @{N='shortDescription'; E={$_.adminConsentDisplayName}}, @{N='description'; E={$_.adminConsentDescription}}, @{N='type'; E={"Delegated"}}, @{N='api'; E={"Graph"}}
    $appRolesData = $permissionsData.appRoles | Select-Object @{N='id'; E={$_.id}}, @{N='friendlyName'; E={$_.value}}, @{N='displayName'; E={$_.displayName}}, @{N='shortDescription'; E={$_.description}}, @{N='type'; E={"Application"}}, @{N='api'; E={"Graph"}}
    $combinedPermissionsData = $appRolesData + $oauth2PermissionsData

    if ($permission -match '(^([0-9A-Fa-f]{8}[-]?[0-9A-Fa-f]{4}[-]?[0-9A-Fa-f]{4}[-]?[0-9A-Fa-f]{4}[-]?[0-9A-Fa-f]{12})$)') {
        $permissionResult = ($combinedPermissionsData | Where-Object { $_.id -eq $permission })
    } else {
        $permissionResult = ($combinedPermissionsData | Where-Object { $_.friendlyName -eq $permission })
    }

    if (!($permissionResult)) {
        $StatusCode = [HttpStatusCode]::NotFound
        $permissionResult = "No permission found"
    }
}
catch {
    $ErrorMessage = $_.Exception.Message
    $StatusCode = [HttpStatusCode]::BadRequest
    $permissionResult = "$($ErrorMessage)"
}

# Associate values to output bindings by calling 'Push-OutputBinding'.
Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
    StatusCode = $StatusCode
    Body       = @($permissionResult)
})