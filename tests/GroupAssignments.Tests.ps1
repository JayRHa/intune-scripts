$ErrorActionPreference = 'Stop'
$path = Join-Path $PSScriptRoot '../Get-AllAadGroupAssignments/Get-AllAadGroupAssignments.ps1'
$ast = [System.Management.Automation.Language.Parser]::ParseFile($path, [ref]$null, [ref]$null)
$ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $false) | ForEach-Object { . ([scriptblock]::Create($_.Extent.Text)) }
function Assert($condition, $message) { if (-not $condition) { throw $message } }
$script:requests = [System.Collections.Generic.List[string]]::new()
function Invoke-MgGraphRequest {
    param($Uri, $Method, $OutputType, $ErrorAction)
    $script:requests.Add($Uri)
    if ($Uri -eq 'https://graph.microsoft.com/beta/page2') { return [pscustomobject]@{value=@([pscustomobject]@{id='2'})} }
    return [pscustomobject]@{value=@([pscustomobject]@{id='1'}); '@odata.nextLink'='https://graph.microsoft.com/beta/page2'}
}
Assert (@(Get-GraphCallCustom -endpoint 'groups').Count -eq 2) 'List pagination lost a record'
Assert ((Get-GraphCallCustom -endpoint 'groups' -value $false).value.Count -eq 2) 'Assignment pagination lost a record'
function Invoke-MgGraphRequest {
    param($Uri, $Method, $OutputType, $ErrorAction)
    $script:requests.Add($Uri)
    return [pscustomobject]@{value=@([pscustomobject]@{id='unique'})}
}
$null=Get-GroupPerName -groupName "O'Brien & Sons"
Assert ([Uri]::UnescapeDataString($script:requests[-1]).Contains("displayName eq 'O''Brien & Sons'")) 'Group filter not escaped'
function Invoke-MgGraphRequest { throw 'Forbidden' }
try { $null=Get-GraphCallCustom -endpoint 'groups'; throw 'Expected request failure' } catch { Assert ($_.Exception.Message -eq 'Forbidden') 'Request failure swallowed' }
function Invoke-MgGraphRequest { return [pscustomobject]@{value=@([pscustomobject]@{id='1'},[pscustomobject]@{id='2'})} }
try { $null=Get-GroupPerName -groupName 'duplicate'; throw 'Expected ambiguous-name failure' } catch { Assert ($_.Exception.Message -like 'Multiple groups*') 'Ambiguous groups not rejected' }
function Get-GraphCallCustom {
    param($endpoint, $value=$true)
    if ($endpoint -eq 'deviceManagement/configurationPolicies') { return [pscustomobject]@{id='policy';name='Modern policy'} }
    return [pscustomobject]@{value=@([pscustomobject]@{target=[pscustomobject]@{groupId='group';'@odata.type'='#microsoft.graph.groupAssignmentTarget'}})}
}
Assert (Get-GroupAssignments -groupId 'group' -uri deviceManagement -type configurationPolicies -uriAssignment assignments) 'Modern policy assignment not found'
Write-Host 'PASS: list/assignment pagination, escaped filters, ambiguity, request errors and modern assignment matching'
