<#
.SYNOPSIS
    Detect taskbar alignment on Windows 11
.DESCRIPTION
    Checks whether the Windows 11 taskbar is aligned to the left (value 0).
    Exits with code 0 if aligned left, code 1 otherwise.
.NOTES
    Author:  Jannik Reinhard (jannikreinhard.com)
    Version: 1.1
#>

$Path  = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
$Value = "TaskbarAl"

# Windows 11 only
if (Get-ComputerInfo.OsBuildNumber -lt 22000) {
    Write-Output "Not Windows 11 - compliant"
    exit 0
}

try {
    $CurrentValue = (Get-ItemProperty -Path $Path -Name $Value -ErrorAction Stop).TaskbarAl

    if ($CurrentValue -eq 0) {
        Write-Output "Compliant - Taskbar aligned left"
        exit 0
    }

    Write-Output "Non-compliant - TaskbarAl=$CurrentValue"
    exit 1
}
catch {
    Write-Output "Non-compliant - TaskbarAl not found"
    exit 1
}
