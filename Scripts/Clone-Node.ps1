﻿[CmdletBinding()]
Param(
[Parameter(Mandatory=$false)][string]$Builddir = $PSScriptRoot,
[Parameter(Mandatory=$true)][string]$MasterVMX,
[Parameter(Mandatory=$false)][string]$Domainname,
[Parameter(Mandatory=$true)][string]$Nodename,
[Parameter(Mandatory=$false)][string]$CloneVMX = "$Builddir\$Nodename\$Nodename.vmx",
[Parameter(Mandatory=$false)][string]$vmnet ="vmnet2",
[Parameter(Mandatory=$false)][switch]$Isilon,
[Parameter(Mandatory=$false)][string]$scenarioname = "Default",
[Parameter(Mandatory=$false)][int]$Scenario = 1,
[Parameter(Mandatory=$false)][int]$ActivationPreference = 1,
[Parameter(Mandatory=$false)][switch]$AddDisks,
[Parameter(Mandatory=$false)][ValidateRange(1, 6)][int]$Disks = 1,
#[string]$Build,
[Parameter(Mandatory=$false)][ValidateSet('XS','S','M','L','XL','TXL','XXL','XXXL')]$Size = "M",
[switch]$Exchange,
[switch]$HyperV,
[switch]$NW,
[switch]$Bridge,
[switch]$Gateway,
[switch]$sql,
$Sourcedir
# $Machinetype
)
# $SharedFolder = "Sources"
$Origin = $MyInvocation.InvocationName
$Sources = "$MountDrive\sources"
$Adminuser = "Administrator"
$Adminpassword = "Password123!"
$BuildDate = Get-Date -Format "MM.dd.yyyy hh:mm:ss"
###################################################
### Node Cloning and Customizing script
### Karsten Bott
### 08.10.2013 Added vmrun errorcheck on initial base snap
###################################################
$VMrunErrorCondition = @("Error: The virtual machine is not powered on","Waiting for Command execution Available","Error","Unable to connect to host.","Error: The operation is not supported for the specified parameters","Unable to connect to host. Error: The operation is not supported for the specified parameters")
function write-log {
    Param ([string]$line)
    $Logtime = Get-Date -Format "MM-dd-yyyy_hh-mm-ss"
    Add-Content $Logfile -Value "$Logtime  $line"
}

function test-user {param ($whois)
$Origin = $MyInvocation.MyCommand
do {([string]$cmdresult = &$vmrun -gu $Adminuser -gp $Adminpassword listProcessesInGuest $Clone.config )2>&1 | Out-Null
Write-Debug $cmdresult
Start-Sleep 5
}
until (($cmdresult -match $whois) -and ($VMrunErrorCondition -notcontains $cmdresult))
write-log "$origin $UserLoggedOn"
}


if (!(Get-ChildItem $MasterVMX -ErrorAction SilentlyContinue)) { write-host "Panic, $MasterVMX not installed"!; Break}
########################################
###########
# Setting Base Snapshot upon First Run


if (!($Master = get-vmx  -Path $MasterVMX))
    { Write-Error "where is our master ?! "
    break 
    }

write-verbose "Checking template"
if (!($Master.Template))
    {
    write-verbose "Templating"
    $Master | Set-VMXTemplate
    }
Write-verbose "Checking Snapshot"
    if(!($Snapshot = $Master | Get-VMXSnapshot | where snapshot -eq "Base"))
    {
    Write-Verbose "Creating Base Snapshot"
    $Snapshot = $Master | New-VMXSnapshot -SnapshotName "Base"
    }


<# old snapshot pre 3.61

do {($Snapshots = &$vmrun listSnapshots $MasterVMX ) 2>&1 | Out-Null 
write-log "$origin listSnapshots $MasterVMX $Snapshots"
}
until ($VMrunErrorCondition -notcontains $Snapshots)
write-log "$origin listSnapshots $MasterVMX $Snapshots"

if ($Snapshots -eq "Total snapshots: 0") 
{
do {($cmdresult = &$vmrun snapshot $MasterVMX Base ) 2>&1 | Out-Null 
write-log "$origin snapshot $MasterVMXX $cmdresult"
}
until ($VMrunErrorCondition -notcontains $cmdresult)
}
write-log "$origin snapshot $MasterVMX $cmdresult"


#>


<# pre 1.6
if (Get-ChildItem $CloneVMX -ErrorAction SilentlyContinue ) 
{write-host "VM $Nodename Already exists, nothing to do here"
return $false
}
#>

if (get-vmx $Nodename)
{
Write-Warning "$Nodename already exists"
return $false
}
else
{
$Displayname = 'displayname = "'+$Nodename+'@'+$Domainname+'"'
Write-Host -ForegroundColor Gray "Creating Linked Clone $Nodename from $MasterVMX, VMsize is $Size"
Write-verbose "Creating linked $Nodename of $MasterVMX"
# while (!(Get-ChildItem $MasterVMX)) {
# write-Host "Try Snapshot"

$Clone = $Snapshot | New-VMXLinkedClone -CloneName $Nodename -clonepath $Builddir
<# pre 3.61
do {($cmdresult = &$vmrun clone $MasterVMX $CloneVMX linked Base )
write-log "$origin clone $MasterVMX $CloneVMX linked Base $cmdresult"
}
until ($VMrunErrorCondition -notcontains $cmdresult)
write-log "$origin clone $MasterVMX $CloneVMX linked Base $cmdresult"
#>
write-verbose "starting customization of $($Clone.config)"
$Content = $Clone | Get-VMXConfig
$Content = $Content | where {$_ -NotMatch "memsize"}
$Content = $Content | where {$_ -NotMatch "numvcpus"}
$Content = $Content | where {$_ -NotMatch "sharedFolder"}
$Content += 'sharedFolder0.present = "TRUE"'
$Content += 'sharedFolder0.enabled = "TRUE"'
$Content += 'sharedFolder0.readAccess = "TRUE"'
$Content += 'sharedFolder0.writeAccess = "TRUE"'
$Content += 'sharedFolder0.hostPath = "'+"$Sourcedir"+'"'
$Content += 'sharedFolder0.guestName = "Sources"'
$Content += 'sharedFolder0.expiration = "never"'
$Content += 'sharedFolder.maxNum = "1"'

switch ($Size)
{ 
"XS"{
$content += 'memsize = "512"'
$Content += 'numvcpus = "1"'
}
"S"{
$content += 'memsize = "768"'
$Content += 'numvcpus = "1"'
}
"M"{
$content += 'memsize = "1024"'
$Content += 'numvcpus = "1"'
}
"L"{
$content += 'memsize = "2048"'
$Content += 'numvcpus = "2"'
}
"XL"{
$content += 'memsize = "4096"'
$Content += 'numvcpus = "2"'
}
"TXL"{
$content += 'memsize = "6144"'
$Content += 'numvcpus = "2"'
}
"XXL"{
$content += 'memsize = "8192"'
$Content += 'numvcpus = "4"'
}
"XXXL"{
$content += 'memsize = "16384"'
$Content += 'numvcpus = "4"'
}
}

$Content = $content | where { $_ -NotMatch "DisplayName" }
$content += $Displayname
Set-Content -Path $Clone.config -Value $content -Force
$vmnetname =  'ethernet0.vnet = "'+$vmnet+'"'
# (get-content $CloneVMX) | foreach-object {$_ -replace 'displayName = "Clone of Master"', $Displayname } | set-content $CloneVMX
(get-content $Clone.config) | foreach-object {$_ -replace 'gui.exitAtPowerOff = "FALSE"','gui.exitAtPowerOff = "TRUE"'} | set-content $Clone.Config
(get-content $Clone.config) | foreach-object {$_ -replace 'mainMem.useNamedFile = "true"','' }| set-content $Clone.config 
$memhook =  'mainMem.useNamedFile = "FALSE"'
add-content -Path $Clone.config $memhook

if ($HyperV){
($Clone | Get-VMXConfig) | foreach-object {$_ -replace 'guestOS = "windows8srv-64"', 'guestOS = "winhyperv"' } | set-content $Clone.config
}

<#
if ($Exchange){

copy-item $Builddir\Disks\DB1.vmdk $Builddir\$Nodename\DB1.vmdk
copy-item $Builddir\Disks\LOG1.vmdk $Builddir\$Nodename\LOG1.vmdk
copy-item $Builddir\Disks\DB1.vmdk $Builddir\$Nodename\DB2.vmdk
copy-item $Builddir\Disks\LOG1.vmdk $Builddir\$Nodename\LOG2.vmdk
copy-item $Builddir\Disks\DB1.vmdk $Builddir\$Nodename\RDB.vmdk
copy-item $Builddir\Disks\LOG1.vmdk $Builddir\$Nodename\RDBLOG.vmdk
$AddDrives = @('scsi0:1.present = "TRUE"','scsi0:1.fileName = "DB1.vmdk"','scsi0:2.present = "TRUE"','scsi0:2.fileName = "LOG1.vmdk"','scsi0:3.present = "TRUE"','scsi0:3.fileName = "DB2.vmdk"','scsi0:4.present = "TRUE"','scsi0:4.fileName = "LOG2.vmdk"','scsi0:5.present = "TRUE"','scsi0:5.fileName = "RDB.vmdk"','scsi0:6.present = "TRUE"','scsi0:6.fileName = "RDBLOG.vmdk"')
$AddDrives | Add-Content -Path $Clone.config
}


if ($AddDisks.IsPresent)
    {
    $Content = $Clone | Get-VMXConfig

    
    foreach ( $Disk in 1..$Disks)
        {
        $Diskpath = "$Builddir\$Nodename\0_"+$Disk+"_100GB.vmdk"
        Write-Verbose "Creating Disk"
        & $VMWAREpath\vmware-vdiskmanager.exe -c -s 100GB -a lsilogic -t 0 $Diskpath 2>&1 | Out-Null
        $AddDrives  = @('scsi0:'+$Disk+'.present = "TRUE"')
        $AddDrives += @('scsi0:'+$Disk+'.deviceType = "disk"')
        $AddDrives += @('scsi0:'+$Disk+'.fileName = "0_'+$Disk+'_100GB.vmdk"')
        $AddDrives += @('scsi0:'+$Disk+'.mode = "persistent"')
        $AddDrives += @('scsi0:'+$Disk+'.writeThrough = "false"')
        $Content += $AddDrives
        }
          $Content | set-Content -Path $Clone.config
    }

#>

######### next commands will be moved in vmrunfunction soon 
# KB , 06.10.2013 ##
$Addcontent = @()
$Addcontent += 'annotation = "This is node '+$Nodename+' for domain '+$Domainname+'|0D|0A built on '+(Get-Date -Format "MM-dd-yyyy_hh-mm")+'|0D|0A using labbuildr by @Hyperv_Guy|0D|0A Adminpasswords: Password123! |0D|0A Userpasswords: Welcome1"'
$Addcontent += 'guestinfo.hypervisor = "'+$env:COMPUTERNAME+'"'
$Addcontent += 'guestinfo.buildDate = "'+$BuildDate+'"'
$Addcontent += 'guestinfo.powerontime = "'+$BuildDate+'"'
Add-Content -Path $Clone.config -Value $Addcontent

if ($exchange.IsPresent)
    {    
    $Diskname =  "DATA_LUN1.vmdk"
    $Newdisk = New-VMXScsiDisk -NewDiskSize 500GB -NewDiskname $Diskname -Verbose  -VMXName $Clone.VMXname -Path $Clone.Path
    Write-Verbose "Adding Disk $Diskname to $($Clone.VMXname)"
    $AddDisk = $Clone | Add-VMXScsiDisk -Diskname $Newdisk.Diskname -LUN 1 -Controller 0
    $Diskname =  "LOG_LUN1.vmdk"
    $Newdisk = New-VMXScsiDisk -NewDiskSize 100GB -NewDiskname $Diskname -Verbose -VMXName $Clone.VMXname -Path $Clone.Path 
    Write-Verbose "Adding Disk $Diskname to $($Clone.VMXname)"
    $AddDisk = $Clone | Add-VMXScsiDisk -Diskname $Newdisk.Diskname -LUN 2 -Controller 0
    $Diskname =  "DATA_LUN2.vmdk"
    $Newdisk = New-VMXScsiDisk -NewDiskSize 500GB -NewDiskname $Diskname -Verbose  -VMXName $Clone.VMXname -Path $Clone.Path
    Write-Verbose "Adding Disk $Diskname to $($Clone.VMXname)"
    $AddDisk = $Clone | Add-VMXScsiDisk -Diskname $Newdisk.Diskname -LUN 3 -Controller 0
    $Diskname =  "LOG_LUN2.vmdk"
    $Newdisk = New-VMXScsiDisk -NewDiskSize 100GB -NewDiskname $Diskname -Verbose -VMXName $Clone.VMXname -Path $Clone.Path 
    Write-Verbose "Adding Disk $Diskname to $($Clone.VMXname)"
    $AddDisk = $Clone | Add-VMXScsiDisk -Diskname $Newdisk.Diskname -LUN 4 -Controller 0
    $Diskname =  "RestoreDB_LUN.vmdk"
    $Newdisk = New-VMXScsiDisk -NewDiskSize 500GB -NewDiskname $Diskname -Verbose -VMXName $Clone.VMXname -Path $Clone.Path 
    Write-Verbose "Adding Disk $Diskname to $($Clone.VMXname)"
    $AddDisk = $Clone | Add-VMXScsiDisk -Diskname $Newdisk.Diskname -LUN 5 -Controller 0
    $Diskname =  "RestoreLOG_LUN.vmdk"
    $Newdisk = New-VMXScsiDisk -NewDiskSize 100GB -NewDiskname $Diskname -Verbose -VMXName $Clone.VMXname -Path $Clone.Path 
    Write-Verbose "Adding Disk $Diskname to $($Clone.VMXname)"
    $AddDisk = $Clone | Add-VMXScsiDisk -Diskname $Newdisk.Diskname -LUN 6 -Controller 0

    }

if ($sql.IsPresent)
    {
    $Diskname =  "DATA_LUN.vmdk"
    $Newdisk = New-VMXScsiDisk -NewDiskSize 500GB -NewDiskname $Diskname -Verbose  -VMXName $Clone.VMXname -Path $Clone.Path
    Write-Verbose "Adding Disk $Diskname to $($Clone.VMXname)"
    $AddDisk = $Clone | Add-VMXScsiDisk -Diskname $Newdisk.Diskname -LUN 1 -Controller 0
    $Diskname =  "LOG_LUN.vmdk"
    $Newdisk = New-VMXScsiDisk -NewDiskSize 100GB -NewDiskname $Diskname -Verbose -VMXName $Clone.VMXname -Path $Clone.Path 
    Write-Verbose "Adding Disk $Diskname to $($Clone.VMXname)"
    $AddDisk = $Clone | Add-VMXScsiDisk -Diskname $Newdisk.Diskname -LUN 2 -Controller 0
    $Diskname =  "TEMPDB_LUN.vmdk"
    $Newdisk = New-VMXScsiDisk -NewDiskSize 100GB -NewDiskname $Diskname -Verbose -VMXName $Clone.VMXname -Path $Clone.Path 
    Write-Verbose "Adding Disk $Diskname to $($Clone.VMXname)"
    $AddDisk = $Clone | Add-VMXScsiDisk -Diskname $Newdisk.Diskname -LUN 3 -Controller 0
    $Diskname =  "TEMPLOG_LUN.vmdk"
    $Newdisk = New-VMXScsiDisk -NewDiskSize 50GB -NewDiskname $Diskname -Verbose -VMXName $Clone.VMXname -Path $Clone.Path 
    Write-Verbose "Adding Disk $Diskname to $($Clone.VMXname)"
    $AddDisk = $Clone | Add-VMXScsiDisk -Diskname $Newdisk.Diskname -LUN 4 -Controller 0
    }


if ($AddDisks.IsPresent)
    {
    $Disksize = "100GB"
    $SCSI = "0"
    foreach ($LUN in (1..$Disks))
        {
        $Diskname =  "SCSI$SCSI"+"_LUN$LUN"+"_$Disksize.vmdk"
        Write-Verbose "Building new Disk $Diskname"
        $Newdisk = New-VMXScsiDisk -NewDiskSize $Disksize -NewDiskname $Diskname -Verbose -VMXName $Clone.VMXname -Path $Clone.Path 
        Write-Verbose "Adding Disk $Diskname to $($Clone.VMXname)"
        $AddDisk = $Clone | Add-VMXScsiDisk -Diskname $Newdisk.Diskname -LUN $LUN -Controller $SCSI
        }
    }

Set-VMXActivationPreference -config $Clone.config -activationpreference $ActivationPreference
Set-VMXscenario -config $Clone.config -Scenario $Scenario -Scenarioname $scenarioname
Set-VMXscenario -config $Clone.config -Scenario 9 -Scenarioname labbuildr



if ($bridge.IsPresent)
    {
    write-verbose "configuring network for bridge"
    Set-VMXNetworkAdapter -config $Clone.config -Adapter 1 -ConnectionType bridged -AdapterType vmxnet3
    Set-VMXNetworkAdapter -config $Clone.config -Adapter 0 -ConnectionType custom -AdapterType vmxnet3
    Set-VMXVnet -config $Clone.config -Adapter 0 -vnet $vmnet
    }
elseif($NW -and $gateway.IsPresent) 
    {
    write-verbose "configuring network for gateway"
    Set-VMXNetworkAdapter -config $Clone.config -Adapter 1 -ConnectionType nat -AdapterType vmxnet3
    Set-VMXNetworkAdapter -config $Clone.config -Adapter 0 -ConnectionType custom -AdapterType vmxnet3
    Set-VMXVnet -config $Clone.config -Adapter 0 -vnet $vmnet
    }
elseif(!$Isilon.IsPresent)
        {
        Set-VMXNetworkAdapter -config $Clone.config -Adapter 0 -ConnectionType custom -AdapterType vmxnet3
        Set-VMXVnet -config $Clone.config -Adapter 0 -vnet $vmnet
        }



$Clone | Start-VMX


if (!$Isilon.IsPresent)
    {
write-verbose "Enabling Shared Folders"


$Clone | Set-VMXSharedFolderState -enabled

<#
    do 
    { 
        $cmdresult = &$vmrun addSharedFolder $CloneVMX $SharedFolder $Mountdrive\$SharedFolder
        write-log "$Origin addSharedFolder $CloneVMX $SharedFolder $Mountdrive\$SharedFolder $cmdresult"
    }
    until ($VMrunErrorCondition -notcontains $cmdresult)
    write-log "$Origin addSharedFolder $CloneVMX $SharedFolder $Mountdrive\$SharedFolder $cmdresult"
#>
#############
$Clone | Write-Host -ForegroundColor Gray

Write-verbose "Waiting for Pass 1 (sysprep Finished)"
test-user -whois Administrator
} #end not isilon

return,[bool]$True
}
