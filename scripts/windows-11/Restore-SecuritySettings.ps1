# Restore-SecuritySettings.ps1
# Re-enables Windows Defender and UAC before template finalization
# These were disabled during build for faster provisioning

$LogFile = "C:\windows-security-restore.log"

function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] $Message"
    Write-Host $logMessage -ForegroundColor Green
    Add-Content -Path $LogFile -Value $logMessage
}

function Write-LogError {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] ERROR: $Message"
    Write-Host $logMessage -ForegroundColor Red
    Add-Content -Path $LogFile -Value $logMessage
}

Write-Log "=== Restoring Security Settings ==="

# ============================================================================
# 1. RE-ENABLE USER ACCESS CONTROL (UAC)
# ============================================================================
Write-Log "Re-enabling User Access Control (UAC)..."
try {
    $uacPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"
    Set-ItemProperty -Path $uacPath -Name "EnableLUA" -Value 1 -Type DWord -Force

    $currentValue = (Get-ItemProperty -Path $uacPath).EnableLUA
    if ($currentValue -eq 1) {
        Write-Log "UAC re-enabled successfully (EnableLUA = 1)"
    } else {
        Write-LogError "UAC re-enable failed (EnableLUA = $currentValue)"
    }
} catch {
    Write-LogError "Failed to re-enable UAC: $_"
}

# ============================================================================
# 2. RE-ENABLE WINDOWS DEFENDER
# ============================================================================
Write-Log "Re-enabling Windows Defender..."

# Remove the DisableAntiSpyware registry key
try {
    $defenderPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender"

    if (Test-Path $defenderPath) {
        # Remove the DisableAntiSpyware value if it exists
        $disableValue = Get-ItemProperty -Path $defenderPath -Name "DisableAntiSpyware" -ErrorAction SilentlyContinue
        if ($null -ne $disableValue) {
            Remove-ItemProperty -Path $defenderPath -Name "DisableAntiSpyware" -Force -ErrorAction Stop
            Write-Log "Removed DisableAntiSpyware registry value"
        }

        # Also check for DisableRealtimeMonitoring
        $realtimeValue = Get-ItemProperty -Path $defenderPath -Name "DisableRealtimeMonitoring" -ErrorAction SilentlyContinue
        if ($null -ne $realtimeValue) {
            Remove-ItemProperty -Path $defenderPath -Name "DisableRealtimeMonitoring" -Force -ErrorAction Stop
            Write-Log "Removed DisableRealtimeMonitoring registry value"
        }
    }

    Write-Log "Windows Defender policy restrictions removed"
} catch {
    Write-LogError "Failed to remove Defender policy: $_"
}

# Re-enable Windows Defender services
Write-Log "Configuring Windows Defender services..."
try {
    # Enable Windows Defender Antivirus Service
    $defenderService = Get-Service -Name "WinDefend" -ErrorAction SilentlyContinue
    if ($defenderService) {
        Set-Service -Name "WinDefend" -StartupType Automatic -ErrorAction SilentlyContinue
        Write-Log "WinDefend service set to Automatic"
    }

    # Enable Windows Security Center
    $securityCenter = Get-Service -Name "wscsvc" -ErrorAction SilentlyContinue
    if ($securityCenter) {
        Set-Service -Name "wscsvc" -StartupType Automatic -ErrorAction SilentlyContinue
        Start-Service -Name "wscsvc" -ErrorAction SilentlyContinue
        Write-Log "Security Center service enabled and started"
    }
} catch {
    Write-LogError "Failed to configure Defender services: $_"
}

# Use Set-MpPreference to ensure real-time protection is enabled
Write-Log "Enabling Windows Defender real-time protection..."
try {
    Set-MpPreference -DisableRealtimeMonitoring $false -ErrorAction SilentlyContinue
    Set-MpPreference -DisableBehaviorMonitoring $false -ErrorAction SilentlyContinue
    Set-MpPreference -DisableBlockAtFirstSeen $false -ErrorAction SilentlyContinue
    Set-MpPreference -DisableIOAVProtection $false -ErrorAction SilentlyContinue
    Set-MpPreference -DisableScriptScanning $false -ErrorAction SilentlyContinue
    Write-Log "Windows Defender real-time protection settings restored"
} catch {
    Write-LogError "Failed to set Defender preferences (may require reboot): $_"
}

# ============================================================================
# 3. RE-ENABLE WINDOWS UPDATE (Optional - controlled by CloudBase-Init)
# ============================================================================
Write-Log "Restoring Windows Update settings..."
try {
    $wuPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"

    if (Test-Path $wuPath) {
        # Remove NoAutoUpdate to restore default behavior
        $noAutoUpdate = Get-ItemProperty -Path $wuPath -Name "NoAutoUpdate" -ErrorAction SilentlyContinue
        if ($null -ne $noAutoUpdate) {
            Remove-ItemProperty -Path $wuPath -Name "NoAutoUpdate" -Force -ErrorAction Stop
            Write-Log "Removed NoAutoUpdate policy - Windows Update restored to defaults"
        }
    }
} catch {
    Write-LogError "Failed to restore Windows Update settings: $_"
}

# ============================================================================
# 4. VERIFY SECURITY SETTINGS
# ============================================================================
Write-Log "=== Verifying Security Settings ==="

# Check UAC
$uacStatus = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System").EnableLUA
Write-Log "UAC Status: $(if ($uacStatus -eq 1) { 'Enabled' } else { 'Disabled' })"

# Check Defender policy
$defenderPolicy = Get-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender" -Name "DisableAntiSpyware" -ErrorAction SilentlyContinue
Write-Log "Defender Policy: $(if ($null -eq $defenderPolicy) { 'No restrictions (Enabled)' } else { 'Policy exists - may be disabled' })"

# Check Defender service
$defenderSvc = Get-Service -Name "WinDefend" -ErrorAction SilentlyContinue
if ($defenderSvc) {
    Write-Log "Defender Service: $($defenderSvc.Status) (StartType: $($defenderSvc.StartType))"
}

Write-Log "=== Security Settings Restoration Complete ==="
Write-Log "NOTE: Some changes may require a reboot to take full effect"
Write-Log "NOTE: Sysprep will finalize the template after this script"
