<#	
	.NOTES
	===========================================================================
	 Created with: 	SAPIEN Technologies, Inc., PowerShell Studio 2021 v5.8.195
	 Created on:   	5/12/2022 8:59 AM
	 Created by:   	Dave	
	 Filename: UserProfileBackupRemovalTool.ps1   	
	===========================================================================
	.DESCRIPTION
		Backs up and removes Windows user profile in the event the profile is broken
#>
#Requires -RunAsAdministrator
$userprofiles = (Get-ChildItem registry::"HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\" | get-itemproperty).pschildname
$users = foreach ($user in ($userprofiles | where { $_.Length -gt 20 }))
{
	$sid = $user
	try
	{
		[pscustomobject]@{
			'UserName' = ([System.Security.Principal.SecurityIdentifier]($sid)).translate([System.Security.Principal.NTAccount]).value
			'SID'	   = $sid
			'ProfilePath' = (Get-ItemProperty registry::HKEY_LOCAL_MACHINE\"SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\$sid").ProfileImagePath
		}
	}
	Catch {}
	
}

function Welcome
{
	
	Write-Host "####################################################################################################"
	Write-Host "User Profile Backup/Removal Tool Version 1.0`nAuthor: David Just" -ForegroundColor DarkCyan -BackgroundColor Black
	Write-Host "Welcome to the User Profile Backup/Removal Tool" -ForegroundColor Green -BackgroundColor Black
	Write-Host "#################################################################################################### `r`n"
	Write-Warning "This tool performs potentially descructive actions. `nBefore running, please export and save browser passwords, bookmarks etc."
	pause
	Write-Host "[1] Backup/remove user profile registry key and reboot`n[2] Rename user profile folder"
	$global:option = [int](Read-Host "Which step would you like to perform?")
}

function ListUserProgram
{
	param (
		$SID,
		$ProfilePath 
	)
	reg load HKU\brokenuser $ProfilePath\NTUSER.DAT
	$RegPath = "registry::HKU\brokenuser\Software\Microsoft\Windows\CurrentVersion\Uninstall"
	try
	{
		$softwareTable = Get-Childitem $RegPath -ErrorAction Stop | Get-ItemProperty | where displayname | select displayname, displayversion 
		New-Item -ItemType directory -Path $env:SystemDrive\backup -force | Out-Null
		$softwareTable | Export-Csv "$env:SystemDrive\backup\usersoftware.csv" -NoTypeInformation
	}
	Catch
	{
		$_
		"Error exporting user software list"
		"Stopping Operation"
		reg unload HKU\brokenuser 
		sleep 5
		exit 1
	}
	
	
}

Welcome

function RemoveAndBackupUserProfile {
	[Cmdletbinding(SupportsShouldProcess)]
	param (
		[string]$SID,
		[string]$profilepath
	)
	reg export "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\$sid" $env:SystemDrive\backup\profile.reg
	
	$profilepath | Out-File $env:SystemDrive\backup\profilepath.txt
	
	Remove-Item registry::"HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\$sid" -Recurse
	CheckandSuspendBitlocker	
	"Profile removed from registry. Rebooting in 5 seconds"
	shutdown /r /t 5
	
}

function CheckandSuspendBitlocker # Suspend Bitlocker protection for reboot
{
	$Status = (Get-BitLockerVolume -MountPoint $env:systemdrive).protectionstatus
	if ($Status -eq "On")
	{
		"Suspending bitlocker protection..."
		Suspend-BitLocker -MountPoint $env:SystemDrive -RebootCount 1
	}
}

switch ($option)
{
	1 {
		$index = 1
		foreach ($user in $users)
		{
			"[$index] {0}" -f $user.username
			$index++
		}
		$Selection = [int](Read-Host "Which user account do you wish to backup and remove?") - 1		
		
		Write-Host "Exporting User Program List..."
		sleep 1
		ListUserProgram -SID ($users[$Selection]).SID -ProfilePath ($users[$Selection]).ProfilePath
		
		"Program list saved to $env:SystemDrive\backup\usersoftware.csv"
		Pause
		RemoveAndBackupUserProfile -SID ($users[$Selection]).SID -profilepath ($users[$Selection]).ProfilePath -Confirm
	}
	2 {
		$profilepath = Get-Content $env:SystemDrive\backup\profilepath.txt
		Rename-Item $profilepath -NewName ($profilepath + ".bak")
		"Renamed {0} to {1}" -f $profilepath,($profilepath + ".bak")
		sleep 5
	}
}

