$ErrorActionPreference='Stop'
function Assert($condition,$message) { if (-not $condition) { throw $message } }
$root=Split-Path $PSScriptRoot -Parent
# Invoke the inventory with all network/module calls mocked, including empty and single-app devices.
$script:uploads=[System.Collections.Generic.List[object]]::new()
function Get-Module { return $true }
function Connect-MgGraph { param($Scopes,$ErrorAction); Assert ($Scopes -eq 'DeviceManagementManagedDevices.Read.All') 'Wrong inventory scope' }
function Get-MgDeviceManagementManagedDevice {
 param([switch]$All,$ExpandProperty,$ManagedDeviceId,$ErrorAction)
 if ($All) { return @([pscustomobject]@{id='empty';deviceName='Empty'},[pscustomobject]@{id='single';deviceName='München'},[pscustomobject]@{id='many';deviceName='Many'}) }
 $apps=switch($ManagedDeviceId) { empty { @() }; single { @([pscustomobject]@{DisplayName='Äpp';Version='1'}) }; many { @(1..3|ForEach-Object{[pscustomobject]@{DisplayName="App $_";Version='2'}}) } }
 return [pscustomobject]@{detectedApps=$apps}
}
function Invoke-WebRequest {
 param($Uri,$Method,$ContentType,$Headers,$Body,[switch]$UseBasicParsing)
 $json=[Text.Encoding]::UTF8.GetString($Body)
 Assert ($json.StartsWith('[')) 'Single record must remain a JSON array'
 $script:uploads.Add(($json|ConvertFrom-Json))
 return [pscustomobject]@{StatusCode=200}
}
$inventory=Get-Content (Join-Path $root 'Get-DeviceAppInventory/Get-DeviceAppInventory.ps1') -Raw
$inventory=$inventory.Replace('$customerId = ""','$customerId = "test"').Replace('$sharedKey = ""','$sharedKey = "dGVzdA=="')
& ([scriptblock]::Create($inventory))
Assert ($script:uploads.Count -eq 2) 'Expected one upload per non-empty device'
Assert (@($script:uploads[0]).Count -eq 1) 'Single app not preserved'
Assert ($script:uploads[0].AppName -eq 'Äpp') 'UTF-8 app name corrupted'
Assert (@($script:uploads[1]).Count -eq 3) 'Multi-app batch missing records'
# Exercise cleanup with fake registry/process commands.
$script:flags=@{}
function Join-Path { param($Path,$ChildPath); if ($Path -like 'HKLM:*') { return "$Path\$ChildPath" }; Microsoft.PowerShell.Management\Join-Path $Path $ChildPath }
function Get-ChildItem { param($LiteralPath); @('Temporary Sync Files','Downloaded Program Files','Memory Dump Files','Recycle Bin','Update Cleanup') | ForEach-Object { [pscustomobject]@{PSChildName=$_;PSPath="Test:$_"} } }
function New-ItemProperty { param($LiteralPath,$Name,$Value,$PropertyType,[switch]$Force);$script:flags[$LiteralPath]=$Value }
function Test-Path { param($LiteralPath);return $true }
function Start-Process { param($FilePath,$ArgumentList,[switch]$NoNewWindow,[switch]$Wait,[switch]$PassThru);return [pscustomobject]@{ExitCode=0} }
$cleanup=Get-Content (Join-Path $root 'Get-CleanUpDisk/Get-CleanUpDiskRemediation.ps1') -Raw
$cleanup=$cleanup.Replace('exit 0',"throw 'TEST_SUCCESS'").Replace('exit 1',"throw 'TEST_FAILURE'").Replace('Write-Error "Failed to run disk cleanup: $_"','if ($_.Exception.Message -eq ''TEST_SUCCESS'') { return }; throw')
& ([scriptblock]::Create($cleanup))
Assert ($script:flags['Test:Recycle Bin'] -eq 2) 'Selected handler not enabled'
Assert ($script:flags['Test:Update Cleanup'] -eq 0) 'Old handler selection not cleared'
# Parse every changed script and the deployed embedded script without executing Windows UI.
foreach ($relative in @('Get-AllAadGroupAssignments/Get-AllAadGroupAssignments.ps1','Get-CleanUpDisk/Get-CleanUpDiskRemediation.ps1','Get-DeviceAppInventory/Get-DeviceAppInventory.ps1','Get-PendingReboot/Get-PendingRebootNotificationRemediation.ps1','Create-IntuneSystemtray/Create-IntuneSystemtray.ps1','Create-IntuneSystemtray/Deploy-IntuneSystemtrayScript.ps1')) {
 $errors=$null;$null=[System.Management.Automation.Language.Parser]::ParseFile((Join-Path $root $relative),[ref]$null,[ref]$errors)
 Assert ($errors.Count -eq 0) "Parse errors in $relative : $errors"
}
$deploy=Get-Content (Join-Path $root 'Create-IntuneSystemtray/Deploy-IntuneSystemtrayScript.ps1') -Raw
$embedded=[regex]::Match($deploy,'(?s)\$script = @''\r?\n(.*?)\r?\n''@').Groups[1].Value
$errors=$null;$null=[System.Management.Automation.Language.Parser]::ParseInput($embedded,[ref]$null,[ref]$errors)
Assert ($errors.Count -eq 0 -and $embedded.Contains('$path = $PSScriptRoot')) 'Deployed tray parse/path regression'
Write-Host 'PASS: inventory batching/UTF-8/empty devices, cleanup flags, six script parses and embedded tray parse'
