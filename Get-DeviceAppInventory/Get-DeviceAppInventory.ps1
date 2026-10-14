<#
.SYNOPSIS
    Export discovered apps from Intune to a Log Analytics workspace.
.DESCRIPTION
    Connects to Microsoft Graph, enumerates all managed devices and their
    detected applications, then sends each device app collection as JSON to the Azure
    Monitor HTTP Data Collector API.
.NOTES
    Author : Jannik Reinhard (jannikreinhard.com)
    Version: 1.1
    Release: v1.0 - Init
             v1.1 - Removed deprecated Select-MgProfile, fixed Get-GraphAuthentication,
                     renamed Send-LogAnalyticsData, added guards and try/catch
#>

################################################################################################################
############################################# Variables ########################################################
################################################################################################################
$customerId = "" # Add Workspace ID
$sharedKey = "" # Add Primary key
$logType = "DiscoveredApps"

if ([string]::IsNullOrEmpty($customerId) -or [string]::IsNullOrEmpty($sharedKey)) {
    Write-Error "Log Analytics credentials are not configured. Set `$customerId and `$sharedKey before running."
    exit 1
}

function Get-GraphAuthentication{
    if (-not (Get-Module -ListAvailable -Name 'Microsoft.Graph')) {
        Write-Error "Microsoft.Graph module is not installed. Install via: Install-Module Microsoft.Graph -Scope CurrentUser"
        return $false
    }

    try {
      Connect-MgGraph -Scopes "DeviceManagementManagedDevices.Read.All" -ErrorAction Stop
    } catch {
      Write-Error "Failed to connect to MgGraph: $_"
      return $false
    }

    return $true
}

Function Build-Signature ($customerId, $sharedKey, $date, $contentLength, $method, $contentType, $resource)
{
    $xHeaders = "x-ms-date:" + $date
    $stringToHash = $method + "`n" + $contentLength + "`n" + $contentType + "`n" + $xHeaders + "`n" + $resource

    $bytesToHash = [Text.Encoding]::UTF8.GetBytes($stringToHash)
    $keyBytes = [Convert]::FromBase64String($sharedKey)

    $sha256 = New-Object System.Security.Cryptography.HMACSHA256
    $sha256.Key = $keyBytes
    $calculatedHash = $sha256.ComputeHash($bytesToHash)
    $encodedHash = [Convert]::ToBase64String($calculatedHash)
    $authorization = 'SharedKey {0}:{1}' -f $customerId,$encodedHash
    return $authorization
}

Function Send-LogAnalyticsData($f_customerId, $f_sharedKey, $f_body, $f_logType)
{
    $method = "POST"
    $contentType = "application/json"
    $resource = "/api/logs"
    $rfc1123date = [DateTime]::UtcNow.ToString("r")
    $contentLength = $f_body.Length
    $signature = Build-Signature `
        -customerId $f_customerId `
        -sharedKey $f_sharedKey `
        -date $rfc1123date `
        -contentLength $contentLength `
        -method $method `
        -contentType $contentType `
        -resource $resource
    $uri = "https://" + $f_customerId + ".ods.opinsights.azure.com" + $resource + "?api-version=2016-04-01"

    $headers = @{
        "Authorization" = $signature;
        "Log-Type" = $f_logType;
        "x-ms-date" = $rfc1123date;
        "time-generated-field" = "";
    }

    $response = Invoke-WebRequest -Uri $uri -Method $method -ContentType $contentType -Headers $headers -Body $f_body -UseBasicParsing
    return $response.StatusCode
}

#################################################################################################
########################################### Start ###############################################
#################################################################################################

if (-not (Get-GraphAuthentication)) { exit 1 }

try {
    Get-MgDeviceManagementManagedDevice -All -ErrorAction Stop | ForEach-Object {
        $deviceHostname = $_.deviceName
        $device = Get-MgDeviceManagementManagedDevice -ExpandProperty detectedApps -ManagedDeviceId $_.id -ErrorAction Stop
        $records = @($device.detectedApps | ForEach-Object {
            [PSCustomObject][ordered]@{
                Hostname = $deviceHostname
                AppName = $_.DisplayName
                Version = $_.Version
            }
        })
        if ($records.Count -gt 0) {
            # Bound each request to 1 MiB of UTF-8 JSON, below the API's 30 MiB limit.
            $batch = [System.Collections.Generic.List[object]]::new()
            $batchBytes = 2
            foreach ($record in $records) {
                $recordBytes = [Text.Encoding]::UTF8.GetByteCount(($record | ConvertTo-Json -Compress))
                if ($batch.Count -gt 0 -and ($batchBytes + $recordBytes + 1) -gt 1MB) {
                    $null = Send-LogAnalyticsData -f_customerId $customerId -f_sharedKey $sharedKey -f_logType $logType -f_body ([Text.Encoding]::UTF8.GetBytes((ConvertTo-Json -InputObject @($batch.ToArray()) -Compress)))
                    $batch.Clear()
                    $batchBytes = 2
                }
                if ($recordBytes -gt (1MB - 2)) { throw "An app inventory record exceeds the batch limit." }
                $batch.Add($record)
                $batchBytes += $recordBytes + 1
            }
            if ($batch.Count -gt 0) {
                $null = Send-LogAnalyticsData -f_customerId $customerId -f_sharedKey $sharedKey -f_logType $logType -f_body ([Text.Encoding]::UTF8.GetBytes((ConvertTo-Json -InputObject @($batch.ToArray()) -Compress)))
            }
        }
    }
}
catch {
    Write-Error "Failed to process device app inventory: $_"
    exit 1
}
