using namespace System.Net

# Input bindings are passed in via param block.
param($Request, $TriggerMetadata)

try {
    Connect-AzAccount -Identity

    $urlTableContext = New-AzDataTableContext -TableName 'shorturls' -StorageAccountName 'stourlshort' -ManagedIdentity

    $urlObject = (Get-AzDataTableEntity -Filter "RowKey eq '$($Request.Query.code)'" -context $urlTableContext)

} catch {
    $_.Exception.Message
    $_.Exception.Message
    $ErrorMessage = $_.Exception.Message
    $StatusCode = [HttpStatusCode]::Unauthorized
}

# Associate values to output bindings by calling 'Push-OutputBinding'.
Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
    StatusCode  = [HttpStatusCode]::Found
    Headers     = @{ Location = $urlObject.url }
    Body        = ''
})
