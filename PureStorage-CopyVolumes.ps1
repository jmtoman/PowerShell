#simple script to copy volumes from a list, create a new volume with the date appended
$api_token = "xxxxxxxxxxxxxxxx" 
$array = 'xxxxxxxxxxxxxxx' 

$FlashArray = New-PfaArray -EndPoint $array -ApiToken $api_token -IgnoreCertificateError 
$datetime = get-date -format yyyymmddss

#import list from text file
$volumes = Get-Content C:\Files\Volumes.txt

ForEach ($volume in $volumes)
{
    new-pfavolume -array $flasharray -source $volume -VolumeName $volume-$datetime
}

