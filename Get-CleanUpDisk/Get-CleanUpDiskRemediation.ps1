<#
.SYNOPSIS
    Remediate low disk space by running Disk Cleanup
.DESCRIPTION
    Configures selected cleanup categories in the registry and invokes CleanMgr.exe
    to free disk space. Use as an Intune Proactive Remediation script.
.NOTES
    Author:  Jannik Reinhard (jannikreinhard.com)
    Version: 1.0
#>

<#
'Active Setup Temp Folders', 'BranchCache', 'Content Indexer Cleaner', 'Device Driver Packages', 'Downloaded Program Files', 'GameNewsFiles', 'GameStatisticsFiles', 'GameUpdateFiles',
'Internet Cache Files', 'Memory Dump Files', 'Offline Pages Files', 'Old ChkDsk Files', 'Previous Installations', 'Recycle Bin', 'Service Pack Cleanup', 'Setup Log Files', 'System error memory dump files',
'System error minidump files', 'Temporary Files', 'Temporary Setup Files', 'Temporary Sync Files', 'Thumbnail Cache', 'Update Cleanup', 'Upgrade Discarded Files', 'User file versions', 'Windows Defender',
'Windows Error Reporting Archive Files', 'Windows Error Reporting Queue Files', 'Windows Error Reporting System Archive Files', 'Windows Error Reporting System Queue Files', 'Windows ESD installation files',
'Windows Upgrade Log Files'
#>

# Run in 64-bit Windows PowerShell as SYSTEM or an elevated administrator.
$ErrorActionPreference = 'Stop'
try {
    $cleanupTypeSelection = 'Temporary Sync Files', 'Downloaded Program Files', 'Memory Dump Files', 'Recycle Bin'
    $cacheRoot = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches'
    $profileName = 'StateFlags0001'
    # Reset this profile first so previously selected categories do not run again.
    foreach ($category in Get-ChildItem -LiteralPath $cacheRoot) {
        $selected = $cleanupTypeSelection -contains $category.PSChildName
        New-ItemProperty -LiteralPath $category.PSPath -Name $profileName -Value ([int]$selected * 2) -PropertyType DWord -Force | Out-Null
    }
    foreach ($name in $cleanupTypeSelection) {
        if (-not (Test-Path -LiteralPath (Join-Path $cacheRoot $name))) {
            throw "Cleanup category '$name' is unavailable on this Windows installation."
        }
    }
    $process = Start-Process -FilePath "$env:SystemRoot\System32\cleanmgr.exe" -ArgumentList '/sagerun:1' -NoNewWindow -Wait -PassThru
    if ($process.ExitCode -ne 0) { throw "cleanmgr exited with code $($process.ExitCode)." }
    exit 0
} catch {
    Write-Error "Failed to run disk cleanup: $_"
    exit 1
}
