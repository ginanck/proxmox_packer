# Manage-Security.ps1
# Unified script to disable or enable security features during Packer build
#
# Usage:
#   .\Manage-Security.ps1 -Action Disable  # During initial setup
#   .\Manage-Security.ps1 -Action Enable   # Before Sysprep
#   Set SECURITY_ACTION env var and run without params
#
# When disabled:
# - UAC (User Access Control) - allows unattended installs
# - Windows Update - prevents updates during build
# - High Performance power plan - prevents sleep during build
#
# When enabled:
# - UAC (User Access Control)
# - Windows Defender
# - Windows Update

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet("Disable", "Enable")]
    [string]$Action
)

# Support environment variable for Action
if (-not $Action -and $env:SECURITY_ACTION) {
    $Action = $env:SECURITY_ACTION
}

if (-not $Action) {
    Write-Error "Action parameter is required. Use -Action Disable or -Action Enable, or set SECURITY_ACTION environment variable."
    exit 1
}

# Setup logging
$LogDir = "C:\Packer"
$Timestamp = Get-Date -Format "yyyy-MM-dd-HH-mm-ss"
$LogFile = Join-Path $LogDir "Build-ManageSecurity-$Timestamp.log"

if (-not (Test-Path $LogDir)) {
    New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
}

function Write-Log {
    param([string]$Message)
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$ts] $Message"
    Write-Host $logMessage -ForegroundColor Green
    Add-Content -Path $LogFile -Value $logMessage
}

function Write-LogError {
    param([string]$Message)
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$ts] ERROR: $Message"
    Write-Host $logMessage -ForegroundColor Red
    Add-Content -Path $LogFile -Value $logMessage
}

Write-Log "=== Security Management Script - Action: $Action ==="

if ($Action -eq "Disable") {
    # ============================================================================
    # DISABLE MODE - Optimize for build process
    # ============================================================================

    # Disable User Access Control (UAC)
    Write-Log "Disabling User Access Control (UAC)..."
    try {
        $uacPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"
        Set-ItemProperty -Path $uacPath -Name "EnableLUA" -Value 0 -Type DWord -Force

        $currentValue = (Get-ItemProperty -Path $uacPath).EnableLUA
        if ($currentValue -eq 0) {
            Write-Log "UAC disabled successfully (EnableLUA = 0)"
        } else {
            Write-LogError "UAC disable failed (EnableLUA = $currentValue)"
        }
    } catch {
        Write-LogError "Failed to disable UAC: $_"
    }

    # Disable Windows Defender
    Write-Log "Disabling Windows Defender for build performance..."
    try {
        $defenderPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender"

        if (-not (Test-Path $defenderPath)) {
            New-Item -Path $defenderPath -Force | Out-Null
            Write-Log "Created Windows Defender policy registry path"
        }

        Set-ItemProperty -Path $defenderPath -Name "DisableAntiSpyware" -Value 1 -Type DWord -Force

        $currentValue = (Get-ItemProperty -Path $defenderPath -ErrorAction SilentlyContinue).DisableAntiSpyware
        if ($currentValue -eq 1) {
            Write-Log "Windows Defender disabled successfully (DisableAntiSpyware = 1)"
        } else {
            Write-LogError "Windows Defender disable failed (DisableAntiSpyware = $currentValue)"
        }
    } catch {
        Write-LogError "Failed to disable Windows Defender: $_"
    }

    # Disable Windows Update
    Write-Log "Disabling Windows Update automatic updates..."
    try {
        $wuPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"

        if (-not (Test-Path $wuPath)) {
            New-Item -Path $wuPath -Force | Out-Null
            Write-Log "Created Windows Update registry path"
        }

        Set-ItemProperty -Path $wuPath -Name "NoAutoUpdate" -Value 1 -Type DWord -Force

        $currentValue = (Get-ItemProperty -Path $wuPath).NoAutoUpdate
        if ($currentValue -eq 1) {
            Write-Log "Windows Update disabled successfully (NoAutoUpdate = 1)"
        } else {
            Write-LogError "Windows Update disable failed (NoAutoUpdate = $currentValue)"
        }
    } catch {
        Write-LogError "Failed to disable Windows Update: $_"
    }

    # Configure Power Settings
    Write-Log "Configuring power settings..."

    # Set High Performance power plan
    try {
        $highPerfGuid = "8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c"

        $plans = powercfg /list
        if ($plans -match $highPerfGuid) {
            $result = powercfg /setactive $highPerfGuid

            $activePlan = powercfg /getactivescheme
            if ($activePlan -match $highPerfGuid) {
                Write-Log "Power plan set to High Performance"
            } else {
                Write-LogError "Failed to set High Performance power plan"
            }
        } else {
            Write-LogError "High Performance power plan not found on this system"
        }
    } catch {
        Write-LogError "Failed to set power plan: $_"
    }

    # Disable hibernation to save disk space
    try {
        $result = powercfg /hibernate off

        $hiberfil = Test-Path "C:\hiberfil.sys"
        if (-not $hiberfil) {
            Write-Log "Hibernation disabled successfully (hiberfil.sys removed)"
        } else {
            Write-Log "Hibernation command executed (hiberfil.sys may be removed on next boot)"
        }
    } catch {
        Write-LogError "Failed to disable hibernation: $_"
    }

    # Verification Summary
    Write-Log "=== Disable Mode Configuration Summary ==="

    $uacStatus = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System").EnableLUA
    Write-Log "UAC Status: $(if ($uacStatus -eq 0) { 'Disabled' } else { 'Enabled' })"

    $wuStatus = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" -ErrorAction SilentlyContinue).NoAutoUpdate
    Write-Log "Windows Update: $(if ($wuStatus -eq 1) { 'Disabled' } else { 'Enabled or Not Configured' })"

    $activePowerPlan = (powercfg /getactivescheme) -replace '.*GUID: ([0-9a-f\-]+).*', '$1'
    Write-Log "Active Power Plan GUID: $activePowerPlan"

    $hibernationEnabled = Test-Path "C:\hiberfil.sys"
    Write-Log "Hibernation: $(if ($hibernationEnabled) { 'Enabled' } else { 'Disabled' })"

    Write-Log "=== Security Disable Completed ==="

} elseif ($Action -eq "Enable") {
    # ============================================================================
    # ENABLE MODE - Restore security for production template
    # ============================================================================

    # Re-enable User Access Control (UAC)
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

    # Re-enable Windows Defender
    Write-Log "Re-enabling Windows Defender..."

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
        $defenderService = Get-Service -Name "WinDefend" -ErrorAction SilentlyContinue
        if ($defenderService) {
            Set-Service -Name "WinDefend" -StartupType Automatic -ErrorAction SilentlyContinue
            Write-Log "WinDefend service set to Automatic"
        }

        $securityCenter = Get-Service -Name "wscsvc" -ErrorAction SilentlyContinue
        if ($securityCenter) {
            Set-Service -Name "wscsvc" -StartupType Automatic -ErrorAction SilentlyContinue
            Start-Service -Name "wscsvc" -ErrorAction SilentlyContinue
            Write-Log "Security Center service enabled and started"
        }
    } catch {
        Write-LogError "Failed to configure Defender services: $_"
    }

    # Enable Windows Defender real-time protection
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

    # Re-enable Windows Update
    Write-Log "Restoring Windows Update settings..."
    try {
        $wuPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"

        if (Test-Path $wuPath) {
            $noAutoUpdate = Get-ItemProperty -Path $wuPath -Name "NoAutoUpdate" -ErrorAction SilentlyContinue
            if ($null -ne $noAutoUpdate) {
                Remove-ItemProperty -Path $wuPath -Name "NoAutoUpdate" -Force -ErrorAction Stop
                Write-Log "Removed NoAutoUpdate policy - Windows Update restored to defaults"
            }
        }
    } catch {
        Write-LogError "Failed to restore Windows Update settings: $_"
    }

    # Verification Summary
    Write-Log "=== Enable Mode Verification Summary ==="

    $uacStatus = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System").EnableLUA
    Write-Log "UAC Status: $(if ($uacStatus -eq 1) { 'Enabled' } else { 'Disabled' })"

    $defenderPolicy = Get-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender" -Name "DisableAntiSpyware" -ErrorAction SilentlyContinue
    Write-Log "Defender Policy: $(if ($null -eq $defenderPolicy) { 'No restrictions (Enabled)' } else { 'Policy exists - may be disabled' })"

    $defenderSvc = Get-Service -Name "WinDefend" -ErrorAction SilentlyContinue
    if ($defenderSvc) {
        Write-Log "Defender Service: $($defenderSvc.Status) (StartType: $($defenderSvc.StartType))"
    }

    Write-Log "=== Security Enable Completed ==="
    Write-Log "NOTE: Some changes may require a reboot to take full effect"
    Write-Log "NOTE: Sysprep will finalize the template after this script"
}
