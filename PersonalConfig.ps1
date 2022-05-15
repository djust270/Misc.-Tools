<#
.Synopsis
    Sample Script demonstrating the ability to script out software installs using WinGet, and personalizations to the Windows operating system. 
#>
using namespace System.Net
$client = [WebClient]::new()

# Add WinGet Packages.  

$wingetPackages = @(
'Microsoft.VisualStudioCode'
'Google.Chrome'
'Mozilla.Firefox'
'voidtools.Everything'
'Microsoft.PowerShell'
'Notepad++.Notepad++'
'SublimeHQ.SublimeText.4'
'Discord.Discord'
'Microsoft.WindowsTerminal'
'Python.Python.3'
'Obsidian.Obsidian'
)

Function Set-WallPaper($Value)

{
 Set-ItemProperty -path 'HKCU:\Control Panel\Desktop\' -name wallpaper -value $value
 rundll32.exe user32.dll, UpdatePerUserSystemParameters 1, True
}

function Install-VisualC {
$url = 'https://aka.ms/vs/17/release/vc_redist.x64.exe'
$WebClient = New-Object System.Net.WebClient
$WebClient.DownloadFile('https://aka.ms/vs/17/release/vc_redist.x64.exe', "$env:Temp\vc_redist.x64.exe")
$WebClient.Dispose()
start-process "$env:temp\vc_redist.x64.exe" -argumentlist "/q /norestart" -Wait
}

function Install-Winget {
$releases_url = "https://api.github.com/repos/microsoft/winget-cli/releases/latest"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$releases = Invoke-RestMethod -uri "$($releases_url)"
$latestRelease = $releases.assets | Where { $_.browser_download_url.EndsWith("msixbundle") } | Select -First 1
Add-AppxPackage -Path 'https://aka.ms/Microsoft.VCLibs.x64.14.00.Desktop.appx'
Add-AppxPackage -Path $latestRelease.browser_download_url
}

function WingetRun {
param (
	$PackageID,
	$RunType
)
	& Winget $RunType --id $PackageID --source Winget --silent --accept-package-agreements --accept-source-agreements 
}

# Create directory for our wallpaper image
mkdir "$env:appdata\Wallpaper"

# Download Wallpaper
$client.DownloadFile("https://images.hdqwalls.com/download/tired-city-scifi-car-du-2560x1440.jpg","$env:appdata\Wallpaper\tired-city-scifi-car-du-2560x1440.jpg")
$client.Dispose()

# Set Wallpaper
Set-WallPaper -value "$env:appdata\Wallpaper\tired-city-scifi-car-du-2560x1440.jpg"

Install-VisualC
Install-Winget

# Foreach loop to install packages

foreach ($package in $wingetPackages){
Write-Host "Installing Winget Package $($package)" -ForegroundColor Green -BackgroundColor Black
WingetRun -RunType Install -PackageID $package
}


# Enable Dark Mode
Set-ItemProperty -Path HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize -Name AppsUseLightTheme -Value 0 -Force
Set-ItemProperty -Path HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize -Name SystemUsesLightTheme -Value 0 -Force

# Show all items in system tray
Set-ItemProperty -Path HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer -Name EnableAutoTray -Value 0 -Force

# Show Hidden files in explorer
Set-ItemProperty -Path HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced -Name Hidden -Value 1

# Show file extensions in explorer
Set-ItemProperty -Path HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced -Name HiddFileExt -Value 0

Set-ItemProperty -Path HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced -Name HiddeIcons -Value 0 


# Restart Explorer
Get-Process explorer | stop-process

# Install Hyper-V
Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V -All -NoRestart

# Install NuGet package provider for PowerShell
Install−PackageProvider −Name Nuget −Force

# Install PS Modules
Set-PSRepository -Name "PSGallery" -InstallationPolicy Trusted
$modules = 'MSOnline','AzureADPreview','ExchangeOnlineManagement','Microsoft.Online.SharePoint.PowerShell','ImportExcel','MicrosoftTeams','Microsoft.Graph'

$i = 1
foreach ($module in $modules)
{
try {
        Write-Progress -Status "Working" -Activity "Installing Module $($module)" -PercentComplete (($i / $modules.count) * 100)
        Install-Module -Name $module -Force -Confirm:$false -ErrorAction Stop
        $i ++
    }
Catch {
        write-Host $_ -ForegroundColor Red
      }
}

# Install WSL
wsl --install -d ubuntu

# Reboot in 10 seconds
Shutdown /r /t 10