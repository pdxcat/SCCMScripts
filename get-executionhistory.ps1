﻿<#
    .Synopsis
    This retrieves the execution history of sccm installed software. 
    
    .Description
    This script gets the execution history of software installed by sccm. This is done by read the information 
    from registry of the computer. It will output the package name, package id, program name, state, time runned and 
    exit code. The input is computer name. 

    .Example
    get-executionhistory.ps1 smiley
    This will output the the execution history.  
#>
param([string]$computername)

## This is the registry path where the execution hisotry is stored in the regsity.
$reg = "HKLM:\SOFTWARE\Microsoft\SMS\Mobile Client\Software Distribution\Execution History\System"

## This where the package name and package id information is store.
$PkgInfo = Get-WmiObject -Namespace "Root\sms\Site_KAT" -Class SMS_Program -ComputerName Itzamna | select PackageID,PackageName,PackageVersion -Unique

## This will retrieve the execution history from the registry. The function will create a object and add the 
## additional information. Returns the list. 
function get-history{

 ## This uses invoke command to run the script block on a remote computer. 
 $history = invoke-command -computername $computername {
            ## This used to pass a local parameter to the remote computer. 
            param($reg)
            
            $PKIDlist = Get-ChildItem $reg | select -ExpandProperty name | foreach{$_.split('\')[8]} 
            foreach($PKID in $PKIDlist){
                $GUID = Get-ChildItem $reg\$PKID | select -ExpandProperty name | foreach{$_.split('\')[9]}
                foreach($GID in $GUID){
                    $APPInfo = Get-ItemProperty $reg\$PKID\$GID 
                    $APPInfo | Add-Member -type NoteProperty -Name PKID -Value $PKID
                    $appInfo
                }
            }
            } -ArgumentList $reg
 $list = $history | select PKID,_ProgramID,_State,_RunStartTime,SuccessOrFailureCode,SuccessOrFailureReason

 return $list
}

## This will add packagename and the version of the packaged. This information is gained from the sccm
## server. 
function add-packagename{
    param([object]$list)
    $templist = $list
    foreach($PK in $templist){
        foreach($PKlist in $Pkginfo){
            if($pk.pkid -eq $pklist.packageid){
                $pk | Add-Member -type NoteProperty -Name name -Value $pklist.packagename
                $pk | Add-Member -type NoteProperty -Name version -Value $pklist.packageversion
                $pk
            }
        }
    }

}

## This will format the output into a more readable format. 
function format-output{
     param(
        [object]$list
     )
      ## Formats the name of the Package so it outputs Package Name as a title
      $NameFormat =    @{Expression={$_.name};Label="Package Name";width=15;}
      ## Formats the PackageID 
      $PKIDFormat =    @{Expression={$_.PKID};Label="PackageID";width=12}
      ## Formats the output of Program
      $ProgramFormat = @{Expression={$_._ProgramID};Label="Program";width=25}
      ## Formats the output of Version 
      $VersionFormat = @{Expression={$_.version};Label="Version";width=10}
      ## Formats the output the State(FailorSuccess)
      $StateFormat =   @{Expression={$_._State};Label="State";width=10}
      ## Formats the output of Start Time 
      $StartFormat =   @{Expression={$_._RunStartTime};Label="Start Time";width=20}
      ## Formats the output of Exit Code
      $ExitFormat =    @{Expression={$_.SuccessOrFailureCode};Label="Exit Code";width=9}
      ## Formats the output of Exit reason if failed. 
      $ReasonFormat =  @{Expression={$_._SuccessOrFailureReason};Label="Reason"}
      $list | Format-Table $NameFormat,$PKIDFormat,$ProgramFormat,$VersionFormat,$StateFormat,$StartFormat,$ExitFormat
}


$list = Get-History
$fulllist = add-packagename $list
format-output $fulllist

