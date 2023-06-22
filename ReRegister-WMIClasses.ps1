<#	
	.NOTES
	===========================================================================
	 Created with: 	SAPIEN Technologies, Inc., PowerShell Studio 2021 v5.8.195
	 Created on:   	2/28/2022 12:38 PM
	 Created by:   	Dave Just
	 Organization: 	
	 Filename: ReRegister-WMIClasses     	
	===========================================================================
	.DESCRIPTION
		Re-registers all MOF files. MOF files contain the classes and class instances of the WMI objects contained in the WMI repository
#>

$mof = gci "$env:Windir\system32\WBEM" -include *.mof, *.mfl -recurse | foreach { $_  | select -expandproperty path }
$mof | foreach { & "$env:Windir\system32\WBEM\mofcomp" $_ }
