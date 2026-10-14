
<#PSScriptInfo
.VERSION 2.4
.GUID a74f64cf-dbd4-45fe-a8f4-c43e23394d45
.AUTHOR Jannik Reinhard
.COMPANYNAME
.COPYRIGHT
.TAGS
.LICENSEURI
.PROJECTURI https://github.com/JayRHa/Intune-Scripts/blob/main/Get-AllAadGroupAssignments/Get-AllAadGroupAssignments.ps1
.ICONURI
.EXTERNALMODULEDEPENDENCIES
.REQUIREDSCRIPTS
.EXTERNALSCRIPTDEPENDENCIES
.RELEASENOTES
.PRIVATEDATA

#>

<#
.SYNOPSIS
    Show all Intune assignments for a given Azure AD group.
.DESCRIPTION
    Connects to Microsoft Graph and enumerates device configurations,
    administrative templates, compliance policies, apps, scripts,
    remediation scripts, Autopilot profiles, ESP, and security baselines
    to display which are assigned (included/excluded) for a specified group.
.INPUTS
    None required
.OUTPUTS
    Assignments of a specific AAD Group
.NOTES
    Author : Jannik Reinhard (jannikreinhard.com)
    Version: 2.4
    Release: v1.0 - Init
             v2.0 - Rewrite
             v2.1 - Generalization
             v2.2 - Add Graph scope
             v2.3 - Fixed scope to Read, removed Select-MgProfile
#>
Param()

function Write-Entry{
    param(
        [Parameter(Mandatory)]$topic,
        [Parameter(Mandatory)]$value
    )
    Write-Host "$($topic): " -ForegroundColor White -NoNewline
    Write-Host $value -ForegroundColor Yellow

}
function Get-GraphCallCustom {
    param(
        [Parameter(Mandatory)]$endpoint,
        $value=$true
    )
    $uri = "https://graph.microsoft.com/beta/$endpoint"
    $items = [System.Collections.Generic.List[object]]::new()
    do {
        $page = Invoke-MgGraphRequest -Uri $uri -Method Get -OutputType PSObject -ErrorAction Stop
        foreach ($item in $page.value) { $items.Add($item) }
        $uri = $page.'@odata.nextLink'
    } while ($uri)
    if ($value) { return $items.ToArray() }
    return [PSCustomObject]@{ value = $items.ToArray() }

}

function Get-GroupPerName{
    param(
        [Parameter(Mandatory)]$groupName
    )
    if($groupName -eq "All users"){
        return [PSCustomObject]@{
            id               = 'acacacac-9df4-4c7d-9d50-4ef0226f57a9'
            createdDateTime  = '00/00/0000'
            displayName      = 'All users (System group)'
        }
    }
    if($groupName -eq "All devices"){
        return [PSCustomObject]@{
            id               = 'adadadad-808e-44e2-905a-0b7873a8a531'
            createdDateTime  = '00/00/0000'
            displayName      = 'All devices (System group)'
        }
    }

    $filter = [Uri]::EscapeDataString("displayName eq '" + $groupName.Replace("'", "''") + "'")
    $matches = @(Get-GraphCallCustom -endpoint ('groups?$filter=' + $filter))
    if ($matches.Count -gt 1) {
        throw "Multiple groups named '$groupName'. Use a unique group display name before running this report."
    }
    return $matches
}

function Get-Topic{
    param(
        [Parameter(Mandatory)]$topicHeadline,
        [Parameter(Mandatory)]$groupId,
        [Parameter(Mandatory)]$uri,
        [Parameter(Mandatory)]$uriAssignment,
        [Parameter(Mandatory)]$type
    )
    # Enrollment Status Page
    Write-Host $topicHeadline -ForegroundColor Yellow
    Write-Host "------------------------------"
    $hasAssignment = Get-GroupAssignments -groupId $groupId -uri $uri -type $type -uriAssignment $uriAssignment
    if(-not $hasAssignment) {Write-Host "No Assignment" -ForegroundColor green}
    Write-Host "------------------------------"
}

function Get-GroupAssignments{
    param(
        [Parameter(Mandatory)]
        $groupId,
        [Parameter(Mandatory)]
        $uri,
        [Parameter(Mandatory)]
        $uriAssignment,
        [Parameter(Mandatory)]
        $type
        )
    #Device Configuration
    $configurations = (Get-GraphCallCustom -endpoint "$uri/$type")
    $hasAssignment = $false

    foreach ($configuration in $configurations){
        $configurationName = $configuration.displayName
        if (-not $configurationName) { $configurationName = $configuration.name }
        $assignmentsInfo = (Get-GraphCallCustom -endpoint ("$uri/$type/" + $configuration.id + "/$uriAssignment") -value $false)

        if($uriAssignment -eq "groupAssignments"){$assignments = $assignmentsInfo.value}
        elseif($uriAssignment -eq "assignments"){$assignments = $assignmentsInfo.value.target }


        foreach($assignment in $assignments){
            # Include
            if($uriAssignment -eq "groupAssignments" -and $assignment.targetGroupId -eq $groupId -and (-not $assignment.excludeGroup)){
                Write-Host "+" $configurationName
                $hasAssignment = $true
            }elseif($uriAssignment -eq "assignments" -and $assignment.groupId -eq $groupId -and $assignment.'@odata.type' -eq '#microsoft.graph.groupAssignmentTarget'){
                Write-Host "+" $configurationName
                $hasAssignment = $true
            }elseif($uriAssignment -eq "assignments" -and $groupId -eq "acacacac-9df4-4c7d-9d50-4ef0226f57a9" -and $assignment.'@odata.type' -eq '#microsoft.graph.allLicensedUsersAssignmentTarget'){
                Write-Host "+" $configurationName
                $hasAssignment = $true
            }elseif($uriAssignment -eq "assignments" -and $groupId -eq "adadadad-808e-44e2-905a-0b7873a8a531" -and $assignment.'@odata.type' -eq '#microsoft.graph.allDevicesAssignmentTarget'){
                Write-Host "+" $configurationName
                $hasAssignment = $true
            }

            # Exclude
            if($uriAssignment -eq "groupAssignments" -and $assignment.targetGroupId -eq $groupId -and $assignment.excludeGroup){
                Write-Host "-" $configurationName
                $hasAssignment = $true
            }elseif($uriAssignment -eq "assignments" -and $assignment.groupId -eq $groupId -and $assignment.'@odata.type' -eq '#microsoft.graph.exclusionGroupAssignmentTarget'){
                Write-Host "-" $configurationName
                $hasAssignment = $true
            }
        }
    }
    return $hasAssignment
}

#################################################################################################
###################################### Install Modules###########################################
#################################################################################################
if (Get-Module -ListAvailable -Name Microsoft.Graph.Authentication) {
    Write-Information "Microsoft Graph already installed"
} else {
    try {
        Install-Module -Name Microsoft.Graph.Authentication -Scope CurrentUser -Repository PSGallery -Force
    }catch{
        $_.message
        exit
    }
}
Import-Module microsoft.graph.authentication


#########################################################################################################
############################################ Start ######################################################
#########################################################################################################

#Auth
# Read-only scopes for the resource families queried below. No directory-wide write access.
$graph = Connect-MgGraph -Scopes @(
    'DeviceManagementConfiguration.Read.All',
    'DeviceManagementApps.Read.All',
    'DeviceManagementServiceConfig.Read.All',
    'DeviceManagementScripts.Read.All',
    'Group.Read.All'
) -ErrorAction Stop
$group = $null

# Get an check aad group
while ($null -eq $group) {
    Write-Host "------------------------------"
    $aadGroupName = Read-Host "Enter the name of the AAD Group "
    $group = Get-GroupPerName -groupName $aadGroupName
    if($null -eq $group) {Write-Host "Group not found. Try again" -ForegroundColor Red}
    if($null -eq $group) {Write-Host "Open the Azure AD Portal to see all group: https://portal.azure.com/#view/Microsoft_AAD_IAM/GroupsManagementMenuBlade/~/AllGroups" -ForegroundColor Red}
    Write-Host "------------------------------"
}

Write-Host "------------------------------"
Write-Host "Group Info" -ForegroundColor Yellow
Write-Host "------------------------------"
Write-Entry -topic "Group name" -value $group.displayName
Write-Entry -topic "Group Id" -value $group.id
Write-Entry -topic "Created" -value $group.createdDateTime
Write-Host "------------------------------"

# Device Configuration
Get-Topic -topicHeadline "Device Configuration" -groupId $group.id -uri "deviceManagement" -type "deviceConfigurations" -uriAssignment "groupAssignments"

# Administrative templates
Get-Topic -topicHeadline "Administrative Templates" -groupId $group.id -uri "deviceManagement" -type "groupPolicyConfigurations" -uriAssignment "assignments"

# Device Compliance Policies
Get-Topic -topicHeadline "Device Compliance Policies" -groupId $group.id -uri "deviceManagement" -type "deviceCompliancePolicies" -uriAssignment "assignments"

# Apps
Get-Topic -topicHeadline "Apps" -groupId $group.id -uri "deviceAppManagement" -type "mobileApps" -uriAssignment "assignments"

# Scripts
Get-Topic -topicHeadline "Scripts" -groupId $group.id -uri "deviceManagement" -type "deviceManagementScripts" -uriAssignment "assignments"

# Remediation Scripts
Get-Topic -topicHeadline "Remediation Scripts" -groupId $group.id -uri "deviceManagement" -type "deviceHealthScripts" -uriAssignment "assignments"

# Autopilot profile
Get-Topic -topicHeadline "Windows Autopilot deployment profiles" -groupId $group.id -uri "deviceManagement" -type "windowsAutopilotDeploymentProfiles" -uriAssignment "assignments"

# Enrollment Status Page
Get-Topic -topicHeadline "Enrollment Status Page" -groupId $group.id -uri "deviceManagement" -type "deviceEnrollmentConfigurations" -uriAssignment "assignments"

# Security baselines
Get-Topic -topicHeadline "Security baselines" -groupId $group.id -uri "deviceManagement" -type "intents" -uriAssignment "assignments"

# Settings Catalog, modern endpoint-security policies, and migrated security baselines
Get-Topic -topicHeadline "Settings Catalog and modern Endpoint Security" -groupId $group.id -uri "deviceManagement" -type "configurationPolicies" -uriAssignment "assignments"

# App configuration and protection
Get-Topic -topicHeadline "Managed-device app configuration" -groupId $group.id -uri "deviceAppManagement" -type "mobileAppConfigurations" -uriAssignment "assignments"
Get-Topic -topicHeadline "iOS app protection" -groupId $group.id -uri "deviceAppManagement" -type "iosManagedAppProtections" -uriAssignment "assignments"
Get-Topic -topicHeadline "Android app protection" -groupId $group.id -uri "deviceAppManagement" -type "androidManagedAppProtections" -uriAssignment "assignments"

# Update rings already appear in deviceConfigurations; dedicated update profiles follow.
Get-Topic -topicHeadline "Windows feature updates" -groupId $group.id -uri "deviceManagement" -type "windowsFeatureUpdateProfiles" -uriAssignment "assignments"
Get-Topic -topicHeadline "Windows quality updates" -groupId $group.id -uri "deviceManagement" -type "windowsQualityUpdateProfiles" -uriAssignment "assignments"
