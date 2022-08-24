function Install-WinGet # Adapted from https://github.com/microsoft/winget-pkgs/blob/master/Tools/SandboxTest.ps1 (better than my original code!)
# This function will install the latest version of WinGet and its dependancies 
{
	$tempFolderName = 'WinGetInstall'
	$tempFolder = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath $tempFolderName
	New-Item $tempFolder -ItemType Directory -ErrorAction SilentlyContinue | Out-Null
	
	$apiLatestUrl = if ($Prerelease) { 'https://api.github.com/repos/microsoft/winget-cli/releases?per_page=1' }
	else { 'https://api.github.com/repos/microsoft/winget-cli/releases/latest' }
	
	[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
	$WebClient = New-Object System.Net.WebClient
	
	function Get-LatestUrl
	{
		((Invoke-WebRequest $apiLatestUrl -UseBasicParsing | ConvertFrom-Json).assets | Where-Object { $_.name -match '^Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle$' }).browser_download_url
	}
	
	function Get-LatestHash
	{
		$shaUrl = ((Invoke-WebRequest $apiLatestUrl -UseBasicParsing | ConvertFrom-Json).assets | Where-Object { $_.name -match '^Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.txt$' }).browser_download_url
		
		$shaFile = Join-Path -Path $tempFolder -ChildPath 'Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.txt'
		$WebClient.DownloadFile($shaUrl, $shaFile)
		
		Get-Content $shaFile
	}
	
	$desktopAppInstaller = @{
		fileName = 'Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle'
		url	     = $(Get-LatestUrl)
		hash	 = $(Get-LatestHash)
	}
	
	$vcLibsUwp = @{
		fileName = 'Microsoft.VCLibs.x64.14.00.Desktop.appx'
		url	     = 'https://aka.ms/Microsoft.VCLibs.x64.14.00.Desktop.appx'
		hash	 = '9BFDE6CFCC530EF073AB4BC9C4817575F63BE1251DD75AAA58CB89299697A569'
	}
	$uiLibsUwp = @{
		fileName = 'Microsoft.UI.Xaml.2.7.zip'
		url	     = 'https://www.nuget.org/api/v2/package/Microsoft.UI.Xaml/2.7.0'
		hash	 = '422FD24B231E87A842C4DAEABC6A335112E0D35B86FAC91F5CE7CF327E36A591'
	}
	
	$dependencies = @($desktopAppInstaller, $vcLibsUwp, $uiLibsUwp)
	
	Write-Host '--> Checking dependencies'
	
	foreach ($dependency in $dependencies)
	{
		$dependency.file = Join-Path -Path $tempFolder -ChildPath $dependency.fileName
		#$dependency.pathInSandbox = (Join-Path -Path $tempFolderName -ChildPath $dependency.fileName)
		
		# Only download if the file does not exist, or its hash does not match.
		if (-Not ((Test-Path -Path $dependency.file -PathType Leaf) -And $dependency.hash -eq $(Get-FileHash $dependency.file).Hash))
		{
			Write-Host @"
    - Downloading:
      $($dependency.url)
"@
			
			try
			{
				$WebClient.DownloadFile($dependency.url, $dependency.file)
			}
			catch
			{
				#Pass the exception as an inner exception
				throw [System.Net.WebException]::new("Error downloading $($dependency.url).", $_.Exception)
			}
			if (-not ($dependency.hash -eq $(Get-FileHash $dependency.file).Hash))
			{
				throw [System.Activities.VersionMismatchException]::new('Dependency hash does not match the downloaded file')
			}
		}
	}
	
	# Extract Microsoft.UI.Xaml from zip (if freshly downloaded).
	# This is a workaround until https://github.com/microsoft/winget-cli/issues/1861 is resolved.
	
	if (-Not (Test-Path (Join-Path -Path $tempFolder -ChildPath \Microsoft.UI.Xaml.2.7\tools\AppX\x64\Release\Microsoft.UI.Xaml.2.7.appx)))
	{
		Expand-Archive -Path $uiLibsUwp.file -DestinationPath ($tempFolder + '\Microsoft.UI.Xaml.2.7') -Force
	}
	$uiLibsUwp.file = (Join-Path -Path $tempFolder -ChildPath \Microsoft.UI.Xaml.2.7\tools\AppX\x64\Release\Microsoft.UI.Xaml.2.7.appx)
	Add-AppxPackage -Path $($desktopAppInstaller.file) -DependencyPath $($vcLibsUwp.file), $($uiLibsUwp.file)
	# Clean up files
	Remove-Item $tempFolder -recurse -force
}