# Repair-CloudbaseInit.ps1
# Terraform-callable: Reset and repair Cloudbase-Init service
#
# Usage Examples:
#   .\Repair-CloudbaseInit.ps1                 # Full repair and service restart
#   .\Repair-CloudbaseInit.ps1 -RestartOnly    # Just restart the service

param(
    [switch]$RestartOnly
)

$ErrorActionPreference = "Continue"
$logFile = "C:\Windows\Temp\cloudbase-init-repair-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"

function Write-RepairLog {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    Write-Host $logMessage
    Add-Content -Path $logFile -Value $logMessage
}

Write-RepairLog "=== Cloudbase-Init Repair Started ===" -Level "INFO"
Write-RepairLog "RestartOnly: $RestartOnly"

$cloudbaseDir = "C:\Program Files\Cloudbase Solutions\Cloudbase-Init"
$dataDir = Join-Path $cloudbaseDir "data"
$logDir = Join-Path $cloudbaseDir "log"

try {
    if (-not $RestartOnly) {
        # Stop the service
        Write-RepairLog "Stopping Cloudbase-Init service..."
        Stop-Service cloudbase-init -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 2

        # Clear run state (forces re-run on next boot)
        Write-RepairLog "Clearing Cloudbase-Init run state..."
        if (Test-Path $dataDir) {
            Get-ChildItem -Path $dataDir -File | Remove-Item -Force -ErrorAction SilentlyContinue
            Write-RepairLog "Cleared data directory"
        }

        # Archive old logs
        Write-RepairLog "Archiving old logs..."
        if (Test-Path $logDir) {
            $archiveDir = "C:\Windows\Temp\cloudbase-init-logs-archive-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
            New-Item -ItemType Directory -Path $archiveDir -Force | Out-Null
            Get-ChildItem -Path $logDir -File | Copy-Item -Destination $archiveDir -ErrorAction SilentlyContinue
            Get-ChildItem -Path $logDir -File | Remove-Item -Force -ErrorAction SilentlyContinue
            Write-RepairLog "Logs archived to: $archiveDir"
        }

        # Verify service configuration
        Write-RepairLog "Verifying service configuration..."
        $service = Get-Service cloudbase-init -ErrorAction SilentlyContinue
        if ($service) {
            Set-Service -Name cloudbase-init -StartupType Automatic
            Write-RepairLog "Service startup type set to Automatic"
        } else {
            Write-RepairLog "WARNING: Cloudbase-Init service not found!" -Level "WARN"
        }
    }

    # Restart the service
    Write-RepairLog "Starting Cloudbase-Init service..."
    Start-Service cloudbase-init -ErrorAction Stop
    Start-Sleep -Seconds 2

    # Verify service is running
    $service = Get-Service cloudbase-init -ErrorAction SilentlyContinue
    if ($service -and $service.Status -eq 'Running') {
        Write-RepairLog "Cloudbase-Init service is running" -Level "SUCCESS"
    } else {
        Write-RepairLog "WARNING: Service is not running (Status: $($service.Status))" -Level "WARN"
    }

    Write-RepairLog "=== Cloudbase-Init Repair Complete ===" -Level "SUCCESS"

    # Output summary
    @{
        LogFile = $logFile
        ServiceStatus = $service.Status
        ServiceStartType = $service.StartType
        Success = $true
    } | ConvertTo-Json

} catch {
    Write-RepairLog "Repair failed: $_" -Level "ERROR"
    Write-RepairLog $_.ScriptStackTrace -Level "ERROR"

    @{
        LogFile = $logFile
        Success = $false
        Error = $_.Exception.Message
    } | ConvertTo-Json

    throw
}
