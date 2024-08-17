function Invoke-AsyncFileDownload {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [String]$Url,

        [Parameter(Mandatory)]
        [String]$FilePath
    )

    <#
    .SYNOPSIS
    Asynchronously downloads a file from a specified URL to a local path, displaying progress during the download.

    .DESCRIPTION
    The `Invoke-AsyncFileDownload` function downloads a file from the provided URL to the specified file path. 
    It checks for sufficient disk space before starting the download. The download progress is displayed 
    in real-time, showing the percentage completed and the amount of data downloaded. 

    .PARAMETER Url
    The URL of the file to be downloaded. This parameter is mandatory.

    .PARAMETER FilePath
    The local file path where the downloaded file will be saved. This parameter is mandatory.

    .EXAMPLE
    Invoke-AsyncFileDownload -Url "http://example.com/file.zip" -FilePath "C:\Downloads\file.zip"

    This command downloads the file from the specified URL and saves it to the "C:\Downloads\file.zip" location.

    .NOTES
    - This function has been confirmed to work on both Windows and Linux (Ubuntu) in both Windows PowerShell and PowerShell core. 

    .OUTPUTS
    None. The function outputs the progress of the download and messages indicating the download completion.

    .LINK
    https://learn.microsoft.com/en-us/dotnet/api/system.net.webclient.downloadfiletaskasync
    #>

    # Check if there is sufficient space to save the file
    $DownloadSize = [UInt64]::Parse(((Invoke-WebRequest -UseBasicParsing -Uri $Url -Method Head).Headers.'Content-Length'))
    $DownloadSizeFriendly = [String]::Format("{0:0.00} MB",($DownloadSize / 1MB))    
    $DriveLetter = $FilePath[0]
    $DriveAvailableStorage = (Get-PSDrive -Name $DriveLetter | Select-Object -ExpandProperty Free)
    
    if ($DownloadSize -gt $DriveAvailableStorage){
        Write-Error "Insufficient Drive Space to download file"
        return
    }    
    
    $WebClient = New-Object System.Net.WebClient
    $WebClient.DownloadFileTaskAsync($Url,$FilePath) | Out-Null
    
    Do {
        $FileSize = (Get-Item $FilePath).Length 
        $FileSizeFriendly = [String]::Format("{0:0.00} MB",($FileSize / 1MB))
        $PercentComplete = [Math]::Round((($FileSize / $DownloadSize ) * 100), 1)
        Write-Progress -Status "$FileSizeFriendly out of $DownloadSizeFriendly `($PercentComplete`%`)" -Activity "Downloading File..." -PercentComplete $PercentComplete
    }
    Until ($PercentComplete -eq 100)
    
    Write-Host "Download Complete!" -ForegroundColor Green
	Write-Host "File Saved to " $FilePath
    
    $WebClient.Dispose()
}
