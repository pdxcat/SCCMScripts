<#
.Synopsis
    Gets the status of SCCM 2012 Applications that have been deployed to the specified computer.

.Description
    This script queries the WMI repository on the specified computer (or the local machine if a computer name is not given)
    for information about SCCM 2012 Applications that have been deployed to it.

.Inputs
    [String]ComputerName
        The name of the computer to query.

.Outputs
    Writes WMI objects of the type CCM_Application to output, with custom formatting.
    
.Example
    .\Get-ApplicationStatus.ps1 -ComputerName TYRAEL
    
    Description
    -----------
    Lists the SCCM 2012 Applications deployed to the computer named TYRAEL.
#>
param(
    [String]$ComputerName = $env:computername
)
Function Set-DefaultProperties {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true,ValueFromPipeline=$True)][Object[]]$InputObject,
        [Parameter(Mandatory=$true)][String[]]$Properties,
        [Switch]$PassThru
    )
    BEGIN {
        $PropSet = New-Object System.Management.Automation.PSPropertySet('DefaultDisplayPropertySet',[string[]]$Properties)
        $PSStandardMembers = [System.Management.Automation.PSMemberInfo[]]@($PropSet)
    }
    PROCESS {
        $InputObject | Add-Member -MemberType MemberSet -Name PSStandardMembers -Value $PSStandardMembers
        if ($PassThru) { Write-Output $InputObject }
    }
}
$Apps = Get-WmiObject -ComputerName $ComputerName -Namespace "Root\CCM\ClientSDK" -Class CCM_Application
$Apps | Set-DefaultProperties -Properties FullName,ApplicabilityState,SupersessionState,InstallState
$Apps | Sort-Object FullName,InstallState