# Configure-WinRM.ps1
# Configures WinRM for Packer provisioning with proper error handling

# Setup logging
$LogDir = "C:\Packer"
$Timestamp = Get-Date -Format "yyyy-MM-dd-HH-mm-ss"
$LogFile = Join-Path $LogDir "Setup-EnableAdministrator-$Timestamp.log"

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

Write-Log "=== Starting WinRM Configuration ==="

# ============================================================
# Wait for QEMU Guest Agent to be running
# ============================================================
Write-Log "Checking for QEMU Guest Agent..."
$maxAttempts = 60
$attempt = 0
$qemuRunning = $false

do {
    $qemuSvc = Get-Service -Name 'QEMU-GA' -ErrorAction SilentlyContinue
    if ($qemuSvc) {
        if ($qemuSvc.Status -eq 'Running') {
            Write-Log "QEMU Guest Agent is running"
            $qemuRunning = $true
            break
        } else {
            Write-Log "QEMU-GA found but not running (Status: $($qemuSvc.Status)), attempting to start..."
            Start-Service -Name 'QEMU-GA' -ErrorAction SilentlyContinue
        }
    } else {
        Write-Log "QEMU-GA service not found yet... attempt $attempt of $maxAttempts"
    }
    $attempt++
    Start-Sleep -Seconds 2
} while ($attempt -lt $maxAttempts)

if (-not $qemuRunning) {
    Write-LogError "QEMU Guest Agent not running after $maxAttempts attempts, continuing anyway..."
}

# ============================================================
# Wait for network adapter to be ready
# ============================================================
Write-Log "Waiting for network adapter..."
$maxAttempts = 30
$attempt = 0
do {
    $adapter = Get-NetAdapter | Where-Object { $_.Status -eq 'Up' }
    if ($adapter) {
        Write-Log "Network adapter found: $($adapter.Name)"
        break
    }
    $attempt++
    Write-Log "Waiting for network adapter... attempt $attempt of $maxAttempts"
    Start-Sleep -Seconds 2
} while ($attempt -lt $maxAttempts)

if (-not $adapter) {
    Write-LogError "No network adapter found after $maxAttempts attempts"
    exit 1
}

# Wait for network connection profile to exist
Write-Log "Waiting for network connection profile..."
$attempt = 0
do {
    $profile = Get-NetConnectionProfile -ErrorAction SilentlyContinue
    if ($profile) {
        Write-Log "Network profile found: $($profile.Name) - Category: $($profile.NetworkCategory)"
        break
    }
    $attempt++
    Write-Log "Waiting for network profile... attempt $attempt of $maxAttempts"
    Start-Sleep -Seconds 2
} while ($attempt -lt $maxAttempts)

# Set Network to Private (required for WinRM)
Write-Log "Setting network profile to Private..."
try {
    Get-NetConnectionProfile | Set-NetConnectionProfile -NetworkCategory Private -ErrorAction Stop
    Write-Log "Network profile set to Private successfully"
} catch {
    Write-LogError "Failed to set network profile: $_"
    # Continue anyway - we'll try to force WinRM config
}

# Verify network profile
$currentProfile = Get-NetConnectionProfile
Write-Log "Current network profile: $($currentProfile.NetworkCategory)"

# Enable PS Remoting
Write-Log "Enabling PowerShell Remoting..."
try {
    Enable-PSRemoting -Force -SkipNetworkProfileCheck -ErrorAction Stop
    Write-Log "PowerShell Remoting enabled"
} catch {
    Write-LogError "Failed to enable PS Remoting: $_"
}

# Configure WinRM service
Write-Log "Configuring WinRM service..."

# Set WinRM to start automatically
Set-Service -Name WinRM -StartupType Automatic
Start-Service -Name WinRM -ErrorAction SilentlyContinue

# Delete existing listeners and create new one
Write-Log "Configuring WinRM listener..."
try {
    # Remove existing HTTP listeners
    $listeners = Get-ChildItem WSMan:\localhost\Listener -ErrorAction SilentlyContinue
    foreach ($listener in $listeners) {
        $transport = ($listener | Get-ChildItem | Where-Object { $_.Name -eq 'Transport' }).Value
        if ($transport -eq 'HTTP') {
            Write-Log "Removing existing HTTP listener"
            Remove-Item -Path "WSMan:\localhost\Listener\$($listener.Name)" -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    # Create new HTTP listener
    New-Item -Path WSMan:\localhost\Listener -Transport HTTP -Address * -Force -ErrorAction Stop
    Write-Log "HTTP listener created"
} catch {
    Write-LogError "Failed to create listener: $_"
    # Try winrm command as fallback
    winrm create winrm/config/Listener?Address=*+Transport=HTTP 2>&1 | Out-Null
}

# Configure WinRM settings using PowerShell's native WSMan provider
Write-Log "Setting WinRM authentication and service options..."

try {
    # Service Auth settings
    Set-Item -Path WSMan:\localhost\Service\Auth\Basic -Value $true -Force
    Write-Log "Set Basic auth = true"

    Set-Item -Path WSMan:\localhost\Service\AllowUnencrypted -Value $true -Force
    Write-Log "Set AllowUnencrypted = true"

    # WinRS settings
    Set-Item -Path WSMan:\localhost\Shell\MaxMemoryPerShellMB -Value 2048 -Force
    Write-Log "Set MaxMemoryPerShellMB = 2048"

    # Client Auth settings
    Set-Item -Path WSMan:\localhost\Client\Auth\Basic -Value $true -Force
    Write-Log "Set Client Basic auth = true"

    Set-Item -Path WSMan:\localhost\Client\AllowUnencrypted -Value $true -Force
    Write-Log "Set Client AllowUnencrypted = true"

} catch {
    Write-LogError "Failed to set WSMan config: $_"
}

# Enable remote access for local accounts (UAC remote restrictions)
Write-Log "Enabling remote access for local accounts..."
$regPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"
Set-ItemProperty -Path $regPath -Name "LocalAccountTokenFilterPolicy" -Value 1 -Type DWord -Force

# Configure Windows Firewall for WinRM
Write-Log "Configuring firewall rules..."

# Enable WinRM firewall rules
try {
    # Enable existing WinRM rules
    Get-NetFirewallRule -DisplayGroup "Windows Remote Management" -ErrorAction SilentlyContinue |
        Set-NetFirewallRule -Enabled True -ErrorAction SilentlyContinue
    Write-Log "Enabled Windows Remote Management firewall rules"
} catch {
    Write-LogError "Failed to enable firewall rules via PowerShell: $_"
}

# Also try netsh as fallback for all profiles
netsh advfirewall firewall set rule group="Windows Remote Management" new enable=yes 2>&1 | Out-Null
netsh advfirewall firewall add rule name="WinRM-HTTP" dir=in localport=5985 protocol=tcp action=allow 2>&1 | Out-Null
Write-Log "Firewall rules configured via netsh"

# Restart WinRM service
Write-Log "Restarting WinRM service..."
Restart-Service WinRM -Force

# Wait for service to be ready
Start-Sleep -Seconds 3

# Verify configuration
Write-Log "=== Verifying WinRM Configuration ==="

$service = Get-Service WinRM
Write-Log "WinRM Service Status: $($service.Status)"

$listeners = winrm enumerate winrm/config/listener 2>&1
Write-Log "WinRM Listeners: $listeners"

$authConfig = winrm get winrm/config/service/auth 2>&1
Write-Log "WinRM Auth Config: $authConfig"

# Test local WinRM connection
Write-Log "Testing local WinRM connection..."
try {
    $testResult = Test-WSMan -ComputerName localhost -ErrorAction Stop
    Write-Log "Local WinRM test successful: $($testResult.ProductVersion)"
} catch {
    Write-LogError "Local WinRM test failed: $_"
}

Write-Log "=== WinRM Configuration Completed ==="
