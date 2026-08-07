<#
.SYNOPSIS
    Move Windows 11 taskbar alignment to left
.DESCRIPTION
    Sets the TaskbarAl registry value to 0, aligning the Windows 11 taskbar to the left.
    Includes an OS check to ensure it only runs on Windows 11.
    Intune settings :
    Run this script using the logged-on credentials : Yes
    Run script in 64-bit PowerShell : Yes
    Enforce script signature check : No
.NOTES
    Author:  Jannik Reinhard (jannikreinhard.com)
    Version: 1.1
#>

$Path  = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
$Value = "TaskbarAl"

# Windows 11 only
if ((Get-ComputerInfo).OsBuildNumber -lt 22000) {
    Write-Output "Not Windows 11 - skipping"
    exit 0
}

try {

    New-ItemProperty `
        -Path $Path `
        -Name $Value `
        -PropertyType DWord `
        -Value 0 `
        -Force | Out-Null

    Write-Output "Taskbar alignment set to left (TaskbarAl=0)"
    exit 0
}
catch {
    Write-Output "Failed to set TaskbarAl : $($_.Exception.Message)"
    exit 1
}
