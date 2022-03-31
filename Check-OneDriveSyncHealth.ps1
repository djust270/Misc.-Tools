<#
Test script in progress to parse the SyncDiagnostics.log file for possible signs of sync errors
#>
$LogOnUser = (gcim win32_ComputerSystem).UserName
if (!$LogOnUser){exit 0}
$UserSID = ([System.Security.Principal.NTAccount](Get-CimInstance -ClassName Win32_ComputerSystem).UserName).Translate([System.Security.Principal.SecurityIdentifier]).Value
$UserLocalAppdata = (Get-ItemProperty "registry::HKU\$UserSID\Volatile Environment").LocalAppData
$OneDriveLog = $UserLocalAppdata + '\Microsoft\OneDrive\logs\Business1\SyncDiagnostics.log'
if (!(Test-Path $OneDriveLog)) { "OneDrive log not found"; exit 0 }

function parseOdmLogFileForStatus()
{
	#function borrowed from https://www.lieben.nu/liebensraum/2021/12/onedrive-for-business-sync-error-monitoring-and-auto-remediation/
	#with thanks to Rudy Ooms for the example! https://call4cloud.nl/2020/09/lost-in-monitoring-onedrive/
	Param (
		[String][Parameter(Mandatory = $true)]
		$logPath
	)
	
	try
	{
		$retVal = "Unknown: log file could not be parsed"
		if (!(Test-Path $logPath))
		{
			Throw "logfile does not exist at $logPath"
		}
		$progressState = Get-Content $logPath | Where-Object { $_.Contains("SyncProgressState") } | %{ -split $_ | select -index 1 }
		if (!$progressState)
		{
			Throw "SyncProgressState string not found"
		}
		switch ($progressState)
		{
			0{ $retVal = "Healthy" }
			10 { $retVal = "File merge conflict" }
			42{ $retVal = "Healthy" }
			256 { $retVal = "File locked" }
			258 { $retVal = "File merge conflict" }
			8456 { $retVal = "You don't have permission to sync this library" }
			16777216{ $retVal = "Healthy" }
			12544 { $retVal = "Healthy" }
			65536{ $retVal = "Paused" }
			32786{ $retVal = "File merge conflict" }
			4106{ $retVal = "File merge conflict" }
			20480{ $retVal = "File merge conflict" }
			24576{ $retVal = "File merge conflict" }
			25088 { $retVal = "File merge conflict" }
			8449{ $retVal = "File locked" }
			8194{ $retVal = "Disabled" }
			1854{ $retVal = "Unhealthy" }
			12290{ $retVal = "Access Permission" }
			default { $retVal = "Unknown: $progressState" }
		}
	}
	catch
	{
		$retVal = "Unknown: Could not find sync state in O4B log $_"
	}
	
	return $retVal
}

$Status = parseOdmLogFileForStatus -logpath $OneDriveLog
$Log = Get-Content $OneDriveLog 
$loglines = @()
$loglines += $Log | Select-String 'numUploadErrorsReported'
$loglines += $Log | Select-String 'syncStallDetected'
$loglines += $Log | Select-String 'numDownloadErrorsReported'
$loglines += $Log | Select-String 'numFileFailedUploads'
foreach ($line in $loglines){
if ((($line -split ' ')[2] -ge 1) -and $Status -ne "Healthy"){"Sync Status Unhealthy ; Code: {1} : {0}" -F $line,$Status}
}
if ($Status -eq "File merge conflict"){"Sync Status Unhealthy ; Code: {0}" -f $Status}
if ($Status -like "*permission*"){"Sync Status Unhealthy ; Code: {0}" -f $Status}
