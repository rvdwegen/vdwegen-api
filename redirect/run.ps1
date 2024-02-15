using namespace System.Net

# Input bindings are passed in via param block.
param($Request, $TriggerMetadata)

$randomSlug = (("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789").ToCharArray() | Get-Random -Count 8) -Join ""


try {
    Connect-AzAccount -Identity
} catch {
    $_.Exception.Message
    $ErrorMessage = $_.Exception.Message
    $StatusCode = [HttpStatusCode]::Unauthorized
}

$urlTableContext = New-AzDataTableContext -TableName 'shorturls' -StorageAccountName 'stourlshort' -ManagedIdentity

$urlObject = (Get-AzDataTableEntity -Filter "RowKey eq '$($Request.Query.code)'" -context $urlTableContext)

# Associate values to output bindings by calling 'Push-OutputBinding'.
Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
    StatusCode  = [HttpStatusCode]::Found
    Headers     = @{ Location = $urlObject.url }
    Body        = ''
})
