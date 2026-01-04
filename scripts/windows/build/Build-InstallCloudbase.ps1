$ErrorActionPreference = "Stop"

# Setup logging
$LogDir = "C:\Packer"
$Timestamp = Get-Date -Format "yyyy-MM-dd-HH-mm-ss"
$LogFile = Join-Path $LogDir "Build-InstallCloudbase-$Timestamp.log"

$MsiLog = Join-Path $LogDir "Build-InstallCloudbase-MSI-$Timestamp.log"
# Installer and URL will be assigned based on detected OS later
$Installer = $null
$Url = $null

$InstallDir = "C:\Program Files\Cloudbase Solutions\Cloudbase-Init"
$ConfDir = Join-Path $InstallDir "conf"

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

function Get-DriveByLabel {
    param([Parameter(Mandatory=$true)][string]$Label)

    # Works on 2012+ (Get-Volume is available on 2012+)
    $vol = Get-Volume -ErrorAction SilentlyContinue | Where-Object { $_.FileSystemLabel -eq $Label } | Select-Object -First 1
    if ($vol -and $vol.DriveLetter) { return "$($vol.DriveLetter):\" }

    # Fallback (rare)
    $wmi = Get-WmiObject Win32_Volume -ErrorAction SilentlyContinue | Where-Object { $_.Label -eq $Label } | Select-Object -First 1
    if ($wmi -and $wmi.DriveLetter) { return "$($wmi.DriveLetter)\" }

    return $null
}

# TLS (2012 R2 safe)
try {
    [Net.ServicePointManager]::SecurityProtocol =
        [Net.SecurityProtocolType]::Tls12 -bor
        [Net.SecurityProtocolType]::Tls11 -bor
        [Net.SecurityProtocolType]::Tls
} catch {
    [Net.ServicePointManager]::SecurityProtocol = 3072
}

# Choose MSI based on OS: 2012 R2 -> 1.1.2 (max), 2016 -> 1.1.4, others -> latest
$psMajor = $PSVersionTable.PSVersion.Major

if ($psMajor -lt 5) {
    $os = Get-WmiObject Win32_OperatingSystem
} else {
    $os = Get-CimInstance Win32_OperatingSystem
}
$caption = $os.Caption

switch -Wildcard ($caption) {
    '*2012 R2*' {
        $cloudbaseVersion = '1.1.2'
        $Installer = "C:\CloudbaseInitSetup_1_1_2_x64.msi"
        $Url = "https://github.com/cloudbase/cloudbase-init/releases/download/1.1.2/CloudbaseInitSetup_1_1_2_x64.msi"
        Write-Log "Detected Windows Server 2012 R2 - using Cloudbase-Init $cloudbaseVersion (max supported)"
        break
    }
    '*2016*' {
        $cloudbaseVersion = '1.1.4'
        $Installer = "C:\CloudbaseInitSetup_1_1_4_x64.msi"
        $Url = "https://github.com/cloudbase/cloudbase-init/releases/download/1.1.4/CloudbaseInitSetup_1_1_4_x64.msi"
        Write-Log "Detected Windows Server 2016 - using Cloudbase-Init $cloudbaseVersion"
        break
    }
    default {
        $cloudbaseVersion = '1.1.6'
        $Installer = "C:\CloudbaseInitSetup_1_1_6_x64.msi"
        $Url = "https://github.com/cloudbase/cloudbase-init/releases/download/1.1.6/CloudbaseInitSetup_1_1_6_x64.msi"
        Write-Log "Detected OS '$caption' - defaulting to Cloudbase-Init $cloudbaseVersion"
        break
    }
}
$env:cloudbaseInitVersion = $cloudbaseVersion

Write-Output "Detected OS: $caption"
Write-Output "PowerShell version: $($PSVersionTable.PSVersion.ToString())"
Write-Output "Using CloudBase-Init version: $env:cloudbaseInitVersion"

Write-Log "=== Starting Cloudbase-Init Installation ==="

try {
    # Ensure Windows Installer service is up
    Write-Log "Ensuring Windows Installer service is running"
    Start-Service msiserver -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 10

    # Download
    Write-Log "Downloading Cloudbase-Init from $Url"
    Invoke-WebRequest -Uri $Url -OutFile $Installer -UseBasicParsing
    if (-not (Test-Path $Installer)) { throw "Cloudbase-Init installer download failed" }

    # Pre-create dirs (prevents some MSI edge failures)
    New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
    New-Item -ItemType Directory -Path $ConfDir -Force | Out-Null

    # Install: use /qb! not /qn (important for MSI custom actions)
    Write-Log "Installing Cloudbase-Init..."
    $args = @(
        "/i", "`"$Installer`"",
        "/qb!",
        "REBOOT=ReallySuppress",
        "RUN_SERVICE=0",
        "/l*v", "`"$MsiLog`""
    )

    $proc = Start-Process msiexec.exe -ArgumentList $args -Wait -PassThru
    if ($proc.ExitCode -ne 0) {
        throw "Installer failed with exit code $($proc.ExitCode). See $MsiLog"
    }

    Start-Sleep -Seconds 10

    # Find your attached ISO by label, not by letter
    $unattendDrive = Get-DriveByLabel -Label "UNATTEND"
    if (-not $unattendDrive) { throw "Could not find UNATTEND ISO by volume label" }

    # Copy configs from ISO content
    $srcConf  = Join-Path $unattendDrive "cloudbase-init.conf"
    $srcUnatt = Join-Path $unattendDrive "cloudbase-init-unattend.conf"

    if (Test-Path $srcConf)  { Copy-Item $srcConf  (Join-Path $ConfDir "cloudbase-init.conf") -Force; Write-Log "Copied cloudbase-init.conf" }
    if (Test-Path $srcUnatt) { Copy-Item $srcUnatt (Join-Path $ConfDir "cloudbase-init-unattend.conf") -Force; Write-Log "Copied cloudbase-init-unattend.conf" }

    # Configure service to start on first boot after sysprep (NOT during build)
    Write-Log "Configuring Cloudbase-Init service for immediate automatic startup"
    Set-Service cloudbase-init -StartupType Automatic

    # Ensure it's NOT delayed start - remove DelayedAutostart flag if present
    $regPath = "HKLM:\SYSTEM\CurrentControlSet\Services\cloudbase-init"
    if (Test-Path $regPath) {
        Remove-ItemProperty -Path $regPath -Name "DelayedAutostart" -ErrorAction SilentlyContinue
        Write-Log "Ensured cloudbase-init is set to Automatic (immediate, not delayed)"
    }

    # Do NOT start the service now - it will run after sysprep on first boot
    Write-Log "NOTE: Cloudbase-Init service will start automatically on first boot after sysprep"

    $svc = Get-Service cloudbase-init -ErrorAction SilentlyContinue
    if (-not $svc) { throw "Cloudbase-Init service not found after install" }

    Remove-Item $Installer -Force -ErrorAction SilentlyContinue
    Write-Log "=== Cloudbase-Init installation completed successfully ==="
}
catch {
    Write-LogError $_.Exception.Message
    if (Test-Path $MsiLog) { Write-LogError "MSI log: $MsiLog" }
    exit 1
}
