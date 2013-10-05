<#
    .Synopsis
    Displays the currently running advertisements on the given computer.

    .Description
    Returns the status of all current advertisements to the given computer.  The name of the program, 
    package, package version and current state are output.
    
    .Example
    .\running_execuitions bulbasaur

#>

param (
    [string]$computername 
)

#Grabs all running advertisements on the client, ignoring the Configuration Manager Client Upgrade
$runningexecutions = get-wmiobject -namespace root\ccm\softmgmtagent -computername $computername -class ccm_executionrequestex | where-object {$_.state -ne "waitingdisabled"}

if ($runningexecutions -eq $null) {
    write-host "No current installations being run"
}

$runningexecutions | format-table -Property programid,mifpackagename,mifpackageversion,state
