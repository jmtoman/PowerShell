
#Post login details to website and look for a 200 status code
#Post parameters based on fields from page

#create an array for the post fields
$fields = @{tUN='username';tPW='password'}
$website = "https://website.com/path.extension"
$SmtpServer = "1.1.1.1"
$SmtpFrom = "email@domain.com"
$SmtpTo = "email@domain.com" 

$getresponse = Invoke-WebRequest -Uri $website 
If($getresponse.StatusCode -notcontains "200")
{
    Send-MailMessage -To $SmtpTo -Subject "$website GET Issue" -SmtpServer $SmtpServer -From NoReply@rsna.org -Body "GET to $website failed to respond with a 200 status code."
}
#create a variable out of the response of our post 
$postresponse = Invoke-WebRequest -Uri $website -Method POST -Body $fields
#create a variable if the previous does not contain a 200 status
$failure = $postresponse | where {$_.StatusCode -notcontains "200"}
#now we send an email if the failure variable exists
If($failure)
{
    Send-MailMessage -To $SmtpTo -Subject "$website POST Issue" -SmtpServer $SmtpServer -From $SmtpFrom -Body "Post to $website failed to respond with a 200 status code."
}
