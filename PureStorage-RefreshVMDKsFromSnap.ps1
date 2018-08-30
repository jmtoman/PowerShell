# PREREQUISITES & ASSUMPTIONS
# * Assumes execution directly from development SQL Server and that all drive letters match from production to development instances.
# * Assumes logs and database have their own VMDK disks.
# * Assumes production and development VMs are in the same vSphere Cluster with the same host group mapping on the FlashArray
# * Script to be run directly on development instance.  Tested with development cloned from production.
# * Assumes the term 'snap' is only used for datastores built from snapshots.
# * The script will fail if volumes are part of a volume group.

# Check for required modules and install if needed
Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
If (-Not(Get-Module -ListAvailable -Name PureStoragePowerShellSDK)) {
        Install-Module -Name PureStoragePowerShellSDK -Scope CurrentUser
}
If (-Not(Get-Module -ListAvailable -Name VMware.VIM*)) {
        Install-Module -Name VMware.VIM -Scope CurrentUser
}
#############################
# SET THESE VARIABLES BELOW #                           
#############################

# FLASHARRAY CONNECTION INFO
$ArrayAddress = "xxx.xxx.xxx.xxx" # ENTER IP OR DNS OF FLASHARRAY
$Token = "xxx-xxxx-xxxx-xxxx" # ENTER API TOKEN FROM FLASHARRAY

# VMWARE INFORMATION
$vcenter = '111.222.333.444' # ENTER IP OR DNS NAME OF VCENTER
$UserName = 'administrator@vsphere.local' # VSPHERE USERNAME
$SecurePassword = 'SuperPassword!!!' | ConvertTo-SecureString -AsPlainText -Force
$DevVM = "AwesomeDevelopment" # NAME OF DEVELOPMENT SQL VM
$ProdVM = "AwesomeProduction" # NAME OF PRODUCTION SQL VM

# Enter the VMDK numbers
$Logs = "1" #VMDK number of Logs disk
$Data = "2" #VMDK number of Data disk

#############################

# Connect to FlashArray
$FlashArray = New-PfaArray -EndPoint $ArrayAddress -ApiToken $Token -IgnoreCertificateError

# Connect to vCenter
$cred = New-Object System.Management.Automation.PSCredential -ArgumentList $UserName, $SecurePassword
Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -confirm:$false
Connect-VIServer -server $vcenter -Credential $cred -WarningAction SilentlyContinue

# Match development VM to vSphere Cluster and gather host information
$Cluster = (Get-Cluster -VM $DevVM).Name
$Hosts = Get-Cluster $Cluster | Get-VMhost -State Connected

# Match production datastore to FlashArray volume
$datastore = Get-Datastore -VM $ProdVm
$lun = $datastore.ExtensionData.Info.Vmfs.Extent.DiskName
$volserial = ($lun.ToUpper()).substring(12)
$purevolumes = Get-PfaVolumes -Array $FlashArray
$ProdVol = ($purevolumes | where-object { $_.serial -eq $volserial }).Name
$DevVol = "$ProdVol-Dev"

# Find FlashArray host group for production volume
$HGROUP = (Get-PFAVolumeHostGroupConnections -Array $FlashArray -VolumeName $ProdVol).hgroup[0]

# Stop the SQL service and take all Windows disks offline except system drive
Stop-Service -Name MSSQLSERVER
Get-Disk | Where-Object IsSystem -eq $False | Set-Disk -IsOffline:$True

# Remove any VMDK from a snapshot datastore or the logs/data VMDK
$GetDisks = Get-HardDisk -VM $DevVM
ForEach ($Disk in $GetDisks){
        If ($Disk.Filename -like '*snap*' -or "*_$logs.vmdk" -or "*_$data.vmdk") {
        Remove-HardDisk -Confirm:$false
        }
}

# Remove the snapshot datastore from VMware, destroy and eradicate volume on the FlashArray
# Only removes snapshot volumes mounted to development VM
$SnapDatastore = Get-Datastore -Name 'snap*' -RelatedObject $DevVM
If ($SnapDatastore.count -ge 1){
    Remove-Datastore -Datastore $SnapDatastore -VMhost $hosts[0] -confirm:$false
    Remove-PfaHostGroupVolumeConnection -Array $FlashArray -VolumeName $DevVol -HostGroupName $hgroup
    Remove-PfaVolumeOrSnapshot -Array $FlashArray -Name $DevVol 
    Remove-PfaVolumeOrSnapshot -Array $FlashArray -Name $DevVol -Eradicate
    Get-Cluster $cluster | Get-VMHost | Get-VMHostStorage -RescanAllHba -RescanVmfs
}

# Build a development volume from production, attach it to the host group
New-PfaVolume -Array $FlashArray -VolumeName $DevVol -Source $ProdVol -Overwrite
New-PfaHostGroupVolumeConnection -Array $FlashArray -HostGroupName $hgroup -VolumeName $DevVol

# Resignature and mount in vSphere
Get-Cluster $cluster | Get-VMHost | Get-VMHostStorage -RescanAllHba -RescanVmfs
$hosts = get-cluster $cluster | get-vmhost -State connected
$esxcli = $hosts[0] | get-esxcli
$esxcli.storage.vmfs.snapshot.resignature($ProdVol)
Get-Cluster $cluster | Get-VMHost | Get-VMHostStorage -RescanAllHba -RescanVmfs

# Attach snapshot VMDKs
$SnapDatastore = Get-Datastore -Name 'snap*'
New-HardDisk -VM $DevVM -DiskPath "[$SnapDatastore] $ProdVM/${PRODVM}_$Logs.vmdk" 
New-HardDisk -VM $DevVM -DiskPath "[$SnapDatastore] $ProdVM/${PRODVM}_$Data.vmdk" 

# Bring Windows disks online and start SQL services
Get-Disk | Where-Object $_.IsOffline | Set-Disk -IsOffline:$false 
Start-Service -Name MSSQLSERVER

# Disconnect sessions
Disconnect-VIServer -Server $vcenter -Confirm:$false
Disconnect-PfaArray -Array $FlashArray
