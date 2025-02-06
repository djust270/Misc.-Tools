function Get-MSOauthToken {
<#
.SYNOPSIS
Gets an oauth token for Microsoft APIs.

.DESCRIPTION
Gets an oauth token for Microsoft APIs using the specified client id, scope, and tenant id.

.PARAMETER TenantId
The tenant id to use when getting the token.

.PARAMETER Scope
The scope of the token.

.PARAMETER ClientId
The client id to use when getting the token.

.PARAMETER ClientSecret
The client secret to use when getting the token.

.PARAMETER RefreshToken
The refresh token to use when getting the token.

.EXAMPLE
Get-MSOauthToken -ClientId 1950a258-227b-4e31-a9cf-717495945fc2 -Scope 'https://graph.microsoft.com/.default'

.EXAMPLE
Get-MSOauthToken -ClientId 1950a258-227b-4e31-a9cf-717495945fc2 -Scope 'https://graph.microsoft.com/.default' -RefreshToken $RefreshToken

#>
    [cmdletbinding(DefaultParameterSetName='Interactive')]
    param(
        [Parameter(Mandatory=$true, ParameterSetName='ClientCredentials')]
        [Parameter(Mandatory=$false, ParameterSetName='Interactive')]
        [Parameter(Mandatory=$false, ParameterSetName='RefreshToken')]
        [string]$TenantId,

        [Parameter(Mandatory=$true, ParameterSetName='ClientCredentials')]
        [Parameter(Mandatory=$true, ParameterSetName='Interactive')]
        [Parameter(Mandatory=$true, ParameterSetName='RefreshToken')]
        [string]$Scope,

        [Parameter(Mandatory=$true, ParameterSetName='RefreshToken')]
        [string]$RefreshToken,
 
        [Parameter(Mandatory=$true, ParameterSetName='ClientCredentials')]
        [Parameter(Mandatory=$true, ParameterSetName='Interactive')]
        [Parameter(Mandatory=$true, ParameterSetName='RefreshToken')]
        [string]$ClientId,
 
        [Parameter(Mandatory=$true, ParameterSetName='ClientCredentials')]
        [string]$ClientSecret
    )
    begin {
        $authority = if ($TenantId) { $TenantId } else { 'common' }
    }
 
    process {
        switch ($PSCmdlet.ParameterSetName) {
            'ClientCredentials' {
                $body = "grant_type=client_credentials&client_id=$clientid&client_secret=$ClientSecret&scope=$scope"
                $tokenEndpoint = "https://login.microsoftonline.com/$authority/oauth2/v2.0/token"
            }
            'RefreshToken' {
                $body = "grant_type=refresh_token&client_id=$clientid&refresh_token=$RefreshToken&scope=$scope"
                $tokenEndpoint = "https://login.microsoftonline.com/$authority/oauth2/token"
            }
            'Interactive' {
                $authorization_endpoint = "https://login.microsoftonline.com/$authority/oauth2/v2.0/authorize"
                $redirect_uri = 'http://localhost:8400/'
                $nonce = (New-Guid).Guid
                $code_endpoint = "$authorization_endpoint`?client_id=$clientid&scope=$scope&redirect_uri=$redirect_uri&response_type=code&nonce=$nonce&prompt=select_account"
                
                $null = Start-Job -Name 'CodeResponse' -Scriptblock {
                    param($redirect_uri)
                    $httpListener = New-Object System.Net.HttpListener
                    $httpListener.Prefixes.Add($redirect_uri)
                    $httpListener.Start()
                    $context = $httpListener.GetContext()
                    $context.Response.StatusCode = 200
                    $context.Response.ContentType = 'application/json'
                    $responseBytes = [System.Text.Encoding]::UTF8.GetBytes('')
                    $context.Response.OutputStream.Write($responseBytes, 0, $responseBytes.Length)        
                    $context.Response.Close()
                    $httpListener.Close()
                    $context.Request
                } -ArgumentList $redirect_uri
 
                Start-Process $code_endpoint
                $url = Get-Job -Name CodeResponse | Wait-Job | Receive-Job
                Remove-Job -Name CodeResponse
                $code = [System.Web.HTTPUtility]::ParseQueryString($url.url.query)['code']
 
                $body = "grant_type=authorization_code&client_id=$clientid&nonce=$nonce&code=$code&redirect_uri=$redirect_uri&scope=$scope"
                $tokenEndpoint = "https://login.microsoftonline.com/$authority/oauth2/token"
            }
        }
 
        $headers = @{ 'Content-Type' = 'application/x-www-form-urlencoded' }
        $tokenResponse = Invoke-RestMethod -Method POST -Uri $tokenEndpoint -Body $body -Headers $headers
 
        if ($tokenResponse.expires_on) {
            $tokenResponse.expires_on = (Get-Date "1970-01-01T00:00:00Z").ToUniversalTime().AddSeconds($tokenResponse.expires_on)
        }
    }
 
    end {
        $tokenResponse
    }
 }
