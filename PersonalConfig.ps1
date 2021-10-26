using namespace System.Net
$client = [WebClient]::new()

Function Set-WallPaper($Value)

{

 Set-ItemProperty -path 'HKCU:\Control Panel\Desktop\' -name wallpaper -value $value

 rundll32.exe user32.dll, UpdatePerUserSystemParameters 1, True

}

mkdir "$env:appdata\Wallpaper"
$client.DownloadFile("https://images.hdqwalls.com/download/tired-city-scifi-car-du-2560x1440.jpg","$env:appdata\Wallpaper\tired-city-scifi-car-du-2560x1440.jpg")
Set-WallPaper -value "$env:appdata\Wallpaper\tired-city-scifi-car-du-2560x1440.jpg"

mkdir C:\installers

$winget = 'https://github.com/microsoft/winget-cli/releases/download/v1.1.12653/Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle'
$client.DownloadFile($winget, 'C:\installers\Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle')
add-appxpackage -Path 'C:\installers\Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle'

$wingetPackages = @(
'Microsoft.VisualStudioCode'
'Google.Chrome'
'Mozilla.Firefox'
'voidtools.Everything'
'Microsoft.PowerShell'
'Microsoft.PowerAutomateDesktop'
'Notepad++.Notepad++'
'SublimeHQ.SublimeText.4'
)

$wingetUserPackages = @(
'Microsoft.VisualStudio.2019.Community'
'Discord.Discord'
'Microsoft.WindowsTerminal'
'9NTXR16HNW1T'
)

foreach ($package in $wingetPackages){
Write-Host "Installing Winget Package $($package)" -ForegroundColor Green -BackgroundColor Black
Winget Install --id $package --scope machine --accept-package-agreements --accept-source-agreements
}

foreach ($package in $wingetUserPackages){
Write-Host "Installing Winget Package $($package)" -ForegroundColor Green -BackgroundColor Black
Winget Install --id $package --accept-package-agreements --accept-source-agreements
}

#$client.DownloadFile('https://visualstudio.microsoft.com/thank-you-downloading-visual-studio/?sku=Community&rel=16','C:\Installers\vs_community__66ad515f.5979.49e1.830a.e65fb641b23e.exe')
#Start-Process 'C:\Installers\vs_community__66ad515f.5979.49e1.830a.e65fb641b23e.exe'

# Enable Dark Mode
Set-ItemProperty -Path HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize -Name AppsUseLightTheme -Value 0 -Force

# Show all items in system tray

Set-ItemProperty -Path HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer -Name EnableAutoTray -Value 0 -Force

Set-ItemProperty -Path HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced -Name Hidden -Value 1
Set-ItemProperty -Path HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced -Name HiddFileExt -Value 0
Set-ItemProperty -Path HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced -Name HiddeIcons -Value 0 


# Restart Explorer
Get-Process explorer | stop-process

# Install Hyper-V
Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V -All -NoRestart

# Install PS Modules
Set-PSRepository -Name "PSGallery" -InstallationPolicy Trusted
$modules = 'MSOnline','AzureADPreview','ExchangeOnlineManagement','Microsoft.Online.SharePoint.PowerShell','ImportExcel','MicrosoftTeams'
$i = 1
foreach ($module in $modules)
{
try {
        Write-Progress -Status "Working" -Activity "Installing Module $($module)" -PercentComplete ($i / $modules.count)
        Install-Module -Name $module -Force -Confirm:$false -ErrorAction Stop
        $i ++
    }
Catch {
        Throw $_
      }
}


# Reboot in 10 seconds
Shutdown /r /t 10