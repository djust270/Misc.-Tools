function Get-WeatherForecast {
param (
[parameter(mandatory=$true)]
[string]$zipcode
)
$today = [System.DateTime]::Now

#region Weather Variables

#Get Lattitude and Longitude for your zip code
$getLatLong = Invoke-restmethod -uri "https://api.promaptools.com/service/us/zip-lat-lng/get/?zip=$zipcode&key=17o8dysaCDrgv1c" | select -ExpandProperty output

#Get weather forecast endpoint for your zipcode
$getPoints = Invoke-RestMethod -uri "https://api.weather.gov/points/$($getLatLong.latitude),$($getLatLong.longitude)"

#Get 7 day weather forecast
$retryCount = 0
do {    
    try {
    $weatherGet = Invoke-RestMethod -Uri $getPoints.properties.forecast -ErrorAction Stop
    }
    Catch {
    $retryCount++
     sleep -Milliseconds 500
    }
}
Until (($weatherGet) -or ($retryCount -eq 4))

#Get todays date. Manipulate string to match JSON date object returned from api.weather.gov
$TodayManipulate = (($today).ToShortDateString() -replace '/','-') -split '-'
$today = "$($TodayManipulate[2] + '-' + $TodayManipulate[0] + '-' + $TodayManipulate[1])*"

# Do the same for tomorrows date
$TomorrowManipulate = (((get-date).AddDays(1)).ToShortDateString() -replace '/','-') -split '-'
$tomorrow = "$($TomorrowManipulate[2] + '-' + $TomorrowManipulate[0] + '-' + $TomorrowManipulate[1])*"
$tomorrow1= "$(((Get-Date).AddDays(1)).ToShortDateString())*"

# Get today and tomorrows forecasted temperatures
$todaysTemp = Invoke-RestMethod -Uri 'https://api.weather.gov/gridpoints/LWX/102,88' | select -ExpandProperty properties | select -ExpandProperty temperature | select -ExpandProperty values | select -ExcludeProperty values | where validtime -like "$($today)" | sort value
$tomorrowsTemp = Invoke-RestMethod -Uri 'https://api.weather.gov/gridpoints/LWX/102,88' | select -ExpandProperty properties | select -ExpandProperty temperature | select -ExpandProperty values | select -ExcludeProperty values | where validtime -like "$($tomorrow)" | sort value

# Convert temps to farenheit
$TodaysTempF = $todaysTemp | select @{n="Temp";e={$_.value | foreach {[int]($_ * 1.8) + 32}}}
$tomorrowsTempF = $tomorrowsTemp | select @{n="Temp";e={$_.value | foreach {[int]($_ * 1.8) + 32}}}

# Get low and high temperatures, selecting by index of array
$LowTempToday = ($TodaysTempF.Temp)[0]
$LowTempTomorrow = ($tomorrowsTempF.Temp)[0]
$HighTempToday = ($TodaysTempF.Temp)[-1]
$HighTempTomorrow = ($tomorrowsTempF.Temp)[-1]

# Filter 7 day forecast for today and tomorrows forecast
$forecast = $weatherGet | select -ExpandProperty properties | select -ExpandProperty periods | where number -eq 1
if ($host.Version.major -lt 6.0){
    $tomorrowsForecast = ($weatherGet | select -ExpandProperty properties | select -ExpandProperty periods | where startTime -like $tomorrow)[0]
    }
else {
    $tomorrowsForecast = ($weatherGet | select -ExpandProperty properties | select -ExpandProperty periods | where startTime -like $tomorrow1)[0]

}
#endregion


Write-Host "Forecast for $((Get-Date).ToShortDateString())" -foregroundcolor Green -backgroundcolor Black
Write-Host  "Todays Low Temperature: $($LowTempToday)"
Write-host "Todays High Temperature: $($HighTempToday)"

Write-Host "Detailed Forecast: `n$($forecast.detailedForecast)" -ForegroundColor Green -BackgroundColor Black

write-host "`nTomorrows Low Temperature: $($LowTempTomorrow)"
write-host "Tomorrows High Temperature: $($HighTempTomorrow)"

Write-Host "`nTomorrows Forecast:`n$($tomorrowsForecast.detailedForecast)" -foregroundcolor Green -BackgroundColor Black

}

