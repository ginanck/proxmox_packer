# ============================================================================
# Install-Chocolatey.ps1
# Works on Windows Desktop and Windows Server
# ============================================================================

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# Setup logging
$LogDir = "C:\Packer"
$Timestamp = Get-Date -Format "yyyy-MM-dd-HH-mm-ss"
$LogFile = Join-Path $LogDir "Build-InstallChocolatey-$Timestamp.log"

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

Write-Log "=== Installing Chocolatey ==="

# Check if already installed
if (Get-Command choco -ErrorAction SilentlyContinue) {
    Write-Log "Chocolatey already installed: $(choco --version)"
    exit 0
}

# Ensure TLS 1.2 (important for older Windows / Server)
Write-Log "Configuring TLS 1.2..."
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

try {
    Write-Log "Downloading and installing Chocolatey..."
    Invoke-Expression (
        (New-Object System.Net.WebClient).DownloadString(
            'https://community.chocolatey.org/install.ps1'
        )
    )
}
catch {
    Write-LogError "Chocolatey installation failed: $_"
    exit 1
}

# Refresh PATH
$env:Path = [System.Environment]::GetEnvironmentVariable(
    'Path', [System.EnvironmentVariableTarget]::Machine
)

# Verify
if (Get-Command choco -ErrorAction SilentlyContinue) {
    Write-Log "Chocolatey installed successfully: $(choco --version)"
} else {
    Write-LogError "Chocolatey installation verification failed"
    exit 1
}

Write-Log "=== Chocolatey Installation Complete ==="
