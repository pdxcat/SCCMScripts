param(
    [CmdletBinding()]
	[Parameter(Mandatory=$true)]
    [Alias('Name')]
    [String]$SoftwareName,
    [Parameter(Mandatory=$false)]
	[String]$Version,
    [Parameter(Mandatory=$false)]
    [Alias('Vendor')]
	[String]$Manufacturer,
    [Parameter(Mandatory=$false)]
	[String[]]$InstallTypes = $null,
    [Parameter(Mandatory=$false)]
	[String[]]$UninstallTypes = $null
)

# Load necessary Modules.
Import-Module ActiveDirectory
Import-Module "C:\Program Files (x86)\Microsoft Configuration Manager\AdminConsole\bin\ConfigurationManager.psd1"

$GroupOU = "OU=SCCM Applications,OU=CECS Groups,DC=DS,DC=CECS,DC=PDX,DC=EDU"

# Create Install group(s)
if ($InstallTypes) {
	foreach ($Type in $InstallTypes) {
		$GroupName = "SCCM_${SoftwareName} ${Version} ${Type}"
		Write-Host "Creating group '$GroupName'."
		New-ADGroup $GroupName -DisplayName $GroupName -Path $GroupOU -GroupScope Global
	}
} else {
	$GroupName = "SCCM_${SoftwareName} ${Version}"
	Write-Host "Creating group '$GroupName'."
	New-ADGroup $GroupName -DisplayName $GroupName -Path $GroupOU -GroupScope Global
}

# Create Uninstall group(s)
if ($UninstallTypes) {
	foreach ($Type in $UninstallTypes) {
		$GroupName = "SCCM_${SoftwareName} ${Version} ${Type} Uninstall"
		Write-Host "Creating group '$GroupName'."
		New-ADGroup $GroupName -DisplayName $GroupName -Path $GroupOU -GroupScope Global
	}
} else {
	$GroupName = "SCCM_${SoftwareName} ${Version} Uninstall"
	Write-Host "Creating group '$GroupName'."
	New-ADGroup $GroupName -DisplayName $GroupName -Path $GroupOU -GroupScope Global
}
