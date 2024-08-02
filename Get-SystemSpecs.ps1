function Get-SystemSpecs {
$processorSpecs = Get-CimInstance win32_processor
$processorName = $processorSpecs.Name
$processorSpeed = [string]([math]::round(($processorSpecs.CurrentClockSpeed /1000),2)) + 'ghz'
$processorCores = $processorSpecs.NumberOfCores
$processorThreads = $processorSpecs.ThreadCount
$ramTotal = "{0:N2}" -f (((Get-CimInstance CIM_PhysicalMemory | select -ExpandProperty Capacity) | measure -Sum).sum /1gb ) 
$system = Get-CimInstance Win32_ComputerSystem
$bios = Get-CimInstance Win32_Bios
$os = Get-CimInstance win32_operatingsystem
function HDD-Details {
$hdd = Get-CimInstance Win32_DiskDrive | where {$_.MediaType -like "Fixed*"}
$hdd | ForEach{$_.caption + ", Capacity: " + [math]::round(($_.Size / 1GB),'2') + "GB"  }
}

$Specs = [pscustomobject]@{
'Manufacturer' = $system.manufacturer
'Model' = $system.model
'SerialNumber' = $bios.SerialNumber
'BIOS_Version' = $bios.SMBIOSBIOSVersion
'Processor' = $processorName
'Cores' = $processorCores
'ThreadCount' = $processorThreads
'ProcessorClockSpeed' = $processorSpeed
'Physical Memory Size' = $ramTotal + ' GB'
'System Type' = $os.OSArchitecture
'Hard Drive(s)' = HDD-Details
'OS' = $os.caption
'OS_Version' = $os.Version
}
return $Specs
}
