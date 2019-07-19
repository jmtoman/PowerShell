

$Computer = Get-Content env:computername
$Program = get-process '<process name>' -erroraction SilentlyContinue

If ($Program -eq $null){
    Start-Process -filepath '<process location>'
    Send-MailMessage -To email@domain.com -Subject "Scanner Process on $Computer Restarted" -SmtpServer 1.1.1.1 -From email@domain.com -Body "$Program on $Computer Restarted"
}
