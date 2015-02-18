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
$Apps = Get-WmiObject -Namespace "Root\CCM\ClientSDK" -Class CCM_Application
$Apps | Set-DefaultProperties -Properties FullName,SoftwareVersion,Publisher,ApplicabilityState,SupersessionState,InstallState
$Apps