function New-LinuxDesktopShortcut {
<#
.SYNOPSIS
    Create a .desktop shortcut file for appimage files on linux
.PARAMETER Name
    Name of the shortcut to be created
.PARAMETER AppImagePath
    Full file path to the appimage file
.PARAMETER IconPath
    Full file path to the icon file
#>
param(
    [CmdletBinding()]
    [parameter(Mandatory)]    
    [string]
    $Name,
    
    [parameter(Mandatory)]
    [ValidateScript({Test-Path $_})]
    [string]
    $AppImagePath,
    
    [parameter(Mandatory)]
    [ValidateScript({Test-Path $_})]
    [string]
    $IconPath,
    
    [string]
    $Description
)
$ShortcutPath = "~/.local/share/applications/$Name.desktop"
$ShortcutContent = @"
[Desktop Entry]
Name=$Name
Comment=$Description
Exec=$AppImagePath
Icon=$IconPath
Terminal=false~
Type=Application
"@
& /bin/bash /c "chmod +x $AppImagePath"
New-Item -ItemType File -Path $ShortcutPath -Force
$ShortcutContent | Set-Content -Path $ShortcutPath
}