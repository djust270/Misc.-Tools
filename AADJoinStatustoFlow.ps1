<#
.Synopsis
    Sample code, grabbing data from a computer (in this case AD/AAD join status) and sending it to a PowerAutomate flow using the HTTP Request flow trigger. 
#>
$joinstatus = dsregcmd /status | Select-String -SimpleMatch 'AzureAdJoined'
$domainstatus = dsregcmd /status | Select-String -SimpleMatch 'DomainJoined'

if ($joinstatus -like '*yes*'){$aadstatus = "IsJoined"}else{$aadstatus = "NOTJoined"}
if ($domainstatus -like '*yes*'){$DomainJoinStatus = "IsJoined"}else{$DomainJoinStatus = "NOTJoined"}
$CompInfo = [System.Collections.Generic.List[PSObject]]::new()
$CompInfo.add([pscustomobject]@{
    key = "$env:ComputerName"
    ComputerName = "$env:ComputerName"
    User = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name 
    AADJoinStatus = $aadstatus
    DomainJoinStatus = $DomainJoinStatus
    }
   )


$flow = # URL in PowerAutomate Flow for HTTP Request
$flowheader = $compinfo | ConvertTo-Json -Compress
Invoke-RestMethod -Method Post -Body $flowheader -uri $flow -ContentType Application\JSON
		
