# Disable-SecurityForBuild.ps1
# Disables security features during Packer build for faster provisioning
# These settings are restored by Enable-SecurityAfterBuild.ps1 before Sysprep
#
# Disabled during build:
# - UAC (User Access Control) - allows unattended installs
# - Windows Update - prevents updates during build
#
# Enabled during build:
# - RDP (Remote Desktop) - for remote access
# - High Performance power plan - prevents sleep during build

$LogFile = "C:\windows-optimization.log"

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

Write-Log "=== Starting Windows Optimizations ==="

# ============================================================================
# 1. DISABLE USER ACCESS CONTROL (UAC)
# ============================================================================
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

# ============================================================================
# 2. ENABLE REMOTE DESKTOP (RDP)
# ============================================================================
Write-Log "Enabling Remote Desktop Protocol (RDP)..."

# Enable RDP in registry
try {
    $rdpPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server"
    Set-ItemProperty -Path $rdpPath -Name "fDenyTSConnections" -Value 0 -Type DWord -Force

    $rdpEnabled = (Get-ItemProperty -Path $rdpPath).fDenyTSConnections
    if ($rdpEnabled -eq 0) {
        Write-Log "RDP enabled in registry (fDenyTSConnections = 0)"
    } else {
        Write-LogError "RDP enable failed (fDenyTSConnections = $rdpEnabled)"
    }
} catch {
    Write-LogError "Failed to enable RDP: $_"
}

# Configure RDP firewall rules
Write-Log "Enabling RDP firewall rules..."
try {
    # Enable the built-in Remote Desktop firewall rule group
    Enable-NetFirewallRule -DisplayGroup "Remote Desktop" -ErrorAction SilentlyContinue

    # Also use netsh as a fallback for compatibility
    $result = netsh advfirewall firewall set rule group="remote desktop" new enable=yes 2>&1

    # Verify firewall rules are enabled
    $rdpRules = Get-NetFirewallRule -DisplayGroup "Remote Desktop" -ErrorAction SilentlyContinue
    $enabledCount = ($rdpRules | Where-Object { $_.Enabled -eq $true }).Count
    Write-Log "RDP firewall rules enabled: $enabledCount rule(s)"

} catch {
    Write-LogError "Failed to enable RDP firewall rules: $_"
}

# ============================================================================
# 3. DISABLE WINDOWS UPDATE
# ============================================================================
Write-Log "Disabling Windows Update automatic updates..."
try {
    $wuPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"

    # Create the key path if it doesn't exist
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

# ============================================================================
# 4. CONFIGURE POWER SETTINGS
# ============================================================================
Write-Log "Configuring power settings..."

# Set High Performance power plan
try {
    $highPerfGuid = "8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c"

    # Check if High Performance plan exists
    $plans = powercfg /list
    if ($plans -match $highPerfGuid) {
        $result = powercfg /setactive $highPerfGuid

        # Verify active plan
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

    # Verify hibernation is disabled
    $hiberfil = Test-Path "C:\hiberfil.sys"
    if (-not $hiberfil) {
        Write-Log "Hibernation disabled successfully (hiberfil.sys removed)"
    } else {
        Write-Log "Hibernation command executed (hiberfil.sys may be removed on next boot)"
    }
} catch {
    Write-LogError "Failed to disable hibernation: $_"
}

# ============================================================================
# 5. VERIFICATION SUMMARY
# ============================================================================
Write-Log "=== Configuration Summary ==="

# UAC Status
$uacStatus = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System").EnableLUA
Write-Log "UAC Status: $(if ($uacStatus -eq 0) { 'Disabled' } else { 'Enabled' })"

# RDP Status
$rdpStatus = (Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server").fDenyTSConnections
Write-Log "RDP Status: $(if ($rdpStatus -eq 0) { 'Enabled' } else { 'Disabled' })"

# Windows Update Status
$wuStatus = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" -ErrorAction SilentlyContinue).NoAutoUpdate
Write-Log "Windows Update: $(if ($wuStatus -eq 1) { 'Disabled' } else { 'Enabled or Not Configured' })"

# Power Plan
$activePowerPlan = (powercfg /getactivescheme) -replace '.*GUID: ([0-9a-f\-]+).*', '$1'
Write-Log "Active Power Plan GUID: $activePowerPlan"

# Hibernation
$hibernationEnabled = Test-Path "C:\hiberfil.sys"
Write-Log "Hibernation: $(if ($hibernationEnabled) { 'Enabled' } else { 'Disabled' })"

Write-Log "=== Windows Optimizations Completed ==="
