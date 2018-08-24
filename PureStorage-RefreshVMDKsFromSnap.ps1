# PREREQUISITES & ASSUMPTIONS
# * Assumes execution directly from development SQL Server and that all drive letters match from production to development instances.
# * Assumes logs and database have their own VMDK disks.
# * Script to be run directly on development instance.  Tested with development cloned from production.
# * Assumes the term 'snap' is only used for datastores built from snapshots.
# * Assumes the dev VM has had its data/log disks removed after being cloned from production, but before running this script.
# * The script will fail if volumes are part of a volume group.

# Check for required modules and install if needed
Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
If (-Not(Get-Module -ListAvailable -Name PureStoragePowerShellSDK)) {
        Install-Module -Name PureStoragePowerShellSDK -Scope AllUsers
}
If (-Not(Get-Module -ListAvailable -Name VMware.VIM*)) {
        Install-Module -Name VMware.VIM -Scope AllUsers
}
#############################
# SET THESE VARIABLES BELOW #                           
#############################

# FLASHARRAY CONNECTION INFO
$ArrayAddress = "x.x.x.x" # ENTER IP OR DNS OF FLASHARRAY
$Token = "x.x.x.x" # ENTER API TOKEN FROM FLASHARRAY

# VMWARE INFORMATION
$vcenter = 'x.x.x.x' # ENTER IP OR DNS NAME OF VCENTER
$UserName = 'administrator@vsphere.local' # VSPHERE USERNAME
$SecurePassword = 'password' | ConvertTo-SecureString -AsPlainText -Force
$DevVM = "dev" # NAME OF DEVELOPMENT SQL VM
$ProdVM = "prod" # NAME OF PRODUCTION SQL VM

# Enter the VMDK numbers
$Logs = "1" #VMDK number of Logs disk
$Data = "2" #VMDK number of Data disk

#############################

# CREATE FLASHARRAY CONNECTION
$FlashArray = New-PfaArray -EndPoint $ArrayAddress -ApiToken $Token -IgnoreCertificateError

# CREATE VMWARE CONNECTION
$cred = New-Object System.Management.Automation.PSCredential -ArgumentList $UserName, $SecurePassword
Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -confirm:$false
Connect-VIServer -server $vcenter -Credential $cred -WarningAction SilentlyContinue

# MATCH VM TO CLUSTER
$cluster = (get-cluster -vm $prodvm).name

# GATHER HOST DATA
$hosts = get-cluster $cluster | get-vmhost -State connected

# MATCH DATASTORE TO PURE VOLUME
$datastore = Get-Datastore -VM $ProdVm
$lun = $datastore.ExtensionData.Info.Vmfs.Extent.DiskName
$volserial = ($lun.ToUpper()).substring(12)
$purevolumes = Get-PfaVolumes -Array $FlashArray
$ProdVol = ($purevolumes | where-object { $_.serial -eq $volserial }).Name
$DevVol = "$ProdVol-Dev"

# FIND HOST GROUP FOR PROD VOLUME
$HGROUP = (Get-PFAVolumeHostGroupConnections -Array $FlashArray -VolumeName $ProdVol).hgroup[0]

# STOP SQL SERVICE
Stop-Service -Name MSSQLSERVER

# OFFLINE SQL DISKS IN WINDOWS
# ALL DISKS EXCEPT SYSTEM WILL GO OFFLINE
Get-Disk | where-object IsSystem -eq $False | Set-Disk -IsOffline:$True

# REMOVE PREVIOUS RUN VMDKS FROM DEVELOPMENT
# ASSUMES CLONED DISKS ALREADY REMOVED
Get-HardDisk -VM $DevVM | Where-Object {$_.Filename -like '*snap*'} | Remove-HardDisk -Confirm:$false

# REMOVE DATASTORE FROM VMWARE
$SNAPDS = Get-Datastore -Name 'snap*'
If ($SNAPDS.count -ge 1){
    Remove-Datastore -Datastore $SNAPDS -VMhost $hosts[0] -confirm:$false
    Remove-PfaHostGroupVolumeConnection -Array $FlashArray -VolumeName $DevVol -HostGroupName $hgroup
    Remove-PfaVolumeOrSnapshot -Array $FlashArray -Name $DevVol 
    Remove-PfaVolumeOrSnapshot -Array $FlashArray -Name $DevVol -Eradicate
    Get-Cluster $cluster | Get-VMHost | Get-VMHostStorage -RescanAllHba -RescanVmfs
}

# REFRESH PRODUCTION VOLUME TO DEVELOPMENT
New-PfaVolume -Array $FlashArray -VolumeName $DevVol -Source $ProdVol -Overwrite
# ATTACH VOLUME TO HOST GROUP
New-PfaHostGroupVolumeConnection -Array $FlashArray -HostGroupName $hgroup -VolumeName $DevVol

# VMWARE WORK
Get-Cluster $cluster | Get-VMHost | Get-VMHostStorage -RescanAllHba -RescanVmfs
$hosts = get-cluster $cluster | get-vmhost -State connected
$esxcli = $hosts[0] | get-esxcli
$esxcli.storage.vmfs.snapshot.resignature($ProdVol)
Get-Cluster $cluster | Get-VMHost | Get-VMHostStorage -RescanAllHba -RescanVmfs

# ATTACH SNAP VMDKS TO VM
$SNAPDS = Get-Datastore -Name 'snap*'
# MODIFY TO MATCH VMDK NUMBERING AS NEEDED
New-HardDisk -VM $DevVM -DiskPath "[$SNAPDS] $ProdVM/${PRODVM}_$Logs.vmdk" 
New-HardDisk -VM $DevVM -DiskPath "[$SNAPDS] $ProdVM/${PRODVM}_$Data.vmdk" 

# ONLINE SQL DISKS
Get-Disk | ? IsOffline | Set-Disk -IsOffline:$false 

# START SQL SERVICE
Start-Service -Name MSSQLSERVER

# DISCONNECT VCENTER
Disconnect-VIServer -Server $vcenter -Confirm:$false

# DISCONNECT FLASHARRAY
Disconnect-PfaArray -Array $FlashArray
