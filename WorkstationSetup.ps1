Set-Location ([system.Environment]::GetFolderPath('Desktop'))
#Start-Process powershell.exe -ArgumentList "-encodedcommand $command" -Verb runas
#region Functions

function SetMimecastURL
{
try {
$bitness = (Get-ItemProperty registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Office\16.0\Outlook).bitness
switch ($bitness){
x86 {$mimcastURL = "https://601905.app.netsuite.com/core/media/media.nl?id=137021240&c=601905&h=u9RbaTSFzgH2UcL9lemOYThmAM9f4uFudtpErO3ftLndPfX5&_xt=.zip"}
}
x64 {$mimcastURL = "https://601905.app.netsuite.com/core/media/media.nl?id=137021240&c=601905&h=NrhueSTilBnWhYtKOvKs2lXTCnUXVupY2LkBABG3vBgw00nd&_xt=.zip"}
}
catch{
"Office Not Installed"
$global:officeInstall = $false
}
}

function Install-WinGet
{
	Add-AppxPackage -Path 'https://aka.ms/getwinget'
}

function WingetRun
{
	param (
		$PackageID,
		$RunType
	)
	& Winget $RunType --id $PackageID --source Winget --silent --accept-package-agreements --accept-source-agreements
}

function Install-VisualC
{
	$url = 'https://aka.ms/vs/17/release/vc_redist.x64.exe'
	$WebClient = New-Object System.Net.WebClient
	$WebClient.DownloadFile('https://aka.ms/vs/17/release/vc_redist.x64.exe', "$env:Temp\vc_redist.x64.exe")
	$WebClient.Dispose()
	start-process "$env:temp\vc_redist.x64.exe" -argumentlist "/q /norestart" -Wait
}

function DownloadInstaller
{
	param (
		[string]$url,
		[switch]$install,
		[string]$SilentArgs,
        [switch]$nowait
	)
	function Start-Installer
	{
		param (
			$Installer,
			$SilentSwitch,
            [switch]$nowait
		)
		"Starting {0}..." -f $Installer
		if ($SilentSwitch) { Start-Process $Installer -ArgumentList "$SilentSwitch" }
		elseif ($nowait){Start-Process $Installer}
        else 
		{
			start-process $Installer -wait 
		}
		
	}
	$filename = ($url -split '/') | where { $_ -match '[.]msi' -or $_ -match '[.]exe' -or $_ -match '[.]zip' }
	if ($filename.count -gt 1) { Write-Warning "Array passed, please pass a single object";  break}
	$destination = $env:TEMP
	$fullPath = "$destination\$filename"
	if (Test-Path $fullPath)
	{
		"File already exists"
	Start-Installer -Installer $fullPath -nowait  }
	else
	{
		$WebClient = [System.Net.WebClient]::new()
		"Downloading {0} to {1}" -f $filename, $destination
		$WebClient.DownloadFile($url, "$destination\$filename")
		$WebClient.Dispose()
		if ($SilentArgs) { Start-Installer -Installer "$destination\$filename" -SilentSwitch "/qn" }
		elseif ($nowait){Start-Installer -Installer "$destination\$filename" -nowait}
        else { Start-Installer -Installer "$destination\$filename" }
	}
	
}

function Get-RegUninstallKey
{
	param (
		[string]$DisplayName
	)
	$ErrorActionPreference = 'Continue'
	$uninstallKeys = "registry::HKLM\Software\Microsoft\Windows\CurrentVersion\Uninstall", "registry::HKLM\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall","registry::HKCU\Software\Microsoft\Windows\CurrentVersion\Uninstall"
	$softwareTable = @()
	
	foreach ($key in $uninstallKeys)
	{
		$softwareTable += Get-Childitem $key | Get-ItemProperty | where displayname | Sort-Object -Property displayname
	}
	if ($DisplayName)
	{
		$softwareTable | where displayname -Like "*$DisplayName*"
	}
	else
	{
		$softwareTable | Sort-Object -Property displayname -Unique
	}
	
}



function MimecastInstall
{
	if (!$mimecastURL) { "Unable to determine office bitness. Please install mimecast manually"; return}
	$WebClient = [System.Net.WebClient]::new()
	"Download MimeCast for Outlook"
	$WebClient.DownloadFile($mimecast, "$env:TEMP\Mimecast.zip")
	mkdir "$env:TEMP\Mimecast" -force | Out-Null	
	Expand-Archive "$env:TEMP\Mimecast.zip" "$env:TEMP\Mimecast" -Force | Out-Null
	$processes = Get-Process
	if ($processes.name -contains "Outlook") { Get-Process Outlook | Stop-Process }
	if ($processes.name -contains "Excel") { Get-Process Excel | Stop-Process }
	if ($processes.name -contains "WINWORD") { Get-Process WINWORD | Stop-Process }
	$mimecastInstaller = (dir "$env:TEMP\Mimecast" "*.msi").fullname
	Start-Process -filepath $mimecastInstaller 
}

function Pin-ToTaskbar {
	[CmdletBinding()]
	param (
	[string]$targetfile,
	[validateset('PIN','UNPIN')]
    [String]$Action
	)
	
	
function Masquerade-PEB {
<#
.SYNOPSIS
    Masquerade-PEB uses NtQueryInformationProcess to get a handle to powershell's
    PEB. From there itreplaces a number of UNICODE_STRING structs in memory to
    give powershell the appearance of a different process. Specifically, the
    function will overwrite powershell's "ImagePathName" & "CommandLine" in
    _RTL_USER_PROCESS_PARAMETERS and the "FullDllName" & "BaseDllName" in the
    _LDR_DATA_TABLE_ENTRY linked list.
    
    This can be useful as it would fool any Windows work-flows which rely solely
    on the Process Status API to check process identity. A practical example would
    be the IFileOperation COM Object which can perform an elevated file copy if it
    thinks powershell is really explorer.exe ;)!

    Notes:
      * Works on x32/64.
    
      * Most of these API's and structs are undocumented. I strongly recommend
        @rwfpl's terminus project as a reference guide!
          + http://terminus.rewolf.pl/terminus/
    
      * Masquerade-PEB is basically a reimplementation of two functions in UACME
        by @hFireF0X. My code is quite different because,  unfortunately, I don't
        have access to all those c++ goodies and I could not get a callback for
        LdrEnumerateLoadedModules working!
          + supMasqueradeProcess: https://github.com/hfiref0x/UACME/blob/master/Source/Akagi/sup.c#L504
          + supxLdrEnumModulesCallback: https://github.com/hfiref0x/UACME/blob/master/Source/Akagi/sup.c#L477

.DESCRIPTION
    Author: Ruben Boonen (@FuzzySec)
    License: BSD 3-Clause
    Required Dependencies: None
    Optional Dependencies: None

.EXAMPLE
    C:\PS> Masquerade-PEB -BinPath "C:\Windows\explorer.exe"
#>

	param (
		[Parameter(Mandatory = $True)]
		[string]$BinPath
	)

	Add-Type -TypeDefinition @"
	using System;
	using System.Diagnostics;
	using System.Runtime.InteropServices;
	using System.Security.Principal;

	[StructLayout(LayoutKind.Sequential)]
	public struct UNICODE_STRING
	{
		public UInt16 Length;
		public UInt16 MaximumLength;
		public IntPtr Buffer;
	}

	[StructLayout(LayoutKind.Sequential)]
	public struct _LIST_ENTRY
	{
		public IntPtr Flink;
		public IntPtr Blink;
	}
	
	[StructLayout(LayoutKind.Sequential)]
	public struct _PROCESS_BASIC_INFORMATION
	{
		public IntPtr ExitStatus;
		public IntPtr PebBaseAddress;
		public IntPtr AffinityMask;
		public IntPtr BasePriority;
		public UIntPtr UniqueProcessId;
		public IntPtr InheritedFromUniqueProcessId;
	}

	/// Partial _PEB
	[StructLayout(LayoutKind.Explicit, Size = 64)]
	public struct _PEB
	{
		[FieldOffset(12)]
		public IntPtr Ldr32;
		[FieldOffset(16)]
		public IntPtr ProcessParameters32;
		[FieldOffset(24)]
		public IntPtr Ldr64;
		[FieldOffset(28)]
		public IntPtr FastPebLock32;
		[FieldOffset(32)]
		public IntPtr ProcessParameters64;
		[FieldOffset(56)]
		public IntPtr FastPebLock64;
	}

	/// Partial _PEB_LDR_DATA
	[StructLayout(LayoutKind.Sequential)]
	public struct _PEB_LDR_DATA
	{
		public UInt32 Length;
		public Byte Initialized;
		public IntPtr SsHandle;
		public _LIST_ENTRY InLoadOrderModuleList;
		public _LIST_ENTRY InMemoryOrderModuleList;
		public _LIST_ENTRY InInitializationOrderModuleList;
		public IntPtr EntryInProgress;
	}

	/// Partial _LDR_DATA_TABLE_ENTRY
	[StructLayout(LayoutKind.Sequential)]
	public struct _LDR_DATA_TABLE_ENTRY
	{
		public _LIST_ENTRY InLoadOrderLinks;
		public _LIST_ENTRY InMemoryOrderLinks;
		public _LIST_ENTRY InInitializationOrderLinks;
		public IntPtr DllBase;
		public IntPtr EntryPoint;
		public UInt32 SizeOfImage;
		public UNICODE_STRING FullDllName;
		public UNICODE_STRING BaseDllName;
	}

	public static class Kernel32
	{
		[DllImport("kernel32.dll")]
		public static extern UInt32 GetLastError();

		[DllImport("kernel32.dll")]
		public static extern Boolean VirtualProtectEx(
			IntPtr hProcess,
			IntPtr lpAddress,
			UInt32 dwSize,
			UInt32 flNewProtect,
			ref UInt32 lpflOldProtect);

		[DllImport("kernel32.dll")]
		public static extern Boolean WriteProcessMemory(
			IntPtr hProcess,
			IntPtr lpBaseAddress,
			IntPtr lpBuffer,
			UInt32 nSize,
			ref UInt32 lpNumberOfBytesWritten);
	}

	public static class Ntdll
	{
		[DllImport("ntdll.dll")]
		public static extern int NtQueryInformationProcess(
			IntPtr processHandle, 
			int processInformationClass,
			ref _PROCESS_BASIC_INFORMATION processInformation,
			int processInformationLength,
			ref int returnLength);

		[DllImport("ntdll.dll")]
		public static extern void RtlEnterCriticalSection(
			IntPtr lpCriticalSection);

		[DllImport("ntdll.dll")]
		public static extern void RtlLeaveCriticalSection(
			IntPtr lpCriticalSection);
	}
"@

	# Flag architecture $x32Architecture/!$x32Architecture
	if ([System.IntPtr]::Size -eq 4) {
		$x32Architecture = 1
	}

	# Current Proc handle
	$ProcHandle = (Get-Process -Id ([System.Diagnostics.Process]::GetCurrentProcess().Id)).Handle

	# Helper function to overwrite UNICODE_STRING structs in memory
	function Emit-UNICODE_STRING {
		param(
			[IntPtr]$hProcess,
			[IntPtr]$lpBaseAddress,
			[UInt32]$dwSize,
			[String]$data
		)

		# Set access protections -> PAGE_EXECUTE_READWRITE
		[UInt32]$lpflOldProtect = 0
		$CallResult = [Kernel32]::VirtualProtectEx($hProcess, $lpBaseAddress, $dwSize, 0x40, [ref]$lpflOldProtect)

		# Create replacement struct
		$UnicodeObject = New-Object UNICODE_STRING
		$UnicodeObject_Buffer = $data
		[UInt16]$UnicodeObject.Length = $UnicodeObject_Buffer.Length*2
		[UInt16]$UnicodeObject.MaximumLength = $UnicodeObject.Length+1
		[IntPtr]$UnicodeObject.Buffer = [System.Runtime.InteropServices.Marshal]::StringToHGlobalUni($UnicodeObject_Buffer)
		[IntPtr]$InMemoryStruct = [System.Runtime.InteropServices.Marshal]::AllocHGlobal($dwSize)
		[system.runtime.interopservices.marshal]::StructureToPtr($UnicodeObject, $InMemoryStruct, $true)

		# Overwrite PEB UNICODE_STRING struct
		[UInt32]$lpNumberOfBytesWritten = 0
		$CallResult = [Kernel32]::WriteProcessMemory($hProcess, $lpBaseAddress, $InMemoryStruct, $dwSize, [ref]$lpNumberOfBytesWritten)

		# Free $InMemoryStruct
		[System.Runtime.InteropServices.Marshal]::FreeHGlobal($InMemoryStruct)
	}

	# Process Basic Information
	$PROCESS_BASIC_INFORMATION = New-Object _PROCESS_BASIC_INFORMATION
	$PROCESS_BASIC_INFORMATION_Size = [System.Runtime.InteropServices.Marshal]::SizeOf($PROCESS_BASIC_INFORMATION)
	$returnLength = New-Object Int
	$CallResult = [Ntdll]::NtQueryInformationProcess($ProcHandle, 0, [ref]$PROCESS_BASIC_INFORMATION, $PROCESS_BASIC_INFORMATION_Size, [ref]$returnLength)

	# PID & PEB address
	# echo "`n[?] PID $($PROCESS_BASIC_INFORMATION.UniqueProcessId)"
	if ($x32Architecture) {
		# echo "[+] PebBaseAddress: 0x$("{0:X8}" -f $PROCESS_BASIC_INFORMATION.PebBaseAddress.ToInt32())"
	} else {
		# echo "[+] PebBaseAddress: 0x$("{0:X16}" -f $PROCESS_BASIC_INFORMATION.PebBaseAddress.ToInt64())"
	}

	# Lazy PEB parsing
	$_PEB = New-Object _PEB
	$_PEB = $_PEB.GetType()
	$BufferOffset = $PROCESS_BASIC_INFORMATION.PebBaseAddress.ToInt64()
	$NewIntPtr = New-Object System.Intptr -ArgumentList $BufferOffset
	$PEBFlags = [system.runtime.interopservices.marshal]::PtrToStructure($NewIntPtr, [type]$_PEB)

	# Take ownership of PEB
	# Not sure this is strictly necessary but why not!
	if ($x32Architecture) {
		[Ntdll]::RtlEnterCriticalSection($PEBFlags.FastPebLock32)
	} else {
		[Ntdll]::RtlEnterCriticalSection($PEBFlags.FastPebLock64)
	} # echo "[!] RtlEnterCriticalSection --> &Peb->FastPebLock"

	# &Peb->ProcessParameters->ImagePathName/CommandLine
	if ($x32Architecture) {
		# Offset to &Peb->ProcessParameters
		$PROCESS_PARAMETERS = $PEBFlags.ProcessParameters32.ToInt64()
		# x86 UNICODE_STRING struct's --> Size 8-bytes = (UInt16*2)+IntPtr
		[UInt32]$StructSize = 8
		$ImagePathName = $PROCESS_PARAMETERS + 0x38
		$CommandLine = $PROCESS_PARAMETERS + 0x40
	} else {
		# Offset to &Peb->ProcessParameters
		$PROCESS_PARAMETERS = $PEBFlags.ProcessParameters64.ToInt64()
		# x64 UNICODE_STRING struct's --> Size 16-bytes = (UInt16*2)+IntPtr
		[UInt32]$StructSize = 16
		$ImagePathName = $PROCESS_PARAMETERS + 0x60
		$CommandLine = $PROCESS_PARAMETERS + 0x70
	}

	# Overwrite PEB struct
	# Can easily be extended to other UNICODE_STRING structs in _RTL_USER_PROCESS_PARAMETERS(/or in general)
	$ImagePathNamePtr = New-Object System.Intptr -ArgumentList $ImagePathName
	$CommandLinePtr = New-Object System.Intptr -ArgumentList $CommandLine
	if ($x32Architecture) {
		# echo "[>] Overwriting &Peb->ProcessParameters.ImagePathName: 0x$("{0:X8}" -f $ImagePathName)"
		# echo "[>] Overwriting &Peb->ProcessParameters.CommandLine: 0x$("{0:X8}" -f $CommandLine)"
	} else {
		# echo "[>] Overwriting &Peb->ProcessParameters.ImagePathName: 0x$("{0:X16}" -f $ImagePathName)"
		# echo "[>] Overwriting &Peb->ProcessParameters.CommandLine: 0x$("{0:X16}" -f $CommandLine)"
	}
	Emit-UNICODE_STRING -hProcess $ProcHandle -lpBaseAddress $ImagePathNamePtr -dwSize $StructSize -data $BinPath
	Emit-UNICODE_STRING -hProcess $ProcHandle -lpBaseAddress $CommandLinePtr -dwSize $StructSize -data $BinPath

	# &Peb->Ldr
	$_PEB_LDR_DATA = New-Object _PEB_LDR_DATA
	$_PEB_LDR_DATA = $_PEB_LDR_DATA.GetType()
	if ($x32Architecture) {
		$BufferOffset = $PEBFlags.Ldr32.ToInt64()
	} else {
		$BufferOffset = $PEBFlags.Ldr64.ToInt64()
	}
	$NewIntPtr = New-Object System.Intptr -ArgumentList $BufferOffset
	$LDRFlags = [system.runtime.interopservices.marshal]::PtrToStructure($NewIntPtr, [type]$_PEB_LDR_DATA)

	# &Peb->Ldr->InLoadOrderModuleList->Flink
	$_LDR_DATA_TABLE_ENTRY = New-Object _LDR_DATA_TABLE_ENTRY
	$_LDR_DATA_TABLE_ENTRY = $_LDR_DATA_TABLE_ENTRY.GetType()
	$BufferOffset = $LDRFlags.InLoadOrderModuleList.Flink.ToInt64()
	$NewIntPtr = New-Object System.Intptr -ArgumentList $BufferOffset

	# Traverse doubly linked list
	# &Peb->Ldr->InLoadOrderModuleList->InLoadOrderLinks->Flink
	# This is probably overkill, powershell.exe should always be the first entry for InLoadOrderLinks
	# echo "[?] Traversing &Peb->Ldr->InLoadOrderModuleList doubly linked list"
	while ($ListIndex -ne $LDRFlags.InLoadOrderModuleList.Blink) {
		$LDREntry = [system.runtime.interopservices.marshal]::PtrToStructure($NewIntPtr, [type]$_LDR_DATA_TABLE_ENTRY)

		if ([System.Runtime.InteropServices.Marshal]::PtrToStringUni($LDREntry.FullDllName.Buffer) -like "*powershell.exe*") {

			if ($x32Architecture) {
				# x86 UNICODE_STRING struct's --> Size 8-bytes = (UInt16*2)+IntPtr
				[UInt32]$StructSize = 8
				$FullDllName = $BufferOffset + 0x24
				$BaseDllName = $BufferOffset + 0x2C
			} else {
				# x64 UNICODE_STRING struct's --> Size 16-bytes = (UInt16*2)+IntPtr
				[UInt32]$StructSize = 16
				$FullDllName = $BufferOffset + 0x48
				$BaseDllName = $BufferOffset + 0x58
			}

			# Overwrite _LDR_DATA_TABLE_ENTRY struct
			# Can easily be extended to other UNICODE_STRING structs in _LDR_DATA_TABLE_ENTRY(/or in general)
			$FullDllNamePtr = New-Object System.Intptr -ArgumentList $FullDllName
			$BaseDllNamePtr = New-Object System.Intptr -ArgumentList $BaseDllName
			if ($x32Architecture) {
				# echo "[>] Overwriting _LDR_DATA_TABLE_ENTRY.FullDllName: 0x$("{0:X8}" -f $FullDllName)"
				# echo "[>] Overwriting _LDR_DATA_TABLE_ENTRY.BaseDllName: 0x$("{0:X8}" -f $BaseDllName)"
			} else {
				# echo "[>] Overwriting _LDR_DATA_TABLE_ENTRY.FullDllName: 0x$("{0:X16}" -f $FullDllName)"
				# echo "[>] Overwriting _LDR_DATA_TABLE_ENTRY.BaseDllName: 0x$("{0:X16}" -f $BaseDllName)"
			}
			Emit-UNICODE_STRING -hProcess $ProcHandle -lpBaseAddress $FullDllNamePtr -dwSize $StructSize -data $BinPath
			Emit-UNICODE_STRING -hProcess $ProcHandle -lpBaseAddress $BaseDllNamePtr -dwSize $StructSize -data $BinPath
		}
		
		$ListIndex = $BufferOffset = $LDREntry.InLoadOrderLinks.Flink.ToInt64()
		$NewIntPtr = New-Object System.Intptr -ArgumentList $BufferOffset
	}

	# Release ownership of PEB
	if ($x32Architecture) {
		[Ntdll]::RtlLeaveCriticalSection($PEBFlags.FastPebLock32)
	} else {
		[Ntdll]::RtlLeaveCriticalSection($PEBFlags.FastPebLock64)
	} # echo "[!] RtlLeaveCriticalSection --> &Peb->FastPebLock`n"
}


if (($args[0] -eq "/?") -Or ($args[0] -eq "-h") -Or ($args[0] -eq "--h") -Or ($args[0] -eq "-help") -Or ($args[0] -eq "--help")){
	write-host "This script needs to be run with two arguments."`r`n
	write-host "1 - Full path to the file you wish to pin (surround in quotes)."
	write-host "2 - Either PIN or UNPIN (case insensitive)."
	write-host "Example:-"
	write-host 'powershell -noprofile -ExecutionPolicy Bypass -file PinToTaskBar1903.ps1 "C:\Windows\Notepad.exe" PIN'`r`n
	Break
}

<#
if ($args.count -eq 2){
	$TargetFile = $args[0]
	$PinUnpin = $args[1].ToUpper()
} else {
	write-host "Incorrect number of arguments.  Exiting..."`r`n
	Break
}
#>

# Check all the variables are correct before starting
if (!(Test-Path "$TargetFile")){
	write-host "File not found.  Exiting..."`r`n
	Break
}

# Set the arguments to the required verb actions
if ($Action -eq "PIN"){$PinUnpin = "taskbarpin"}
if ($Action -eq "UNPIN"){$PinUnpin = "taskbarunpin"}

# Split the target path to folder, filename and filename with no extension
$FileNameNoExt = (Get-ChildItem $TargetFile).BaseName
$FileNameWithExt = (Get-ChildItem $TargetFile).Name
$Directory = (Get-Childitem $TargetFile).Directory

# Hide Powershell as Explorer...
Masquerade-PEB -BinPath "C:\Windows\explorer.exe"

# If target file is not a .lnk then create a shortcut, (un)pin that and then delete it
if ((Get-ChildItem $TargetFile).Extension -ne ".lnk"){

	if (test-path "$env:TEMP\$FileNameNoExt.lnk"){Remove-Item -path "$env:TEMP\$FileNameNoExt.lnk"}

	$WshShell = New-Object -comObject WScript.Shell
	$Shortcut = $WshShell.CreateShortcut("$env:TEMP\$FileNameNoExt.lnk")
	$Shortcut.TargetPath = $TargetFile
	$Shortcut.Save()
	
	$TargetFile = "$env:TEMP\$FileNameNoExt.lnk"
	$FileNameWithExt = (Get-ChildItem $TargetFile).Name
	$Directory = (Get-Childitem $TargetFile).Directory
	
	(New-Object -ComObject shell.application).Namespace("$Directory\").parsename("$FileNameWithExt").invokeverb("$PinUnpin")

	if (test-path "$env:TEMP\$FileNameNoExt.lnk"){Remove-Item -path "$env:TEMP\$FileNameNoExt.lnk"}

} else {
	(New-Object -ComObject shell.application).Namespace("$Directory\").parsename("$FileNameWithExt").invokeverb("$PinUnpin")
}

}

function Unpin-App {
param (
$AppName,
[ValidateSet('taskbarunpin')]
$Verb
)
$Apps = (New-Object -Com Shell.Application).NameSpace('shell:::{4234d49b-0245-4df3-b780-3893943456e1}').Items()
($Apps | where name -like "$AppName").invokeverb("$Verb")
}

#endregion

#region Bookmarks
$bookmarks = @'
<!DOCTYPE NETSCAPE-Bookmark-file-1>
<!-- This is an automatically generated file.
     It will be read and overwritten.
     DO NOT EDIT! -->
<META HTTP-EQUIV="Content-Type" CONTENT="text/html; charset=UTF-8">
<TITLE>Bookmarks</TITLE>
<H1>Bookmarks</H1>
<DL><p>
    <DT><H3 ADD_DATE="1638560671" LAST_MODIFIED="1638560847" PERSONAL_TOOLBAR_FOLDER="true">Bookmarks bar</H3>
    <DL><p>
        <DT><A HREF="https://online.adp.com/signin/v1/?APPID=RDBX&productId=80e309c3-70c6-bae1-e053-3505430b5495&returnURL=https://my.adp.com/&callingAppId=RDBX&TARGET=-SM-https://my.adp.com/static/redbox/" ADD_DATE="1638560692" ICON="data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAIAAACQkWg2AAAAZElEQVQ4jd2SsRKAMAhDTY///+U4oAHTOnRxkKlHHiTcFSSPnRpb9CcDUU/ARdKbZDjRK+neBEZpKSRkKCCrlxsUJmdIDUetn2+wbH7DM2sllMnlMK9XgJUn2DmD+qLbAT/4SydlLzMdCB1INwAAAABJRU5ErkJggg==">ADP iStatements</A>
        <DT><A HREF="https://myplan.johnhancock.com/login" ADD_DATE="1638560721" ICON="data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAABZklEQVQ4jaWTS2oCQRRFT1W1ndaoYKPgxICi7sBhIGQSHQjiIlyFO1Acu4esQHDiApw6EBeQj5GENgRb7cpAo612PpgLDZfbcOrVe/UEDDzOl2cA4h8AIYNz/Y0/zU4AoZDg5iZBLmeh1Mbn8+Hd/2zW4vY2gWmKYMDlpaLdzlGp2FiWpNXKUq3a21M15bJNp5MjGlXBAAClQMovLxBi3yYpDzMjuAeHsixJJKJ23q9fAVpDo5Hm7i4BQCZzwXy+/jtACOj3X7m/f0ZrqNWSXF/HTwG2beC6+/Fo3/RGo3d6vRcACgXrACBh0/lut0C9niSdNonFDKbTpb+Oo28vA2Cx8Hh4cGk2r3CcNZPJB4PBG1LCfL7GdfevfbHwcJw1eluigIEGiMcVpVIM05QMhw5PT0uUEhSLYWazFY+PLgCpVIhUKsR4/MFqpb0dYHtzX8n+7Hhddpl3NIWgvfo5M4Bz11kA3icsxGm1wuKBqgAAAABJRU5ErkJggg==">John Hancock</A>
        <DT><A HREF="https://login.microsoftonline.com/common/oauth2/v2.0/authorize?client_id=4765445b-32c6-49b0-83e6-1d93765276ca&redirect_uri=https%3A%2F%2Fwww.office.com%2Flandingv2&response_type=code%20id_token&scope=openid%20profile%20https%3A%2F%2Fwww.office.com%2Fv2%2FOfficeHome.All&response_mode=form_post&nonce=637741575417654915.MmU2ZTQ2OWEtYTA1My00ZmZiLWEyZWMtNTIzMzY2ZTRlMjAwNWUyMTFmYWQtOGJiZi00YmIwLWI2ZGQtYzRmODRkNGEzYzE3&ui_locales=en-US&mkt=en-US&state=X-EHHbAGtqr2MtbWBq3iNtEaO9rBMzgfSls0OU7FAj0LXZMlHRef0webe1p-0UevO_s4zasajhVU0QSz3vS0QvraBgGUJiS2trxi1SeJm6LX6eeVgh3TnGKsEK_RTWmbYf0JRXluNGV5e5lf5ijCtk2ydIxMENOFPFTT5duqAPl6WwmmxYDbhjLumzBvuV-CXKSm9tTnXoppDOK4C0wALSBkBlv6LHEIV_E2Nlgdr65RA65RXAieEVvUAieryT0tqmB12B1gME_Iu8Z25Jibjg&x-client-SKU=ID_NETSTANDARD2_0&x-client-ver=6.12.1.0&sso_reload=true#" ADD_DATE="1638560751" ICON="data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAAQklEQVQ4jWP87if3nwEH4Nz0iLF+FwNO+UY3BkYmXJLEglEDqGAAxYCRYcl7nPHMECPI+H8n7nTA6D6aDgaHARQDAKgRDRsLiHU6AAAAAElFTkSuQmCC">Office 365</A>
        <DT><A HREF="https://www.principal.com/" ADD_DATE="1638560778" ICON="data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAADIklEQVQ4jW2SW2xUVRSG/7XPPudMpzjt0M5Y0pZGCxZD1GggXqCIiWiIEHyZRowmJoYYfWmCN3whR4P4oDE8GCLhpQ8SsKgPkD4ICqN4gQQSMSmXjthIqTYzFPDM5Vz2Pnv5MI5pIv/z+r+1Vv6f0BIzgYgP/jbfv+fP2vYGmdcuBoHQMGYwk7Z7JR1/siO1fefyJZOtWQAgAIDnCfY8fvG7q5uPVZM9FaK7WAUJBBMkC5DRaHNlty3K69qcbV89tPRIC0IAE0C8tTi7eaIcfemDbXAcw7Ed2xGQHEO7KShdBxwbi234L/d2rvpwMF8CMwmA+IzPXd/ONPb6IdsUxjHYdfKMqY0d8tXRpdkNq1yzswNOBZHRNxI7UyzXPmDvpVTz9QKsh8end9DYLNP+SxHGrpiuQ1emD842+rFAz5+e3eJMlDSOXk7uPlmqTTIvAgCB3afbwzga5WrNQANCpChP4tOtvekZ7DtrF8bZwjhbBwadEz0JlyBcmgtMvVC8AAAQK77v5NL1ugUdEkehZcch96XlFDxPIPu7OTwCgxFKzrmuG2rKINA8YMlFxZW5JuDyub+4UQ0YKiIoZRKVUNlv5OB5BrkCsUd00fe7tp2Y3zXfQA/giLwQn+f2jmh4npBrBmw6rxi1WDMEoBsBV4he4DeeOkBPUH3LsT/W/HL0xtjVEMvQ1o4lOrj05j1dr9OGYggUSfww0m7dm5UCQQSKlYWGz+WqHl654qNPTt26la1VVf66dpalVNQYoviLt4YWb9w00HmzGT+YeP16ubaw652f5vR7rMME0hGwLKa2tOhwrZnVPemvh+7MTNwh7Qu7h3PTBKhWd/5r4o/n5/LPHjr7a0WLHCQxhC0gSSGVdZank+NTo6ufaRpBYEarxs0YwfTYAz2VR/oyO1JggUgxdGQQKwth3chEK3z8qAQ3T15o/hdATACOHF732f3d8n1HSIlIW9BKQ8VAogD/5/8ZFwCahaQikjNvP+0N97e/0u3gmqWNi0gLE8WEv/voduaFgCYESL4ZfXz/vufuW/tgPv1ufxqTrjAKN6/ddjsA/AP0F30vEsmmXQAAAABJRU5ErkJggg==">Principal Finanical Group</A>
        <DT><A HREF="https://www.rclco.com/" ADD_DATE="1638560804" ICON="data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAIAAACQkWg2AAABsklEQVQ4jZVSTUscQRDtqvlY58MIQdl1TAgiIQhKDt71tKAnD/mF+QF79pZLQIIQzGERskl23XHNwcGByExPz3RPVQ69WWQvYd/pVXW9aor3gJnFKnBXFSDAnME/ZgkALHUscZnnNRHZISICQPvz4gkRhRDMhEKIsiyapkZEIqqqEhGN0cwMAEpJKUtEVKqSsgRAdzweXVwMoig+O/twff0lTX/2++c3N9+Oj099359MfgDA5mY3zzNjzPb2a7i6+qx1w8x5nvn+WpK8ur9Pi+Kp3z/XujHGxPH6dPqr2018v5PnGYZhNBx+TdNxkrwhMvv7709OTutaIaLjOMboKFrf2upqrZnZcVx0XU/Kkpn39t41Ta21tmcAgBD24rZtWyGEECyEcIviz+HhkZTlePzd8/zRaDib3XqeV1WSiD3Pryr5+Jj1ejsA2LYGgyCK4xe7u2+lLDqdtcvLTwcHR57nDwYfHx5+F8XT3d2k19vJ82w2m25svIS2bZkJ0WEmZqjrKgwjY7RSKggCrTVRG4axUpUlQETPnbfGWZsWeG7cssBqlgK26MyDsFL4lpf9F38BlnUEmLAtpKIAAAAASUVORK5CYII=">RCLCO</A>
        <DT><A HREF="https://prod.member.myuhc.com/content/myuhc/en/public/member-ei-login.html" ADD_DATE="1638560813" ICON="data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAB/0lEQVQ4jYWRP2tUQRTFz7kz8142f4TVyIYoISz+KSRiZZEyIGKZIuIHsPEDWGkRv4CfQEhaKy2CAQuDTQpBRbCJmASJhEQha567m/f2zZtrsdGQt25yq5nhnjO/ey7Qt5T/TvPz8vLt1tTrDz/Hy132/0ICoKqqffPpe205kcmkmZ1tJO0cwPYpBlSdh30wsjq1+Gq9Njk+lDbDgetQ205sKHdL+eHxwsfL19dfPH2+vLH05dvv2pULZ/a1QGY1GCDu+e4Ywcra9uj9R6uLmzt+OhR5aq1mABCEoqpqpMOygRzNDew1wsB+29eC+kKM5FBKm2CsUJJ0LtI+BFQAsD4EK+xAIQoVAHAAMoIAkOfNkwlEyAAIqCSoVFEAiA0UAEIY7iE4FuIBAEK1u0miMAWg0CwD1RgV6UvQHSEOqn+vykCoCgmJYyg7GUNw/QiORiBJgBCwcCLqPSQSE4K1bKWFP9SxZNAlyNXlXtUDogPONKOI6e6vphsZiovhShTaqS8OdVoy6NbsdC2JrSQoyOqg3bpaH2183Uzcj1bLjAyaMFF17RNDxBP6i9XKu8EK/Y1r55fqY5XMCMWnQKOR6tydS42yQU+qcw9XxoarZvb2zYnECHfAUGSBlYhh4+5Mfe1UAwDQzYWBZ5+nZ2In54Yit9fxxe69W/X3JHu28AfuxuF3IV9RDwAAAABJRU5ErkJggg==">United Healthcare</A>
        <DT><A HREF="https://rclco.deltekfirst.com/RCLCOClient/" ADD_DATE="1638560826">Vision</A>
        <DT><A HREF="https://www.vsp.com/" ADD_DATE="1638560838" ICON="data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAABdElEQVQ4jaXRP0gCURwH8N+7J/cnNTkMGiqHRKyhghISmlyCagnCKWh1b2yIttqjrSAahUKioqGhpSKXiCCPhEQoSgvS7O7Uu/dek3LBeRr+pt/7fXkffrwH0GWhRnNwP+sWgSa/9Ey0zz3+rNLywsrEdbEdwDUaD+YTH+rdnEmr8nslPcUMPdHJBk3Ayw9MWoO6WfL9C6iS8q6AfQQAAHOCIUvBm04AZD2cKcszjKK4Rj5T8bHzy06Args5hUlFCYucsF7U9SHMoZLkwvvKSCi1gRBtCxxnc9GCqp3+GIbcmHEIwaDXs7UUDq41Z60AzTR2rJcBAChjUFC11cPHbPPHbIGTp/xwqVoft8tqhPAV04w4AnViugijuNV2ogsHHAHRRfMCh1/tMgQAwNiVIzAfCtX63T17di8sC0K6rFcuHAEAAAzm5qhf3hYx/kYAgBEigV7PLcV0MRGJGH82cqqjTMYv8dI0o/AmveQeYrGYac1/AYNBhNqS7XFXAAAAAElFTkSuQmCC">VPS</A>
        <DT><A HREF="https://participant.wageworks.com/home.aspx?ReturnUrl=%2F" ADD_DATE="1638560847" ICON="data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAACtUlEQVQ4jaWTS2hdZRSFv/3/55z7yr03Fi6mtsSBOLHTSjGhSSxFLOigQnHixI4cOFBwIlU4WFF0Ik4ddeCg4ExEUimmwVZKlaKgIBg7qEk01PRy34/z/3s7SFNBEQQ37Nl+rLVYC/5nSe+duZaL6RPVfn9d3mt3/suSvUZtODt/YjTSm0mcZBdnav5EN9S/7b5efbrx7tYugIGQI/c/5Sggu/mBekdrnzYzvxwC15wIDw5GURtVd9RSeQHAVkgETHJ0v9dWSABz1J5rVv3yYBQVrJUYfJ55eSwGU3GyBHwoVwi9N+ePqOflLJGsPw0ft97aWgNwyIqqaepFNHDFeeLqJFgs1ESRY5aT7eaHDpuXy42Kf6ns5exM6r/o5QeX7rFZmCpSRLOouup621vXDbslIiTCoX6ce7Sk7ni9LHPdUZx0xjosl3wSLXm2fe7gwwKPAKjxm3PddffQRwxVZT3zQq0kpqTLRQxbRTTDSEVIwdQ7brksWahmzmVeMOxqM+/edXuo9NI4mJgBnsXZNNwcFtZOPZjhh2OTIkyvYix6gRBNVLi0pwkwHhZfTQvbjQogi5Lf6YvZxUrmXDUVNw329QPnd34QZCma2biwftmKNQAxEAHr5vOfzZTkVH9ixBiOhsl0p1SrfZd5DihxQUZxZ5KkG/WSuP7UrjXz20t7CM5wj4Z9KYirpmIi7mTr/T+2JUye7I6KleobmzcKnz5VSUWcEwd6GcDO4BP5hAhgHbvQberZRjM54gp7HKB+/vcf7/vXybGs5n2nHX7RiV6wvDVDfmfg9p3a/GDzLkFPjwfhBnCy/crsrIFYjvv1VSpmemo6it87F56h4hsDzU4L2P4BA6T59ubP1zduL6vyfMiSuG9nOIwJL36zMTjeyLd/EnqbVo6r/0wZf4XnX5P4t5k/Acj3U1w4ND3dAAAAAElFTkSuQmCC">Wage Works</A>
    </DL><p>
</DL><p>
'@

$bookmarks | Out-File "RCLCObookmarks.html"
#endregion

# get zeedrive and mfiles client download links. Should always get latest version
$zeedrive = ((Invoke-WebRequest -UseBasicParsing -Uri "https://www.thinkscape.com/Map-Network-Drives-To-Office-365-OneDrive/").links | where href -like "*ZeeDrive.exe")[0].href
$mfiles = ([string]((Invoke-WebRequest -UseBasicParsing 'https://www.m-files.com/customers/product-downloads/download-update-links/#online%20desktop%20only').links.href | select-string 'M-Files_x64_eng_client')).trim()
$vonage = ((Invoke-WebRequest -UseBasicParsing 'https://businesssupport.vonage.com/articles/answer/Business-Apps').links | where href -like "*MobileConnect.bc-uc.win*")[0].href

# try to instantiate a Microsoft Office object
try { $excel = New-Object -ComObject Excel.Application; $mimecast = SetMimecastURL}
catch { }


#region M-Files Registry Keys
#Extract MFiles Version #
$version = (((($mfiles -split '_client*').replace('_','.')).replace('EV.msi','')).substring(1))
$mfilesVersion = ($version[1]).substring(0,($version[1].length) -1)
$SID = ([System.Security.Principal.NTAccount](GCIM Win32_ComputerSystem).username).translate([System.Security.Principal.SecurityIdentifier]).value

$mfilesreg = @"
Windows Registry Editor Version 5.00

[HKEY_USERS\$SID\SOFTWARE\Motive\M-Files\$mfilesversion\Client\MFClient\Vaults\RCLCO]
"ID"=dword:00000001
"InfoTip"="Browse to this folder to view the contents of this document vault."
"ProtocolSequence"="ncacn_http"
"NetworkAddress"="mfiles.rclco.com"
"Endpoint"="4466"
"Secured"=dword:00000000
"ServerVaultGUID"="{3CD33C45-52F7-4931-B0F0-AAB744461128}"
"ServerVaultName"="RCLCO"
"AuthType"=dword:00000001
"AutoLogin"=dword:00000001
"HTTPProxy"=""
"SPN"=""
"GUID"="{7CE2D3E1-6CCC-4C7C-BA34-2BFDAAE3E9E1}"
"@

"Importing M-Files registry Keys"
$mfilesReg | out-file "$env:temp\mfiles.reg"
reg import "$env:temp\mfiles.reg"
start-process cmd.exe -ArgumentList "/c `"reg add HKLM\SOFTWARE\Motive\M-Files\$mfilesversion\Client\MFClient /v IncludeIDsInNamesInIDView /t REG_DWORD /d 00000000`"" -Verb runas
del "$env:temp\mfiles.reg"
#endregion

# Package names for WinGet
$wingetPackages = @(
	'Google.Chrome'
	'Mozilla.Firefox'
	'Sonicwall.NetExtender'
	'Zoom.Zoom'
	'Zoom.Zoom.OutlookPlugin'
)

#region Process
$installedSoft = Get-RegUninstallKey
if (!(Get-Process | where processname -eq "ZeeDrive")){
DownloadInstaller -url $zeedrive -install -nowait}
if (!($installedSoft | where displayname -like "*M-Files*")){
DownloadInstaller -url $mfiles -install}
if (!($installedSoft | where displayname -like "*MobileConnect*")){
DownloadInstaller -url $vonage -install -SilentArgs "/qn"}

Install-WinGet
Install-VisualC
MimecastInstall
try {
winget
}
catch {
"Installing Winget"
Start-Process "ms-appinstaller:?source=https://aka.ms/getwinget"
}
$wingetPackages | foreach { WingetRun -PackageID $_ -RunType Install }

Unpin-App -AppName "Microsoft Store" -Verb taskbarunpin
Unpin-App -AppName Mail -Verb taskbarunpin
if ($excel){
$officepath = $excel.path
$StartMenuFolder = "$env:programdata\Microsoft\Windows\Start Menu\Programs"
Pin-ToTaskbar -targetfile "$StartMenuFolder\Google Chrome.lnk" -Action pin
Pin-ToTaskbar -targetfile "$officepath\OUTLOOK.exe" -Action PIN
Pin-ToTaskbar -targetfile "$officepath\EXCEL.exe" -Action PIN
Pin-ToTaskbar -targetfile "$officepath\WINWORD.exe" -Action PIN
}

# PowerSettings 
powercfg.exe -x -monitor-timeout-ac 15
powercfg.exe -x -monitor-timeout-dc 10
powercfg.exe -x -standby-timeout-dc 30
powercfg.exe -x -standby-timeout-ac 0
powercfg.exe -x -disk-timeout-ac 0
powercfg.exe -x -disk-timeout-dc 0


"Please import RCLCOBookmarks.html into Chrome/Edge"
#endregion
#region Cleanup
"Cleaning up temp files"
gci $env:temp\* -include *.exe,*.zip,*.msi | remove-item 
"done"
#endregion
