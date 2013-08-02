<#
    .Synopsis
    This retrieves SCCM advertisements that are scheduled for install.  
    
    .Description
    This script will output the advertisements schedule for a machine. It uses WMI to find the scheduled advert
    and the package information. It then it combines the output. 

    .Example
    get-sccmschedule.ps1 <computername>
    This will output the scheduled tasks.  
#>
param(
    [string]$CompName
)

## Graps the package information 
$ScheduleList = Get-WmiObject -Namespace "root\ccm\scheduler" -Class ccm_scheduler_history -ComputerName $CompName | where -Property "ScheduleID" -Match "cat" | select ScheduleID,LastTriggerTime
$PkgInfo = Get-WmiObject -Namespace "Root\sms\Site_KAT" -Class SMS_Program -ComputerName Itzamna | select PackageID,PackageName,PackageVersion -Unique

function Format-Pkg{
    
    foreach($Item in $ScheduleList){
        $NewObject = New-Object -TypeName PSObject
        $AdvertID=$Item.ScheduleID.Split('-')[0]
        $PKID=$Item.ScheduleID.Split('-')[1]
        $Time = Format-Date($Item.LastTriggerTime)
        $NewObject | Add-Member -Type "NoteProperty" -Name PackageID -Value $PKID
        $NewObject | Add-Member -Type "NoteProperty" -Name AdvertiseID -Value $AdvertID
        $NewObject | Add-Member -Type "NoteProperty" -Name LastRunTime -Value $Time
        $NewObject  
    }
}

function Format-Date{
    param($Date)      
          $Year = $Date.SubString(0,4) 
         $Month = $Date.SubString(4,2)
           $Day = $Date.SubString(6,2)
          $Hour = $Date.SubString(8,2)
        $Minute = $Date.SubString(10,2)
        $Second = $Date.SubString(12,2)
        "$Month/$Day/$Year $Hour`:$Minute`:$Second"
}

$FinalList = Format-Pkg
$FinalList