# Setup-VirtIO.ps1
# Installs VirtIO Guest Tools and starts QEMU Guest Agent
# Runs during Windows installation via AutoUnattend.xml FirstLogonCommands

$LogDir = "C:\Packer"
$Timestamp = Get-Date -Format "yyyy-MM-dd-HH-mm-ss"
$LogFile = Join-Path $LogDir "Setup-VirtIO-$Timestamp.log"

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

Write-Log "=== Starting VirtIO Guest Tools Installation ==="

# ============================================================
# Wait for CD/DVD drives to be ready
# ============================================================
Write-Log "Waiting for drives to be ready..."
Start-Sleep -Seconds 5

# ============================================================
# Detect OS version to determine installer type
# ============================================================
$osInfo = Get-CimInstance -ClassName Win32_OperatingSystem
$osVersion = [System.Version]$osInfo.Version
$osCaption = $osInfo.Caption
Write-Log "Detected OS: $osCaption (Version: $osVersion)"

# Windows Server 2012 R2 = 6.3.x, Windows Server 2012 = 6.2.x
# Windows Server 2016+ and Windows 10/11 use the EXE installer
$useMsiInstaller = $osVersion.Major -eq 6 -and $osVersion.Minor -le 3
if ($useMsiInstaller) {
    Write-Log "OS requires MSI installer (legacy VirtIO installation)"
} else {
    Write-Log "OS supports EXE installer (modern VirtIO installation)"
}

# ============================================================
# Search for VirtIO installer
# ============================================================
Write-Log "Searching for VirtIO installer..."

$installer = $null
$installerType = $null
$maxAttempts = 30
$attempt = 0

do {
    # Get all drive letters
    $drives = Get-PSDrive -PSProvider FileSystem -ErrorAction SilentlyContinue | Where-Object { $_.Root -match '^[A-Z]:\\$' }

    foreach ($drive in $drives) {
        $exePath = Join-Path $drive.Root "virtio-win-guest-tools.exe"
        if (Test-Path $exePath) {
            $installer = $exePath
            $installerType = "EXE"
            $installerDrive = $drive.Root
            Write-Log "Found VirtIO EXE installer at: $installer"
            break
        }
    }

    if (-not $installer) {
        $attempt++
        Write-Log "VirtIO installer not found yet... attempt $attempt of $maxAttempts"
        Start-Sleep -Seconds 2
    }
} while (-not $installer -and $attempt -lt $maxAttempts)

if (-not $installer) {
    Write-LogError "VirtIO installer not found after $maxAttempts attempts"
    Write-Log "Available drives:"
    Get-PSDrive -PSProvider FileSystem | ForEach-Object { Write-Log "  $($_.Root)" }
    exit 1
}

# ============================================================
# Import RedHat.cer into Trusted Publishers (only for Windows Server 2012 R2)
# ============================================================
$is2012R2 = ($osVersion.Major -eq 6 -and $osVersion.Minor -eq 3)

if (-not $is2012R2) {
    Write-Log "Skipping RedHat.cer import: OS is not Windows Server 2012 R2 (Detected: $osCaption, Version: $osVersion)"
} else {
    Write-Log "OS detected as Windows Server 2012 R2; searching for RedHat.cer certificate on available drives..."

    $certPath = $null
    $maxAttempts = 30
    $attempt = 0

    do {
        # Refresh drives in case media was mounted recently
        $drives = Get-PSDrive -PSProvider FileSystem -ErrorAction SilentlyContinue | Where-Object { $_.Root -match '^[A-Z]:\\$' }

        foreach ($drive in $drives) {
            try {
                # Search recursively for the file (take the first match)
                $found = Get-ChildItem -Path $drive.Root -Filter 'RedHat.cer' -Recurse -ErrorAction SilentlyContinue -Force | Select-Object -First 1
                if ($found -and (Test-Path $found.FullName)) {
                    $certPath = $found.FullName
                    Write-Log "Found RedHat.cer at: $certPath"
                    break
                }
            } catch {
                Write-Log "Error while searching drive $($drive.Root): $_"
            }
        }

        if (-not $certPath) {
            $attempt++
            Write-Log "RedHat.cer not found yet... attempt $attempt of $maxAttempts"
            Start-Sleep -Seconds 2
        }
    } while (-not $certPath -and $attempt -lt $maxAttempts)

    if (-not $certPath) {
        Write-LogError "RedHat.cer not found after $maxAttempts attempts"
    } else {
        try {
            # Load cert to compute thumbprint and check if it's already present
            $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($certPath)
            $thumb = $cert.Thumbprint
            $existing = Get-ChildItem -Path Cert:\LocalMachine\TrustedPublisher -ErrorAction SilentlyContinue | Where-Object { $_.Thumbprint -eq $thumb }

            if ($existing) {
                Write-Log "Certificate already present in Trusted Publishers (thumbprint: $thumb)"
            } else {
                $importResult = Import-Certificate -FilePath $certPath -CertStoreLocation 'Cert:\LocalMachine\TrustedPublisher' -ErrorAction Stop
                if ($importResult) {
                    Write-Log "Certificate imported to Trusted Publishers (thumbprint: $($cert.Thumbprint))"
                } else {
                    Write-LogError "Import-Certificate returned no result; verify certificate content and permissions"
                }
            }
        } catch {
            Write-LogError "Failed to import certificate: $_"
        }
    }
}

# ============================================================
# Install VirtIO Guest Tools
# ============================================================
Write-Log "Installing VirtIO Guest Tools (silent mode) - Type: $installerType..."

try {
    if ($installerType -eq "EXE") {
        $process = Start-Process -FilePath $installer -ArgumentList '/S', '/norestart' -Wait -PassThru -ErrorAction Stop
        Write-Log "VirtIO EXE installer exit code: $($process.ExitCode)"
    } else {
        # MSI installer
        $process = Start-Process -FilePath "msiexec.exe" -ArgumentList '/i', "`"$installer`"", '/quiet', '/norestart' -Wait -PassThru -ErrorAction Stop
        Write-Log "VirtIO MSI installer exit code: $($process.ExitCode)"
    }

    if ($process.ExitCode -eq 0) {
        Write-Log "VirtIO Guest Tools installed successfully"
    } elseif ($process.ExitCode -eq 3010) {
        Write-Log "VirtIO Guest Tools installed successfully (reboot required)"
    } else {
        Write-LogError "VirtIO installer returned unexpected exit code: $($process.ExitCode)"
    }
} catch {
    Write-LogError "Failed to run VirtIO installer: $_"
    exit 1
}

# ============================================================
# Wait for QEMU Guest Agent service to register
# ============================================================
Write-Log "Waiting for QEMU Guest Agent service to register..."
$maxAttempts = 30
$attempt = 0
$qemuService = $null

do {
    $qemuService = Get-Service -Name 'QEMU-GA' -ErrorAction SilentlyContinue
    if ($qemuService) {
        Write-Log "QEMU-GA service found (Status: $($qemuService.Status))"
        break
    }
    $attempt++
    Write-Log "QEMU-GA service not registered yet... attempt $attempt of $maxAttempts"
    Start-Sleep -Seconds 2
} while ($attempt -lt $maxAttempts)

if (-not $qemuService) {
    Write-LogError "QEMU-GA service not found after $maxAttempts attempts"
    Write-Log "Available services containing 'QEMU':"
    Get-Service | Where-Object { $_.Name -like '*QEMU*' -or $_.DisplayName -like '*QEMU*' } | ForEach-Object { Write-Log "  $($_.Name) - $($_.DisplayName)" }
    exit 1
}

# ============================================================
# Configure and Start QEMU Guest Agent
# ============================================================
Write-Log "Configuring QEMU Guest Agent for immediate automatic startup..."

# Set service to Automatic (immediate, not delayed)
Set-Service -Name 'QEMU-GA' -StartupType Automatic -ErrorAction SilentlyContinue
# Ensure it's NOT delayed start - remove DelayedAutostart flag if present
$regPath = "HKLM:\SYSTEM\CurrentControlSet\Services\QEMU-GA"
if (Test-Path $regPath) {
    Remove-ItemProperty -Path $regPath -Name "DelayedAutostart" -ErrorAction SilentlyContinue
    Write-Log "Ensured QEMU-GA is set to Automatic (immediate, not delayed)"
}

Write-Log "Starting QEMU Guest Agent..."

try {
    if ($qemuService.Status -ne 'Running') {
        Start-Service -Name 'QEMU-GA' -ErrorAction Stop
        Start-Sleep -Seconds 2
        $qemuService = Get-Service -Name 'QEMU-GA'
    }
    Write-Log "QEMU Guest Agent status: $($qemuService.Status)"
} catch {
    Write-LogError "Failed to start QEMU Guest Agent: $_"
}

# ============================================================
# Verify network adapter (VirtIO NIC)
# ============================================================
Write-Log "Checking for VirtIO network adapter..."
$maxAttempts = 30
$attempt = 0
$netAdapter = $null

do {
    $netAdapter = Get-NetAdapter | Where-Object { $_.Status -eq 'Up' }
    if ($netAdapter) {
        Write-Log "Network adapter found: $($netAdapter.Name) (Status: $($netAdapter.Status))"
        break
    }
    $attempt++
    Write-Log "Waiting for network adapter... attempt $attempt of $maxAttempts"
    Start-Sleep -Seconds 2
} while ($attempt -lt $maxAttempts)

if ($netAdapter) {
    # Wait for IP address
    Write-Log "Waiting for IP address..."
    $attempt = 0
    do {
        $ip = Get-NetIPAddress -InterfaceIndex $netAdapter.InterfaceIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue |
              Where-Object { $_.IPAddress -notlike '169.254.*' }
        if ($ip) {
            Write-Log "IP Address obtained: $($ip.IPAddress)"
            break
        }
        $attempt++
        Start-Sleep -Seconds 2
    } while ($attempt -lt 30)
}

Write-Log "=== VirtIO Guest Tools Installation Completed ==="
