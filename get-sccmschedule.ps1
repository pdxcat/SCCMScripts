<#
    .Synopsis
    This retrieves what advertizements are scheduled to be installed.  
    
    .Description
    This script will output the advertizements schedule for a machine. It uses a wmi to find the scheduled advert.
    and the package information. Then it combies the outputs. 

    .Example
    get-sccmschedule.ps1 <computername>
    This will output the scheduled tasks.  
#>
param(
    [string]$CompName
)

## Graps the package information 
$Schedulelist = Get-WmiObject -Namespace "root\ccm\scheduler" -Class ccm_scheduler_history -ComputerName $CompName | where -Property "ScheduleId" -Match "cat" | select ScheduleID,lasttriggertime
$PkgInfo = Get-WmiObject -Namespace "Root\sms\Site_KAT" -Class SMS_Program -ComputerName Itzamna | select PackageID,PackageName,PackageVersion -Unique

function format-pkg{
    
    foreach($item in $Schedulelist){
        $newobject = New-Object -TypeName psobject
        $AdvertID=$item.scheduleid.split('-')[0]
        $PKID=$item.scheduleid.split('-')[1]
        $time = format-date($item.lasttriggertime)
        $newobject | Add-Member -Type "NoteProperty" -name PackageID -Value $PKID
        $newobject | Add-Member -Type "NoteProperty" -name AdvertizeID -value $AdvertID
        $newobject | Add-Member -Type "NoteProperty" -Name LastRunTime -Value $time
        $newobject  
    }
}

function format-date{
    param($date)      
          $year = $date.substring(0,4) 
         $month =  $date.substring(4,2)
           $day = $date.substring(6,2)
          $hour = $date.substring(8,2)
        $minute = $date.substring(10,2)
        $second = $date.substring(12,2)
        "$month/$day/$year $hour`:$minute`:$second"
}

$finallist = format-pkg
$finallist

