<#
    .Synopsis
    This retrieves the execution history of SCCM installed software. 
    
    .Description
    This script gets the execution history of software installed by SCCM. This is done by reading the information 
    from registry of the computer. It will output the package name, package id, program name, state, time ran and 
    exit code. It takes the computer's name as input. 

    .Example
    get-executionhistory.ps1 smiley
    This will output the the execution history.  
#>
param([string]$ComputerName)

## This is the registry path where the execution history is stored.
$Reg = "HKLM:\SOFTWARE\Microsoft\SMS\Mobile Client\Software Distribution\Execution History\System"

## This where the package name and package id information is stored.
$PkgInfo = Get-WmiObject -Namespace "Root\sms\Site_KAT" -Class SMS_Program -ComputerName Itzamna | select PackageID,PackageName,PackageVersion -Unique

## This will retrieve the execution history from the registry. The function will create a object and add the 
## additional information. Returns the list. 
function Get-History{

 ## This uses the invoke command to run the script block on a remote computer. 
 $History = Invoke-Command -ComputerName $ComputerName {
            ## This used to pass a local parameter to the remote computer. 
            param($Reg)
            
            $PKIDlist = Get-ChildItem $Reg | select -ExpandProperty Name | foreach{$_.split('\')[8]} 
            foreach($PKID in $PKIDlist){
                $GUID = Get-ChildItem $Reg\$PKID | select -ExpandProperty Name | foreach{$_.split('\')[9]}
                foreach($GID in $GUID){
                    $APPInfo = Get-ItemProperty $Reg\$PKID\$GID 
                    $APPInfo | Add-Member -Type NoteProperty -Name PKID -Value $PKID
                    $APPInfo
                }
            }
            } -ArgumentList $Reg
 $List = $History | select PKID,_ProgramID,_State,_RunStartTime,SuccessOrFailureCode,SuccessOrFailureReason

 return $List
}

## This will add the package name and the package version. This information is gained from the SCCM
## server. 
function Add-Packagename{
    param([object]$List)
    $TempList = $List
    foreach($PK in $TempList){
        foreach($PKList in $PkgInfo){
            if($PK.PKID -eq $PKList.PackageID){
                $PK | Add-Member -Type NoteProperty -Name Name -Value $PKList.PackageName
                $PK | Add-Member -Type NoteProperty -Name Version -Value $PKList.PackageVersion
                $PK
            }
        }
    }

}

## This will format the output into a more readable format. 
function Format-Output{
     param(
        [object]$List
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
      $List | Format-Table $NameFormat,$PKIDFormat,$ProgramFormat,$VersionFormat,$StateFormat,$StartFormat,$ExitFormat
}


$List = Get-History
$FullList = Add-Packagename $List
Format-Output $FullList

