# Prevents screen lock by sending key presses at a random interval
$w = New-Object -ComObject Wscript.Shell
while($true){
start-sleep (Get-Random -Maximum 15 -Minimum 5)
$w.SendKeys('abc')
}
