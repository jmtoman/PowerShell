$api_token = "dcea5e9f-f535-de9e-24fa-cdff7f1451aa" 
$ArrayAddress = '10.224.112.110' 

$FlashArray = New-PfaArray -EndPoint $ArrayAddress -ApiToken $api_token -IgnoreCertificateError 
$Volumes = Get-PfaVolumes -Array $FlashArray

ForEach ($volume in $volumes)
 
{
  $HostGroups = Get-PfaVolumeHostGroupConnections -Array $FlashArray -VolumeName $volume.name
  If ($HostGroups.host -eq $null)
 
    {
      Write-Host $volume.name
    }
}