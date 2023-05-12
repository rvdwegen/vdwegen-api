using namespace System.Net

# Input bindings are passed in via param block.
param($Request, $TriggerMetadata)

$StatusCode = [HttpStatusCode]::OK

# Write to the Azure Functions log stream.
Write-Host "PowerShell HTTP trigger function processed a request."

# Interact with query parameters or the body of the request.
$license = $Request.Query.license

try {

    $licenseDataURL = "https://download.microsoft.com/download/e/3/e/e3e9faf2-f28b-490a-9ada-c6089a1fc5b0/Product%20names%20and%20service%20plan%20identifiers%20for%20licensing.csv"
    $licenseData = (Invoke-RestMethod -Method GET -Uri $licenseDataURL) | ConvertFrom-Csv | Sort-Object -Property 'GUID' -Unique
    #Set-Location (Get-Item $PSScriptRoot).Parent.FullName
    #$licenseData = Import-Csv -Path licensetable.csv
    
    if ($license -match '(^([0-9A-Fa-f]{8}[-]?[0-9A-Fa-f]{4}[-]?[0-9A-Fa-f]{4}[-]?[0-9A-Fa-f]{4}[-]?[0-9A-Fa-f]{12})$)') {
        $licenseResult = ($licenseData | Where-Object { $_.GUID -eq $license } | Select-Object Product_Display_Name).Product_Display_Name
    } else {
        $licenseResult = ($licenseData | Where-Object { $_.Product_Display_Name -like "*$($license)*" } | Select-Object GUID).GUID
    }

    if (!($licenseResult)) {
        #$StatusCode = [HttpStatusCode]::NotFound
        #$licenseResult = "No license information found"
        $licenseResult = $license
    }

} catch {
    $ErrorMessage = $_.Exception.Message
    $StatusCode = [HttpStatusCode]::BadRequest
    $licenseResult = "$($ErrorMessage)"
}

# Associate values to output bindings by calling 'Push-OutputBinding'.
Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
    StatusCode = $StatusCode
    Body       = @($licenseResult)
})
