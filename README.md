SCCMScripts
===========

Collection of PowerShell scripts to interact with SCCM 2012

get-executionhistory - Used to get the execution history of sccm 2012 advertizements. It will show
information about the package including whether it was successifully installed or failed. 

get-sccmschedule - Used to determine whether or not an advertizements have been schedule to a computer
and will show the date and time of when the advertizement was ran. 

Get deployments
Cmdlets have been created to get the object associated with an actual deployment.

Get-CMApplicationDeployment -Gets an application deployment.

Get-CMBaselineDeployment - Gets a baseline deployment.

Get-CMConfigurationPolicyDeployment - Gets a configuration policy deployment.

Get-CMPackageDeployment - Gets a package deployment from Configuration Manager.

Get-CMSoftwareUpdateDeployment - Gets a software update deployment.

Get-CMTaskSequenceDeployment - Gets a task sequence deployment in Configuration Manager.

Updated SCCM CMDlets
https://docs.microsoft.com/en-us/powershell/sccm/1702_release_notes?view=sccm-ps
