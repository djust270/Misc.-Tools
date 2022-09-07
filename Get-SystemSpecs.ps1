function Get-SystemSpecs {
$processorSpecs = gcim win32_processor
$processorName = $processorSpecs.Name
$processorSpeed = [string]([math]::round(($processorSpecs.CurrentClockSpeed /1000),2)) + 'ghz'
$processorCores = $processorSpecs.NumberOfCores
$processorThreads = $processorSpecs.ThreadCount
$ramTotal = "{0:N2}" -f (((gcim CIM_PhysicalMemory | select -ExpandProperty Capacity) | measure -Sum).sum /1gb ) 

function HDD-Details {
$hdd = gcim Win32_DiskDrive | where {$_.MediaType -like "Fixed*"}
$hdd | ForEach{$_.caption + ", Capacity: " + [math]::round(($_.Size / 1GB),'2') + "GB"  }
}

$Specs = [pscustomobject]@{
'Processor' = $processorName
'Cores' = $processorCores
'ThreadCount' = $processorThreads
'ProcessorClockSpeed' = $processorSpeed
'Physical Memory Size' = $ramTotal + ' GB'
'System Type' = gcim win32_operatingsystem | select -ExpandProperty OSArchitecture
'Hard Drive(s)' = HDD-Details
'Serial' = gcim win32_bios | select -expandproperty serialnumber
'OS' = gcim win32_operatingsystem | select -expandproperty caption
}
return $Specs
}