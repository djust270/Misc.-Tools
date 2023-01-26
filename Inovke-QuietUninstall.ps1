<#
Author: David Just
Date: 11/03/2022
Website: davidjust.com
Github: github.com/djust270
Filename: Invoke-QuietUninstall.ps1

Synopsis. 
    Attempt to uninstall software using uninistall information in the registy
#>
# Software Name to Search For. Change this to whatever you desire. 
param (
    [String]$SoftwareName
)

function Get-RegUninstallKey
{
	param (
		[string]$DisplayName
	)
	$ErrorActionPreference = 'Continue'
	#$UserSID = (New-Object -ComObject Microsoft.DiskQuota).TranslateLogonNameToSID((Get-CimInstance -Class Win32_ComputerSystem).Username)
	$uninstallKeys = "registry::HKLM\Software\Microsoft\Windows\CurrentVersion\Uninstall", "registry::HKLM\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
	$softwareTable = @()
	
	foreach ($key in $uninstallKeys)
	{
		$softwareTable += Get-Childitem $key | Get-ItemProperty | Where-Object {$_.displayname} | Sort-Object -Property displayname
	}
	if ($DisplayName)
	{
		$softwareTable | Where-Object {$_.displayname -Like "*$DisplayName*"}
	}
	else
	{
		$softwareTable | Sort-Object -Property displayname -Unique
	}
	
}

# Make C:\temp if it doesnt exist
if (-Not(test-path "C:\temp")){
    New-Item -ItemType Directory -Path C:\temp
    }

$UnInstallString = (Get-RegUninstallKey -DisplayName $SoftwareName).uninstallstring

# Test if Uninstall string is using MSIExec
if ($UnInstallString -match 'msiexec'){
    # Find the MSI Product code by getting the uninstall string and doing some simple string manipulation
    $MsiProductCode = ((($UnInstallString) -split '{') -split '}')[1]

    # Test the MSIProduct code by type casting to GUID. This will throw a terminating error if incorrect
    try {
        [GUID]$MsiProductCode | Out-Null
    }
    Catch {
        # Catch the error and output to file
        $_ | Out-File "C:\temp\$SoftwareName-Uninstall.log"
        # Output the registry key to the same log file for thoroughness 
        Get-RegUninstallKey -displayname $SoftwareName | Out-File "C:\temp\$SoftwareName-Uninstall.log" -Append
    }
    # Run Uninstall command with logging
        msiexec /x "{$MsiProductCode}" /qn /norestart /l*v "C:\temp\$SoftwareName-Uninstall.log"
}
else {
    # Uninstall string does not contain MSIExec, try quietuninstall string
    $QuietUninstallString = (Get-RegUninstallKey -DisplayName $SoftwareName).QuietUninstallString
    if (-Not $QuietUninstallString){
        # If quiet uninstall string is not found in reg key, log to file, then quit script
        "No Quiet Uninstall String Found" | Out-File "C:\temp\$SoftwareName-Uninstall.log`n" -Append
        Get-RegUninstallKey -displayname $SoftwareName | Out-File "C:\temp\$SoftwareName-Uninstall.log" -Append
        return
    }
    # Execute QuietUninstallString
    & $QuietUninstallString
}
