# Manage-Security.ps1
# Safely relax / restore security during image build

param(
    [ValidateSet("Disable","Enable")]
    [string]$Action
)

if (-not $Action -and $env:SECURITY_ACTION) {
    $Action = $env:SECURITY_ACTION
}

if (-not $Action) {
    Write-Error "Use -Action Disable or -Action Enable"
    exit 1
}

# ===============================
# LOGGING
# ===============================
$LogDir = "C:\Packer"
$Timestamp = Get-Date -Format "yyyy-MM-dd-HH-mm-ss"
$LogFile = Join-Path $LogDir "Build-ManageSecurity-$Timestamp.log"

if (-not (Test-Path $LogDir)) {
    New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
}

function Write-Log {
    param([string]$Message)
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $msg = "[$ts] $Message"
    Write-Host $msg -ForegroundColor Green
    Add-Content -Path $LogFile -Value $msg
}

Write-Log "=== Security Management ($Action) ==="

# ===============================
# DISABLE MODE
# ===============================
if ($Action -eq "Disable") {

    Write-Log "Relaxing security for build performance..."

    # --- DEFENDER (SAFE METHOD) ---
    try {
        Set-MpPreference -DisableRealtimeMonitoring $true -ErrorAction SilentlyContinue
        Add-MpPreference -ExclusionPath "C:\Windows\Temp"
        Add-MpPreference -ExclusionPath "C:\Windows\SoftwareDistribution"
        Add-MpPreference -ExclusionPath "C:\Packer"
        Write-Log "Windows Defender real-time protection disabled with exclusions"
    } catch {
        Write-Log "Defender not available or already disabled"
    }

    # --- WINDOWS UPDATE (non-blocking with timeout) ---
    try {
        Write-Log "Stopping Windows Update service (wuauserv)..."
        $svc = Get-Service -Name wuauserv -ErrorAction SilentlyContinue
        if ($svc -and $svc.Status -ne 'Stopped') {
            # Try graceful stop first
            Stop-Service -Name wuauserv -Force -ErrorAction SilentlyContinue

            # Wait up to 30s for stop
            $wait = 30
            $elapsed = 0
            while ($elapsed -lt $wait) {
                Start-Sleep -Seconds 1
                $elapsed++
                try { $svc.Refresh() } catch { $svc = Get-Service -Name wuauserv -ErrorAction SilentlyContinue }
                if ($svc.Status -eq 'Stopped') { break }
            }

            if ($svc.Status -ne 'Stopped') {
                Write-LogError "wuauserv did not stop within $wait seconds (status: $($svc.Status)); attempting sc.exe stop"
                & sc.exe stop wuauserv | Out-Null

                # Wait another short period
                $wait2 = 30
                $elapsed2 = 0
                while ($elapsed2 -lt $wait2) {
                    Start-Sleep -Seconds 1
                    $elapsed2++
                    $svc = Get-Service -Name wuauserv -ErrorAction SilentlyContinue
                    if ($svc.Status -eq 'Stopped') { break }
                }
            }
        }

        $svc = Get-Service -Name wuauserv -ErrorAction SilentlyContinue
        if ($svc -and $svc.Status -eq 'Stopped') {
            Write-Log "Windows Update service stopped"
        } else {
            Write-Log "Windows Update service not stopped (status: $($svc.Status)) - continuing"
        }
    } catch {
        Write-LogError "Failed to stop Windows Update service: $_"
    }

    # --- POWER PLAN ---
    try {
        powercfg /setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c
        Write-Log "High Performance power plan activated"
    } catch {}

    # --- HIBERNATION ---
    try {
        powercfg /hibernate off
        Write-Log "Hibernation disabled"
    } catch {}

    Write-Log "Security relaxed for build"
}

# ===============================
# ENABLE MODE
# ===============================
if ($Action -eq "Enable") {

    Write-Log "Restoring security settings..."

    # --- DEFENDER ---
    try {
        Set-MpPreference -DisableRealtimeMonitoring $false -ErrorAction SilentlyContinue
        Write-Log "Windows Defender real-time protection restored"
    } catch {}

    # --- WINDOWS UPDATE ---
    try {
        Set-Service wuauserv -StartupType Automatic -ErrorAction SilentlyContinue
        Start-Service wuauserv -ErrorAction SilentlyContinue
        Write-Log "Windows Update service restored"
    } catch {}

    Write-Log "Security restored (some changes may require reboot)"
}
