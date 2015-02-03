<#
    .Synopsis
    Creates the framework for a Group-deployed SCCM 2012 software package.

    .Description
    Creates AD Security Groups for installing and uninstalling a software package, then creates SCCM 2012 Collections which are populated by members of those groups, and then creates a SCCM 2012 Package which will install software to those Collections.
    The Programs within the SCCM 2012 Package must still be created, as well as the Advertisements.

    .Parameter SoftwareName
    The name of the software package.

    .Parameter Version
    The version number of the software package.

    .Parameter Manufacturer
    The manufacturer/vendor of the software package.

    .Parameter InstallTypes
    A list of the names of different types (configurations) of installations of the same software package. E.g. network (license server) activation vs. serial number activation, 64-bit vs. 32-bit, etc.

    .Parameter UninstallTypes
    A list of the names of different types (configurations) of uninstallations of the same software package. E.g. 64-bit vs. 32-bit.

    .Example
    Create-SCCMPackage.ps1 -SoftwareName Thunderbird -Version 17.0.7 -Manufacturer Mozilla

    This will create the following AD Groups:
    SCCM_Thunderbird 17.0.7
    SCCM_Thunderbird 17.0.7 Uninstall

    The following Collections:
    Install Thunderbird 17.0.7
    Uninstall Thunderbird 17.0.7

    And the following Package:
    Mozilla Thunderbird 17.0.7

    .Example
    Create-SCCMPackage.ps1 -SoftwareName SPSS -Version 21 -Manufacturer IBM -InstallTypes Network,Activation

    This will create the following AD Groups:
    SCCM_SPSS 21 Network
    SCCM_SPSS 21 Activation
    SCCM_SPSS 21 Uninstall

    The following Collections:
    Install SPSS 21 Network
    Install SPSS 21 Activation
    Uninstall SPSS 21

    And the following Package:
    IBM SPSS 21
#>
[CmdletBinding()]
Param(
    [Parameter(Mandatory=$true)][Alias('Name')][String]$SoftwareName,
    [Parameter(Mandatory=$true)][String]$Version,
    [Parameter(Mandatory=$true)][Alias('Vendor')][String]$Manufacturer,
    [Parameter(Mandatory=$false)][String[]]$InstallTypes = $null,
    [Parameter(Mandatory=$false)][String[]]$UninstallTypes = $null
)

# Load necessary Modules.
Import-Module ActiveDirectory
Import-Module "C:\Program Files (x86)\Microsoft Configuration Manager\AdminConsole\bin\ConfigurationManager.psd1"
# Defining global variables here because I don't want to have to pass them in on command-line every time.
# Alter these to set your own defaults for your environment.
$GroupTargetOU = "OU=SCCM Applications,OU=CECS Groups,DC=DS,DC=CECS,DC=PDX,DC=EDU"
$SCCMSiteServer = "ITZAMNA.DS.CECS.PDX.EDU"
$SCCMSiteCode = "KAT"
$RootSCCMFolderPath = "Software\"

# Define function to move Objects into containing Folders in SCCM.
# Credit for writing this function goes to Kaido, at http://cm12sdk.net/?p=1006.
Function Move-CMObject
{
    [CmdLetBinding()]
    Param(
    [Parameter(Mandatory=$True,HelpMessage="Please Enter Site Server Site code")]
              $SiteCode,
    [Parameter(Mandatory=$True,HelpMessage="Please Enter Site Server Name")]
              $SiteServer,
    [Parameter(Mandatory=$True,HelpMessage="Please Enter Object ID")]
              [ARRAY]$ObjectID,
    [Parameter(Mandatory=$True,HelpMessage="Please Enter current folder ID")]
              [uint32]$CurrentFolderID,
    [Parameter(Mandatory=$True,HelpMessage="Please Enter target folder ID")]
              [uint32]$TargetFolderID,
    [Parameter(Mandatory=$True,HelpMessage="Please Enter object type ID")]
              [uint32]$ObjectTypeID
    )
 
    Try{
        Invoke-WmiMethod -Namespace "Root\SMS\Site_$SiteCode" -Class SMS_objectContainerItem -Name MoveMembers -ArgumentList $CurrentFolderID,$ObjectID,$ObjectTypeID,$TargetFolderID -ComputerName $SiteServer -ErrorAction STOP
    }
    Catch{
        $_.Exception.Message
    }  
}
# Ex: Move-CMObject -SiteCode PRI -SiteServer Server100 -ObjectID "PRI00017" -CurrentFolderID 0 -TargetFolderID "16777236," -ObjectTypeID 5000


# Create Install/Uninstall group
Function New-InstallGroup {
    Param(
        [Parameter(Mandatory=$True)][String]$SoftwareName,
        [Parameter(Mandatory=$False)][String]$Version,
        [Parameter(Mandatory=$False)][String]$Type,
        [Parameter(Mandatory=$False)][Switch]$Uninstall
    )
    $GroupName = "SCCM_${SoftwareName}"
    if ($Version) { $GroupName += " ${Version}" }
    if ($Type) { $GroupName += " ${Type}" }
    if ($Uninstall) { $GroupName += " Uninstall" }
    Write-Host "Creating Group '$GroupName'."
    New-ADGroup $GroupName -DisplayName $GroupName -Path $GroupTargetOU -GroupScope Global -PassThru
}

# Create Install group(s)
$InstallGroups = @()
if ($InstallTypes) {
    foreach ($Type in $InstallTypes) {
        $InstallGroups += New-InstallGroup -SoftwareName $SoftwareName -Version $Version -Type $Type
    }
} else {
    $InstallGroups += New-InstallGroup -SoftwareName $SoftwareName -Version $Version
}

# Create Uninstall group(s)
$UninstallGroups = @()
if ($UninstallTypes) {
    foreach ($Type in $UninstallTypes) {
        $UninstallGroups += New-InstallGroup -SoftwareName $SoftwareName -Version $Version -Type $Type -Uninstall
    }
} else {
    $UninstallGroups += New-InstallGroup -SoftwareName $SoftwareName -Version $Version -Uninstall
}

# Switch contexts to SCCM 2012.
Push-Location "${SCCMSiteCode}:\"

# Create SCCM 2012 Device Collections.
$InstallCollections = @()
$sched = New-CMSchedule -End (Get-Date) -RecurCount 5 -RecurInterval Minutes -Start (Get-Date)
if ($InstallTypes) {
    foreach ($Type in $InstallTypes) {
        $CollectionName = "Install ${SoftwareName} ${Version} ${Type}"
        Write-Host "Creating Collection '$CollectionName'."
        $InstallCollections += New-CMDeviceCollection -Name $CollectionName -LimitingCollectionName "All Systems" -RefreshSchedule $sched
    }
} else {
    $CollectionName = "Install ${SoftwareName} ${Version}"
    Write-Host "Creating Collection '$CollectionName'."
    $InstallCollections += New-CMDeviceCollection -Name $CollectionName -LimitingCollectionName "All Systems" -RefreshSchedule $sched
}
$UninstallCollections = @()
if ($UninstallTypes) {
    foreach ($Type in $UninstallTypes) {
        $CollectionName = "Uninstall ${SoftwareName} ${Version} ${Type}"
        Write-Host "Creating Collection '$CollectionName'."
        $UninstallCollections += New-CMDeviceCollection -Name $CollectionName -LimitingCollectionName "All Systems" -RefreshSchedule $sched
    }
} else {
    $CollectionName = "Uninstall ${SoftwareName} ${Version}"
    Write-Host "Creating Collection '$CollectionName'."
    $UninstallCollections += New-CMDeviceCollection -Name $CollectionName -LimitingCollectionName "All Systems" -RefreshSchedule $sched
}

# Create Folder to move Collections into.
# Move Collections into Folder.
#Move-CMObject -SiteCode $SCCMSiteCode -SiteServer $SCCMSiteServer -ObjectID "PRI00017" -CurrentFolderID 0 -TargetFolderID "16777236," -ObjectTypeID 5000
# gwmi -query "select * from SMS_ObjectContainerNode where name like 'Software'" -Namespace "root\SMS\Site_KAT" -comp itzamna | format-list *
# Create Package
#$sched = ([wmiclass]"\\${SCCMSiteServer}\Root\SMS\Site_${SCCMSiteCode}:SMS_ST_RecurInterval").CreateInstance()

Pop-Location