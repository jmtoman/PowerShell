$api_token = "xxxxxx-xxxx-xxx-xxxx-xxxxxxxx" 
$ArrayAddress = 'x.x.x.x' 

$FlashArray = New-PfaArray -EndPoint $ArrayAddress -ApiToken $api_token -IgnoreCertificateError 
$Volumes = Get-PfaVolumes -Array $FlashArray

ForEach ($volume in $volumes)
 
{
  $HostGroups = Get-PfaVolumeHostGroupConnections -Array $FlashArray -VolumeName $volume.name
  If ($HostGroups.host -eq $null)
 
    {
      Write-Host "$volume.name"
    }
}

