<#	
.NOTES
	===========================================================================
	 Created with: 	SAPIEN Technologies, Inc., PowerShell Studio 2021 v5.8.195
	 Created on:   	8/3/2022 3:10 PM
	 Created by:   	David Just
	 Organization: 	
	 Filename: Get-ADUserPasswordExpiration    	
	===========================================================================
.DESCRIPTION
		Get the password expiration date and details for a specific AD user account. 
.EXAMPLE
	Example 1: Get the password expiration details for the user "djust"
	PS> Get-ADUserPasswordExpiration -Identity djust 
.EXAMPLE
	Example 2: Create a report for the password expiration for all users in a specific OU
	PS> $report = Get-ADUser -SearchBase "OU=Users,DC=localdomain,DC=local" | foreach {Get-ADUserPasswordExpiration $_.SamAccountName}
	PS> $report | export-csv PasswordExpirationReport.csv
#>

function Get-ADUserPasswordExpiration{
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true)]
		[string]$Identity
	)
	Import-Module ActiveDirectory
	try
	{
		$User = Get-ADUser $Identity -properties *
	}
	catch
	{
		$error[0]
	}
	$PasswordExpirationPolicy = (Get-ADDefaultDomainPasswordPolicy).MaxPasswordAge.Days
	$ExpirationDate = (get-date ($User).PasswordLastSet).AddDays($PasswordExpirationPolicy)
	$DaysToExpire = $ExpirationDate - (Get-Date)
	#return "Password Expiration Date for {0}: {1} `nDays until expiration: {2}" -f $User.DisplayName,$ExpirationDate,$DaysToExpire.days
	# decided to return an object instead of text. 
	$hash = [pscustomobject]@{
		User = $User.DisplayName
		PasswordExpiryDate = $ExpirationDate
		DaysToExpire = $DaysToExpire.days
		PasswordNeverExpires = $User.PasswordNeverExpires
	}
	return $hash
}

