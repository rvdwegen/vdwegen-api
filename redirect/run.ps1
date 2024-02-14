using namespace System.Net

# Input bindings are passed in via param block.
param($Request, $TriggerMetadata)

switch ($Request.Query.urlcode) {
    AAA { $url = "https://nu.nl/" }
    BBB { $url = "https://tweakers.net/" }
    CCC { $url = "https://reddit.com/" }
    Default {}
}

#$url = "https://nu.nl/"

# Associate values to output bindings by calling 'Push-OutputBinding'.
Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
    StatusCode  = [HttpStatusCode]::Found
    Headers     = @{ Location = $url }
    Body        = ''
})
