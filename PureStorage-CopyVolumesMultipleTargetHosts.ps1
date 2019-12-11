#Make sure Pure's PowerShell SDK is installed: https://github.com/PureStorage-OpenConnect/powershell-toolkit
#Description: This script will collect all volumes on a defined host, and clone to 3 target hosts

#Set these variables
$api_token = "xx-xxx-xx-xxx-xx" 
$array = '11.22.33.44' 
$SourceHost = "Host1" #Source host with volumes attached
$DestHosts = @("Host2","Host3","Host4") #Define target hosts here

#Create FlashArray connection
$FlashArray = New-PfaArray -EndPoint $array -ApiToken $api_token -IgnoreCertificateError 

#Collect all volumes attached to source, copy to volume(s), attach to hosts
$SourceVolumes = (Get-PfaHostVolumeConnections -Array $FlashArray -Name $SourceHost).vol
ForEach ($Volume in $SourceVolumes){
    ForEach ($HostName in $DestHosts){
        New-PfaVolume -Array $FlashArray -VolumeName "$Volume$Hostname" -Source $Volume
        New-PfaHostVolumeConnection -Array $FlashArray -VolumeName "$Volume$Hostname" -HostName $Hostname    
    }
}


