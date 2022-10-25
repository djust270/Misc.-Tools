function Invoke-AsyncFileDownload {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [String]$Url,
        [Parameter(Mandatory)]
        [String]$FilePath 
    )
    # Check if there is sufficient spaace to save the file
    $DownloadSize = [UInt64]::Parse(((Invoke-WebRequest -UseBasicParsing -Uri $Url -Method Head).Headers.'Content-Length'))
    $DownloadSizeFriendly = [String]::Format("{0:0.00} MB",($DownloadSize / 1MB))
    $DriveLetter = $FilePath[0]
    $DriveAvailableStorage = (Get-Volume -DriveLetter $DriveLetter).SizeRemaining
    if ($DownloadSize -gt $DriveAvailableStorage){
        Write-Error "Insufficient Drive Space to download file"
        return
    }    
    $WebClient = New-Object System.Net.WebClient
    $WebClient.DownloadFileTaskAsync($Url,$FilePath) | Out-Null
    Do {
        Start-Sleep -Seconds 3
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