#requires powershell 3.0
#gather a reponse and store in a variable
$website = "website.com/file.ext"
$SmtpServer = "1.1.1.1"
$SmtpFrom = "mail@domain.com"
$SmtpTo = "mail@domain.com"
$response =  Invoke-WebRequest -Uri $website
#create a variable only if we get a 200 on the web get
$databasecheck = $response | Where {$_.StatusCode -contains "200"}
#if we didn't get a 200 response stop the job and alert
If($databasecheck -eq $null)
    {
    Send-MailMessage -To $SmtpTo -Subject "$website GET Issue" -SmtpServer $SmtpServer -From NoReply@rsna.org -Body "GET to $website failed to respond with a 200 status code."
    }
#we received a 200, let's look for failure data in the page
Else
   {
      If($response.Content -match "[VERIFIED=false]")
        {
            Send-MailMessage -To $SmtpTo -Subject "$website Database Verify Failed" -SmtpServer $SmtpServer -From NoReply@rsna.org -Body "$website responded with failed database verification"
        }
    }
    


    