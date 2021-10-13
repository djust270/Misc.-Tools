<#
.Synopsis 
    Return uninstall registry key properties for all installed software, including software installed in user context. Can be run as system. 

.Outputs 
    Selected.System.Management.Automation.PSCustomObject

.Example
    
    PS> Get-UninstallKeys | where displayname -eq "Zoom" | Select displayname,displayversion,uninstallstring,quietuninstallstring 
    
    ---------------------------Description--------------------------
    Filter for specific app, select desired properties
    
.Example

    PS> Start-Process  ((Get-UninstallKeys | where displayname -eq "Zoom").UninstallString).split()[0] -argumentlist ((Get-UninstallKeys | where displayname -eq "Zoom").UninstallString).split()[1]

    ---------------------------Description--------------------------
    Uninstall the selected app using start process. 

.Notes 
    Created by : David Just
    Date coded : 10/07/2021
    Repository : https://github.com/djust270
#>
function Get-UninstallKeys
{
$UserSID = (New-Object -ComObject Microsoft.DiskQuota).TranslateLogonNameToSID((Get-CimInstance -Class Win32_ComputerSystem).Username)
$table = [System.Collections.Generic.List[psobject]]::new()
$uninst = "registry::HKLM\Software\Microsoft\Windows\CurrentVersion\Uninstall","registry::HKLM\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall","registry::HKU\$UserSID\Software\Microsoft\Windows\CurrentVersion\Uninstall"
$uninst | foreach {$u = $_
$table.add((Get-Childitem $u | Get-ItemProperty | where displayname -ne $null | select displayname,DisplayVersion,UninstallString,QuietUninstallString,InstallLocation | Sort-Object -Property displayname)) }

    Return $table
}
