using namespace System.Net

# Input bindings are passed in via param block.
param($Request, $TriggerMetadata)

$StatusCode = [HttpStatusCode]::OK

# Write to the Azure Functions log stream.
Write-Host "PowerShell HTTP trigger function processed a request."

# Interact with query parameters or the body of the request.
$user = $Request.Query.user

try {
    # Get the access token using managed identity
    $tokenAuthUri = $env:IDENTITY_ENDPOINT + "?resource=https://outlook.com&api-version=2019-08-01"
    $tokenResponse = Invoke-RestMethod -Method Get -Headers @{"X-IDENTITY-HEADER"=$env:IDENTITY_HEADER} -Uri $tokenAuthUri
    $outlookToken = $tokenResponse.access_token

    $headers = @{
        Authorization = "Bearer $outlookToken"
        Accept        = "application/json"
        "User-Agent"  = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Teams/1.3.00.24755 Chrome/69.0.3497.128 Electron/4.2.12 Safari/537.36"
    }

    $body = @{
        EntityRequests = @(
            @{
                Query = @{
                    QueryString = $user
                    DisplayQueryString = ""
                }
                EntityType = "People"
                Provenances = @("Mailbox", "Directory")
                From = 0
                Size = 500
                Fields = @("Id", "DisplayName", "EmailAddresses", "CompanyName", "JobTitle", "ImAddress", "UserPrincipalName", "ExternalDirectoryObjectId", "PeopleType", "PeopleSubtype", "ConcatenatedId", "Phones", "MRI")
            }
        )
        Cvid = (New-Guid).ToString()
        AppName = "Microsoft Teams"
        Scenario = @{
            Name = "staticbrowse"
        }
    }

    $response = Invoke-RestMethod -Method Post -Uri "https://substrate.office.com/search/api/v1/suggestions" -Headers $headers -Body ($body | ConvertTo-Json -Depth 10) -ContentType "application/json"

    $fullDetails = $response.Groups.Suggestions

    $StatusCode = [HttpStatusCode]::OK
} catch {
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
