$Adapters = @("1.1.1.1","2.2.2.2") # Local server adapters
$TargetPortalAddresses = @("3.3.3.3","4.4.4.4","5.5.5.5","6.6.6.6") # IPs on the FlashArray

ForEach ($TargetPortalAddress in $TargetPortalAddresses){
New-IscsiTargetPortal -TargetPortalAddress $TargetPortalAddress 
}

# Create iSCSI sessions for adapters
ForEach ($TargetPortalAddress in $TargetPortalAddresses){
Get-IscsiTarget | Connect-IscsiTarget -InitiatorPortalAddress $Adapters[0] -IsMultipathEnabled $true -IsPersistent $true -TargetPortalAddress $TargetPortalAddress 
Get-IscsiTarget | Connect-IscsiTarget -InitiatorPortalAddress $Adapters[1] -IsMultipathEnabled $true -IsPersistent $true -TargetPortalAddress $TargetPortalAddress 
}