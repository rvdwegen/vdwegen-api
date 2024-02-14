using namespace System.Net

function Get-MicrosoftToken {
    Param(
        # Tenant Id
        [Parameter(Mandatory=$false)]
        [guid]$TenantId,

        # Scope
        [Parameter(Mandatory=$false)]
        [string]$Scope = 'https://graph.microsoft.com/.default',

        # ApplicationID
        [Parameter(Mandatory=$true)]
        [guid]$ApplicationID,

        # ApplicationSecret
        [Parameter(Mandatory=$true)]
        [string]$ApplicationSecret,

        # RefreshToken
        [Parameter(Mandatory=$true)]
        [string]$RefreshToken
    )

    if ($TenantId) {
        $Uri = "https://login.microsoftonline.com/$TenantId/oauth2/v2.0/token"
    }
    else {
        $Uri = "https://login.microsoftonline.com/common/oauth2/v2.0/token"  
    }

    # Define the parameters for the token request
    $Body = @{
        client_id       = $ApplicationID
        client_secret   = $ApplicationSecret
        scope           = $Scope
        refresh_token   = $RefreshToken
        grant_type      = 'refresh_token'    
    }

    $Params = @{
        Uri = $Uri
        Method = 'POST'
        Body = $Body
        ContentType = 'application/x-www-form-urlencoded'
        UseBasicParsing = $true
    }

    try {
        $AuthResponse = (Invoke-WebRequest @Params).Content | ConvertFrom-Json
    } catch {
        throw "Authentication Error Occured $_"
    }

    return $AuthResponse
}

function Get-RedirectURL {
    # Input bindings are passed in via param block.
    param($Request, $TriggerMetadata)

<#     try {
        Connect-AzAccount -Identity

        $urlTableContext = New-AzDataTableContext -TableName 'shorturls' -StorageAccountName 'stourlshort' -ManagedIdentity

        $urlObject = (Get-AzDataTableEntity -Filter "RowKey eq '$($Request.Query.code)'" -context $urlTableContext)

    } catch {
        $_.Exception.Message
        $ErrorMessage = $_.Exception.Message
        $StatusCode = [HttpStatusCode]::Unauthorized
    } #>

    # Associate values to output bindings by calling 'Push-OutputBinding'.
    Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
        StatusCode  = [HttpStatusCode]::Found
        Headers     = @{ Location = "https://www.nu.nl/" }
        Body        = ''
    })

}

Export-ModuleMember -Function @('Get-MicrosoftToken', 'Get-RedirectURL')