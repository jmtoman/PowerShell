# PREREQUISITES & ASSUMPTIONS
# * PSRemoting must be enabled.  You can enable via the Powershell command 'Enable-PSRemoting'.
# * Assumes execution directly from development SQL Server and that all drive letters match from production to development instances.
# * Requires Pure Storage PowerShell Toolkit to be installed.  You can install via 'Install-Module -Name PureStoragePowerShellToolkit'
# * Requires VMware PowerCLI to be installed.  You can install via 'Install-Module -Name VMware.PowerCLI -RequiredVersion 6.5.4.7155375'
# * Assumes default SQL instance name.  For a single instance server this will be MSSQLSERVER.
# * Script to be run directly on development instance.  Tested with development cloned from production.
# * Assumes the term 'snap' is only used for datastores built from snapshots.

#############################
#         TODO

If (-Not(Get-Module -ListAvailable -Name PureStoragePowerShellSDK)) {
        Exit
}

#############################
#          STEP 1           #
# SET THESE VARIABLES BELOW #                           
#############################

# FLASHARRAY CONNECTION INFO
$ArrayAddress = "x.x.x.x" # ENTER IP OR DNS OF FLASHARRAY
$Token = "x-x-x-x" # ENTER API TOKEN FROM FLASHARRAY
$hgroup = "Name"

# VMWARE INFORMATION
$vcenter = 'x.x.x.x' # ENTER IP OR DNS NAME OF VCENTER
$cluster = 'Name' # ENTER CLUSTER NAME
$UserName = 'administrator@vsphere.local' # VSPHERE USERNAME
$SecurePassword = 'SuperSecurePassword' | ConvertTo-SecureString -AsPlainText -Force
$cred = New-Object System.Management.Automation.PSCredential -ArgumentList $UserName, $SecurePassword
$DevVM = "Dev" # NAME OF DEVELOPMENT SQL VM
$ProdVM = "Prod" # NAME OF PRODUCTION SQL VM

# LIST OF PURE STORAGE VOLUMES
$ProdVol = "Prod" # SPECIFIES YOUR PRODUCTION VOLUME YOU WANT TO CLONE ON TOP DEVELOPMENT
$DevVol = "Dev" # THE NAME OF THE DEVELOPMENT VOLUME TO BE OVERWRITTEN


#############################
#          STEP 2           #
#    CREATE CONNECTIONS     #                           
#############################

# CREATE FLASHARRAY CONNECTION
$FlashArray = New-PfaArray -EndPoint $ArrayAddress -ApiToken $Token -IgnoreCertificateError

# CREATE VMWARE CONNECTION
Set-PowerCLIConfiguration -InvalidCertificateAction ignore -confirm:$false
Connect-VIServer -server $vcenter -Credential $cred -WarningAction SilentlyContinue
# GATHER HOST DATA
$hosts = get-cluster $cluster | get-vmhost -State connected
 
#############################
#          STEP 3           #
#   CLEANUP PREVIOUS RUN    #
#############################                           

# STOP SQL SERVICE
Stop-Service -Name MSSQLSERVER

# OFFLINE SQL DISKS IN WINDOWS
# ALL DISKS EXCEPT SYSTEM WILL GO OFFLINE
$disks = Get-Disk | where-object IsSystem -eq $False
ForEach ($disk in $disks) {
            $disknumber = $disk.Number
            $cmds = "`"SELECT DISK $disknumber`"",
                    "`"OFFLINE DISK`""
            $scriptblock = [string]::Join(",",$cmds)
            $diskpart = $ExecutionContext.InvokeCommand.NewScriptBlock("$scriptblock | DISKPART")
            Invoke-Command -ComputerName localhost -ScriptBlock $diskpart
        }

# REMOVE PREVIOUS RUN VMDKS FROM DEVELOPMENT
Get-HardDisk -VM $DevVM | Where-Object {$_.Filename -like '*snap*'} | Remove-HardDisk -Confirm:$false

# CHECK NO VMS ARE REGISTERED ON REFRESH DATASTORE, EXIT SCRIPT IF GUESTS ARE FOUND
$VMs = Get-Datastore | Where-Object {$.Name -like '*snap*'}
If ($VMs.count -ge 1)
        {
                Exit
        }
Else
        {
                $oldds = get-datastore -name 'snap*'
                Remove-Datastore -Datastore $oldds -VMhost $hosts[0]
        }

# DISCONNECT HOST GROUP
Remove-PfaHostGroupVolumeConnection -Array $FlashArray -VolumeName $DevVol -HostGroupName $hgroup

# DELETE AND ERADICATE VOLUME
Remove-PfaVolumeOrSnapshot -Array $FlashArray -Name $DevVol
Remove-PfaVolumeOrSnapshot -Array $FlashArray -Name $DevVol -Eradicate

# RESCAN VMWARE HBAS
Get-Cluster $cluster | Get-VMHost | Get-VMHostStorage -RescanAllHba -RescanVmfs

#############################
#         STEP 4            #
#   BEGIN REFRESH PROCESS   #
#############################                           

# REFRESH PRODUCTION VOLUME TO DEVELOPMENT
New-PfaVolume -Array $FlashArray -VolumeName $DevVol -Source $ProdVol -Overwrite
#TO DO ATTACH HOST HGROUP

# VMWARE WORK
Get-Cluster $cluster | Get-VMHost | Get-VMHostStorage -RescanAllHba -RescanVmfs
$hosts = get-cluster $cluster | get-vmhost -State connected
$esxcli = $hosts[0] | get-esxcli
$esxcli.storage.vmfs.snapshot.resignature($ProdVol)
Get-Cluster $cluster | Get-VMHost | Get-VMHostStorage -RescanAllHba -RescanVmfs

# ATTACH SNAP VMDKS TO VM
$SNAPDS = Get-Datastore -Name 'snap*'
# MODIFY TO MATCH VMDK NUMBERING AS NEEDED
New-HardDisk -VM $DevVM -DiskPath "[$SNAPDS] $ProdVM/${PRODVM}_1.vmdk" #LOGS - VERIFY THE LOCATION!
New-HardDisk -VM $DevVM -DiskPath "[$SNAPDS] $ProdVM/${PRODVM}_2.vmdk" # DATABASE - VERIFY THE LOCATION!

# ONLINE SQL DISKS
# SIMPLE LOOP TO ONLINE ANY DISKS THAT ARE OFFLINE
# Get-Disk | ? IsOffline | Set-Disk -IsOffline:$false # TEST THIS CODE
$disks = Get-Disk
ForEach ($disk in $disks) {
        If ($disk.OperationalStatus -ne 1) {
            $disknumber = $disk.Number
            $cmds = "`"SELECT DISK $disknumber`"",
                    "`"ONLINE DISK`""
            $scriptblock = [string]::Join(",",$cmds)
            $diskpart = $ExecutionContext.InvokeCommand.NewScriptBlock("$scriptblock | DISKPART")
            Invoke-Command -ComputerName localhost -ScriptBlock $diskpart
        }
    }

# START SQL SERVICE
Start-Service -Name MSSQLSERVER

#############################
#         STEP 5            #
#    DISCONNECT SESSIONS    #
############################# 

# DISCONNECT VCENTER
Disconnect-viserver -Server $vcenter -confirm:$false

# DISCONNECT FLASHARRAY
Disconnect-PfaArray -Array $flasharray
