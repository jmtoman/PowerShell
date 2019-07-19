
#Logging Information
#A log file will be placed in the root of the user profile of whomever is running this script
$LogFolder = $env:userprofile
$LogFile = $logfolder + '\' + (Get-Date -Format o | ForEach-Object {$_ -Replace ':', '.'}) + "PlannedFailover.log"

$SourceStoragePolicy = "Name of Storage Policy Created"

$SourceVC = "x.x.x.x"
$DestVC = "x.x.x.x"

#Name of the destination vSphere cluster you are failing the VMs over to
$Cluster = "DestinationCluster"

$Cred = $Host.ui.PromptForCredential("vCenter Credentials", "Please enter your vCenter username and password.", "","")
#vCenter Credentials - Assumes same credential for source and target vCenter
Connect-VIServer -Server $SourceVC -Credential $Cred -ErrorAction Stop
Connect-VIServer -Server $destVC -Credential $Cred -ErrorAction Stop


Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Confirm:$False

#Build array of VMs based off input storage policy name - from source vCenter
$VMs = Get-SpbmStoragePolicy -Name $SourceStoragePolicy -Server $SourceVC | Get-VM

#Shutdown VM and verify PoweredOff state - checking for graceful shutdown
ForEach ($VM in $VMs){
If ($VM.PowerState -eq "PoweredOn")
    {
            Shutdown-VMGuest -VM $VM -Confirm:$False -ErrorAction SilentlyContinue
            #Stop-VM $vm -Confirm:$False
            Add-Content $LogFile ('[' + (Get-Date -Format G) + '] ' + 'Powering down virtual machine ' + $VM)
            Do {        
                    Start-Sleep -s 5             
             }Until ((Get-VM -Name $VM).PowerState -eq "PoweredOff")
    }
}

#Determine replication group target based off input VM from array
$VM = Get-VM -Name $VMs[0]
$TargetGroup = (Get-SpbmReplicationPair -Source ($VM | Get-SpbmReplicationGroup )).Target

#Build target Cluster variable
$TargetCluster = Get-Cluster -Name $Cluster -Server $DestVC

#Begin test failover, store VMX paths in variable
$VMPath = Start-SpbmReplicationTestFailover -ReplicationGroup $TargetGroup -ErrorAction 'SilentlyContinue'
Add-Content $LogFile ('[' + (Get-Date -Format G) + '] ' + 'Beginning fail-over of replication group ' + $SourceStoragePolicy)

#Store newly registered VMs into an array
$NewVMs = @()

#Import VMX into cluster as new VM
ForEach ($Path in $VMPath){
    $NewVMs += New-VM -VMFilePath $Path -ResourcePool $TargetCluster
    Add-Content $LogFile ('[' + (Get-Date -Format G) + '] ' + 'Importing VMX file path ' + $Path)
}

#Start VM and answer question
ForEach ($NewVM in $NewVMs)
{
    Try{
        $NewVM | Start-VM -ErrorAction Stop 
    }
    Catch [VMware.VimAutomation.ViCore.Types.V1.ErrorHandling.VMBlockedByQuestionException]{
        $NewVM | Get-VMQuestion | Set-VMQuestion -DefaultOption -Confirm:$False
    } 
}

#End test failover using Stop-SpbmReplicationTestFailover -ReplicationGroup $TargetGroup

