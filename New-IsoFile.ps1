function New-IsoFile {
    <#
    .Synopsis
        Creates a new .iso file.
    .Description
        The New-IsoFile cmdlet creates a new .iso file containing content from chosen folders.
    .Example
        New-IsoFile "c:\tools","c:\Downloads\utils"
        This command creates a .iso file in $env:temp folder (default location) that contains c:\tools and c:\downloads\utils folders.
        The folders themselves are included at the root of the .iso image.
    .Example
        New-IsoFile -FromClipboard -Verbose
        Before running this command, select and copy (Ctrl-C) files/folders in Explorer first.
    .Example
        dir c:\WinPE | New-IsoFile -Path c:\temp\WinPE.iso -BootFile "${env:ProgramFiles(x86)}\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\Oscdimg\efisys.bin" -Media DVDPLUSR -Title "WinPE"
        This command creates a bootable .iso file containing the content from c:\WinPE folder, but the folder itself isn't included.
        Boot file etfsboot.com can be found in Windows ADK. Refer to IMAPI_MEDIA_PHYSICAL_TYPE enumeration for possible media types.
    .Notes
        Sourced from https://answers.microsoft.com/en-us/windows/forum/all/iso-file-creation/e57a4732-adcb-41ae-a49d-54c2c4218eff
        NAME: New-IsoFile
        AUTHOR: Chris Wu
        LASTEDIT: 03/23/2016 14:46:50
    #>

    [CmdletBinding(DefaultParameterSetName = 'Source')]
    Param (
        [parameter(Position = 1, Mandatory = $true, ValueFromPipeline = $true, ParameterSetName = 'Source')] $Source,
        [parameter(Position = 2)][string] $Path = "$env:temp\$((Get-Date).ToString('yyyyMMdd-HHmmss.ffff')).iso",
        [ValidateScript({ Test-Path -LiteralPath $_ -PathType Leaf })][string] $BootFile = $null,
        [ValidateSet('CDR', 'CDRW', 'DVDRAM', 'DVDPLUSR', 'DVDPLUSRW', 'DVDPLUSR_DUALLAYER', 'DVDDASHR', 'DVDDASHRW', 'DVDDASHR_DUALLAYER', 'DISK', 'DVDPLUSRW_DUALLAYER', 'BDR', 'BDRE')][string] $Media = 'DVDPLUSRW_DUALLAYER',
        [string] $Title = (Get-Date).ToString("yyyyMMdd-HHmmss.ffff"),
        [switch] $Force,
        [parameter(ParameterSetName = 'Clipboard')][switch] $FromClipboard
    )

    Begin {
        # Create a CompilerParameters object with the '/unsafe' option
        ($cp = New-Object System.CodeDom.Compiler.CompilerParameters).CompilerOptions = '/unsafe'
        
        # Check if the ISOFile type is already defined, if not, define it
        if (!('ISOFile' -as [type])) {
            Add-Type -CompilerParameters $cp -TypeDefinition @'
public class ISOFile
{
public unsafe static void Create(string Path, object Stream, int BlockSize, int TotalBlocks)
{
int bytes = 0;
byte[] buf = new byte[BlockSize];
var ptr = (System.IntPtr)(&bytes);
var o = System.IO.File.OpenWrite(Path);
var i = Stream as System.Runtime.InteropServices.ComTypes.IStream;

if (o != null) {
while (TotalBlocks-- > 0) {
i.Read(buf, BlockSize, ptr); o.Write(buf, 0, bytes);
}
o.Flush(); o.Close();
}
}
}
'@
        }

        # If a BootFile is specified, prepare the boot options
        if ($BootFile) {
            if ('BDR', 'BDRE' -contains $Media) {
                Write-Warning "Bootable image doesn't seem to work with media type $Media"
            }
            ($Stream = New-Object -ComObject ADODB.Stream -Property @{ Type = 1 }).Open() # adFileTypeBinary
            $Stream.LoadFromFile((Get-Item -LiteralPath $BootFile).Fullname)
            ($Boot = New-Object -ComObject IMAPI2FS.BootOptions).AssignBootImage($Stream)
        }

        # Define media types
        $MediaType = @('UNKNOWN', 'CDROM', 'CDR', 'CDRW', 'DVDROM', 'DVDRAM', 'DVDPLUSR', 'DVDPLUSRW', 'DVDPLUSR_DUALLAYER', 'DVDDASHR', 'DVDDASHRW', 'DVDDASHR_DUALLAYER', 'DISK', 'DVDPLUSRW_DUALLAYER', 'HDDVDROM', 'HDDVDR', 'HDDVDRAM', 'BDROM', 'BDR', 'BDRE')

        # Select the appropriate media type
        Write-Verbose -Message "Selected media type is $Media with value $($MediaType.IndexOf($Media))"
        ($Image = New-Object -com IMAPI2FS.MsftFileSystemImage -Property @{ VolumeName = $Title }).ChooseImageDefaultsForMediaType($MediaType.IndexOf($Media))

        # Create the target file if it does not exist or overwrite if Force is specified
        if (!($Target = New-Item -Path $Path -ItemType File -Force:$Force -ErrorAction SilentlyContinue)) {
            Write-Error -Message "Cannot create file $Path. Use -Force parameter to overwrite if the target file already exists."
            break
        }
    }

    Process {
        # If FromClipboard is specified, get the clipboard content
        if ($FromClipboard) {
            if ($PSVersionTable.PSVersion.Major -lt 5) {
                Write-Error -Message 'The -FromClipboard parameter is only supported on PowerShell v5 or higher'
                break
            }
            $Source = Get-Clipboard -Format FileDropList
        }

        # Add each item in Source to the target image
        foreach ($item in $Source) {
            if ($item -isnot [System.IO.FileInfo] -and $item -isnot [System.IO.DirectoryInfo]) {
                $item = Get-Item -LiteralPath $item
            }

            if ($item) {
                Write-Verbose -Message "Adding item to the target image: $($item.FullName)"
                try {
                    $Image.Root.AddTree($item.FullName, $true)
                } catch {
                    Write-Error -Message ($_.Exception.Message.Trim() + ' Try a different media type.')
                }
            }
        }
    }

    End {
        # If a boot image is specified, assign the boot options
        if ($Boot) {
            $Image.BootImageOptions = $Boot
        }

        # Create the result image
        $Result = $Image.CreateResultImage()
        
        # Write the ISO file
        [ISOFile]::Create($Target.FullName, $Result.ImageStream, $Result.BlockSize, $Result.TotalBlocks)
        
        Write-Verbose -Message "Target image ($($Target.FullName)) has been created"
        $Target
    }
}
