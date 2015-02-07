<#
    .Synopsis
    Creates the framework for a Group-deployed SCCM 2012 software package.

    .Description
    Creates AD Security Groups for installing and uninstalling a software
    package, then creates SCCM 2012 Collections which are populated by members
    of those groups. Finally, creates a containing Folder in the SCCM Console
    to organize the collection by its manufacturer's name. The SCCM 2012
    Package/Application must still be created.

    .Parameter SoftwareName
    The name of the software package.

    .Parameter Version
    The version number of the software package.

    .Parameter Manufacturer
    The manufacturer/vendor of the software package.

    .Parameter InstallTypes
    A list of the names of different types (configurations) of installations
    of the same software package. E.g. network activation vs. serial number
    activation, 64-bit vs. 32-bit, etc.

    .Example
    Create-SCCMPackage.ps1 -SoftwareName Thunderbird -Version 17.0.7 -Manufacturer Mozilla

    This will create the following AD Groups:
    SCCM_Thunderbird 17.0.7
    SCCM_Thunderbird 17.0.7 Uninstall

    And the following Collections:
    Install Thunderbird 17.0.7
    Uninstall Thunderbird 17.0.7

    And place the ollections in the following Folder under Device Collections:

    Root\Software\Mozilla
    
    .Example
    Create-SCCMPackage.ps1 -SoftwareName SPSS -Version 21 -Manufacturer IBM -InstallTypes Network,Activation

    This will create the following AD Groups:
    SCCM_SPSS 21 Network
    SCCM_SPSS 21 Activation
    SCCM_SPSS 21 Network Uninstall
    SCCM_SPSS 21 Activation Uninstall

    And the following Collections:
    Install SPSS 21 Network
    Install SPSS 21 Activation
    Uninstall SPSS 21 Network
    Uninstall SPSS 21 Activation

    And place the Collections in the following Folder under Device Collections:

    Root\Software\IBM
#>
[CmdletBinding()]
Param(
    [Parameter(Mandatory=$true)][Alias('Name')][String]$SoftwareName,
    [Parameter(Mandatory=$false)][String]$Version,
    [Parameter(Mandatory=$false)][Alias('Vendor')][String]$Manufacturer,
    [Parameter(Mandatory=$false)][Alias('Types')][String[]]$InstallTypes = $null
)

# Load necessary Modules.
Import-Module ActiveDirectory
Import-Module "C:\Program Files (x86)\Microsoft Configuration Manager\AdminConsole\bin\ConfigurationManager.psd1"
# Defining global variables here because I don't want to have to pass them in on command-line every time.
# Alter these to set your own defaults for your environment.
$GroupTargetOU = "OU=SCCM Applications,OU=CECS Groups,DC=DS,DC=CECS,DC=PDX,DC=EDU"
$SCCMSiteServer = "ITZAMNA.DS.CECS.PDX.EDU"
$SCCMSiteCode = "KAT"
$SCCMFolderTargetPath = "Software\"
$InstallQuery = 'select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System where SMS_R_System.SystemGroupName in ("CECS\\SCCM_GroupA")'
$UninstallQuery = 'select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System where (SMS_R_System.SystemGroupName in ("CECS\\SCCM_GroupA")) and (SMS_R_System.ResourceId not in (select SMS_R_System.ResourceId from  SMS_R_System where SMS_R_System.SystemGroupName in ("CECS\\SCCM_GroupB")))'
$TypeID = 5000

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

# Create Install/Uninstall Collection
Function New-InstallCollection {
    Param(
        [Parameter(Mandatory=$True)][String]$SoftwareName,
        [Parameter(Mandatory=$False)][String]$Version,
        [Parameter(Mandatory=$False)][String]$Type,
        [Parameter(Mandatory=$False)][String]$Manufacturer,
        [Parameter(Mandatory=$True)][String]$InstallGroup,
        [Parameter(Mandatory=$False)][String]$UninstallGroup
    )
    if ($UninstallGroup) {
        $CollectionName = "Uninstall ${SoftwareName}"
        $Query = $UninstallQuery.Replace('SCCM_GroupA',$UninstallGroup).Replace('SCCM_GroupB',$InstallGroup)
        $QueryRuleName = "Is in $UninstallGroup and not in $InstallGroup"
    } else {
        $CollectionName = "Install ${SoftwareName}"
        $Query = $InstallQuery.Replace('SCCM_GroupA',$InstallGroup)
        $QueryRuleName = "Is in $InstallGroup"
    }
    if ($Version) { $CollectionName += " ${Version}" }
    if ($Type) { $CollectionName += " ${Type}" }
    Push-Location "${SCCMSiteCode}:\"
    $Schedule = New-CMSchedule -End (Get-Date) -RecurCount 5 -RecurInterval Minutes -Start (Get-Date)
    Write-Host "Creating Collection '$CollectionName'."
    $Collection = New-CMDeviceCollection -Name $CollectionName -LimitingCollectionName "All Systems" -RefreshSchedule $Schedule
    Add-CMDeviceCollectionQueryMembershipRule -CollectionName $CollectionName -RuleName $QueryRuleName -QueryExpression $Query
    Pop-Location
    return $Collection
}

# Find and return a Device Collection folder at the given Path. The AutoCreate
# parameter causes this function to create the folder and any parents as
# necessary, if they don't already exist.
Function Get-CollectionFolder {
    Param(
        [String]$Path,
        [Switch]$AutoCreate
    )
    $ParentId = 0
    $Folders = Get-CimInstance -ClassName SMS_ObjectContainerNode -ComputerName $SCCMSiteServer -Namespace Root\SMS\site_$SCCMSiteCode | Where-Object { $_.ObjectType -eq $TypeId }
    $PathSegments = $Path.Split('\')
    $TargetFolder = $null
    foreach ($PathSegment in $PathSegments) {
        $Found = $False
        if ($PathSegment -eq '') { continue }
        foreach ($Folder in $Folders) {
            if (($PathSegment -like $Folder.Name) -and ($ParentId -eq $Folder.ParentContainerNodeID)) {
                $ParentId = $Folder.ContainerNodeID
                $Found = $True
                $TargetFolder = $Folder
                break
            }
        }
        if (-not $Found) {
            if ($AutoCreate) {
                $TargetFolder = New-CimInstance -ClassName SMS_ObjectContainerNode -Property @{Name=$PathSegment;ObjectType=$TypeId;ParentContainerNodeid=$ParentId;SourceSite=$SCCMSiteCode} -Namespace Root/SMS/site_$SCCMSiteCode -ComputerName $SCCMSiteServer
                $ParentId = $TargetFolder.ContainerNodeID
            } else {
                return $null
            }
        }
    }
    return $TargetFolder
}

# Create Groups and Collections
$CollFolder = Get-CollectionFolder -Path "${RootSCCMFolderPath}\${Manufacturer}" -AutoCreate
if ($InstallTypes) {
    foreach ($Type in $InstallTypes) {
        $InstallGroup = New-InstallGroup -SoftwareName $SoftwareName -Version $Version -Type $Type
        $UninstallGroup = New-InstallGroup -SoftwareName $SoftwareName -Version $Version -Type $Type -Uninstall
        $InstallCollection = New-InstallCollection -SoftwareName $SoftwareName -Version $Version -Type $Type -Manufacturer $Manufacturer -InstallGroup $InstallGroup.Name
        $UninstallCollection = New-InstallCollection -SoftwareName $SoftwareName -Version $Version -Type $Type -Manufacturer $Manufacturer -InstallGroup $InstallGroup.Name -UninstallGroup $UninstallGroup.Name
        $Result = Move-CMObject -SiteCode $SCCMSiteCode -SiteServer $SCCMSiteServer -ObjectID $InstallCollection.CollectionID -CurrentFolderID 0 -TargetFolderID $CollFolder.ContainerNodeID -ObjectTypeID $TypeID
        $Result = Move-CMObject -SiteCode $SCCMSiteCode -SiteServer $SCCMSiteServer -ObjectID $UninstallCollection.CollectionID -CurrentFolderID 0 -TargetFolderID $CollFolder.ContainerNodeID -ObjectTypeID $TypeID
    }
} else {
    $InstallGroup = New-InstallGroup -SoftwareName $SoftwareName -Version $Version
    $UninstallGroup = New-InstallGroup -SoftwareName $SoftwareName -Version $Version -Uninstall
    $InstallCollection = New-InstallCollection -SoftwareName $SoftwareName -Version $Version -Manufacturer $Manufacturer -InstallGroup $InstallGroup.Name
    $UninstallCollection = New-InstallCollection -SoftwareName $SoftwareName -Version $Version -Manufacturer $Manufacturer -InstallGroup $InstallGroup.Name -UninstallGroup $UninstallGroup.Name
    $Result = Move-CMObject -SiteCode $SCCMSiteCode -SiteServer $SCCMSiteServer -ObjectID $InstallCollection.CollectionID -CurrentFolderID 0 -TargetFolderID $CollFolder.ContainerNodeID -ObjectTypeID $TypeID
    $Result = Move-CMObject -SiteCode $SCCMSiteCode -SiteServer $SCCMSiteServer -ObjectID $UninstallCollection.CollectionID -CurrentFolderID 0 -TargetFolderID $CollFolder.ContainerNodeID -ObjectTypeID $TypeID
}
