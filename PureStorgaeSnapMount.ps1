
#PowerCLI Tested with 6.5.1
#Pure Storage PowerShell SDK

#datetime variable can use to add granularity to script
$datetime = get-date -format yyyymmddss

#Pure Storage
$api_token = "xxxxxxxx-xxxxx-xxxx-xxxxx-xxxxxx" 
$array = 'x.x.x.x' #IP or DNS of array
$vn = 'volumetoclone'
$group = 'hostgroupname'
$volumetemp = $vn-$date

#VMware vSphere
$vcenter = 'x.x.x.x' #IP Address or DNS of vCenter/ESXi host
$cluster = 'cluster' #Cluster name
$UserName = 'username'
$SecurePassword = 'password' | ConvertTo-SecureString -AsPlainText -Force
$cred = New-Object System.Management.Automation.PSCredential -ArgumentList $UserName, $SecurePassword

#Connect to FlashArray
$FlashArray = New-PfaArray -EndPoint $array -ApiToken $api_token -IgnoreCertificateError
#Take snapshot
$LatestSnapshot = New-PfaVolumeSnapshots -Array $FlashArray -Sources $vn
#Create and mount snapshot
$volume = New-PfaVolume -Array $FlashArray -Source $LatestSnapshot.name -VolumeName $volumetemp -Overwrite
New-PfaHostGroupVolumeConnection -Array $FlashArray -VolumeName $volumetemp -HostGroupName $Group
#VMware vSphere API to mount new snapshot
Connect-VIServer -server $vcenter -Credential $cred -WarningAction SilentlyContinue
Get-Cluster $cluster | Get-VMHost | Get-VMHostStorage -RescanAllHba -RescanVmfs
Get-Cluster 'Cluster1' | Get-VMHost | Get-VMHostStorage -RescanAllHba -RescanVmfs
$hosts = get-vmhost -State connected
$esxcli = $hosts[0] | get-esxcli
$esxcli.storage.vmfs.snapshot.resignature($vn)
Start-Sleep -Seconds 30 # Wait for all connections to mount in VMware 

#Commented out - use this section to import guests as new instaces
#$snap = get-datastore | where {$_.name -like "snap-*$vn"}
#$vmxfile = ("[" + $snap.Name + "] $Server/$Server.vmx")
#$hosts = get-vmhost -State connected
#New-VM -VMHost $hosts[2].Name -VMFilePath $vmxfile -Name "$ServerNew"





