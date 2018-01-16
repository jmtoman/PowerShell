#Script requires PowerShell 3.0 + OnTap Toolkit
#Login to NetApp controllers from file list and get disk status

#declare our variables!
$password = ConvertTo-SecureString "unsecurestring" -AsPlainText –Force
$cred = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList "root",$password
$controllers = Get-Content C:\Lists.txt
$mailto = user@email.com
$mailfrom = user@email.com
#connect to the controllers from our text file
ForEach ($controller in $controllers)

{
    Connect-NaController $controller -Credential $cred
    #check for the word broken in the status field
    $broken = get-nadisk | where {$_.status -contains "broken"}

}

#if the status field has the word broken, send an email
If($broken)
{

	Send-MailMessage -To $mailto -Subject "Broken disks in NetApp Controller $controller" -SmtpServer 1.1.1.1 -From $mailfrom -Body "Broken disks in NetApp Controller $controller"

}

Else
{

Exit