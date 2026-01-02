# ============================================================================
# Install-Chocolatey.ps1
# Works on Windows Desktop and Windows Server
# ============================================================================

# Don't use Stop - we want to handle errors gracefully
$ErrorActionPreference = 'Continue'

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

# Test internet connectivity first
Write-Log "Testing internet connectivity..."
$testUrls = @(
    'https://community.chocolatey.org',
    'https://chocolatey.org',
    'https://www.google.com'
)
$hasInternet = $false
foreach ($url in $testUrls) {
    try {
        $response = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
        if ($response.StatusCode -eq 200) {
            Write-Log "Internet connectivity confirmed via $url"
            $hasInternet = $true
            break
        }
    } catch {
        Write-Log "Cannot reach $url - trying next..."
    }
}

if (-not $hasInternet) {
    Write-LogError "No internet connectivity - skipping Chocolatey installation"
    Write-Log "Chocolatey can be installed manually after deployment"
    exit 0  # Exit gracefully, don't fail the build
}

try {
    Write-Log "Downloading Chocolatey install script..."
    $installScript = (New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1')

    Write-Log "Executing Chocolatey installer..."
    Invoke-Expression $installScript
}
catch {
    Write-LogError "Chocolatey installation failed: $_"
    Write-Log "Continuing without Chocolatey - it can be installed manually later"
    exit 0  # Exit gracefully, don't fail the build
}

# Refresh PATH
$env:Path = [System.Environment]::GetEnvironmentVariable(
    'Path', [System.EnvironmentVariableTarget]::Machine
)

# Verify
if (Get-Command choco -ErrorAction SilentlyContinue) {
    Write-Log "Chocolatey installed successfully: $(choco --version)"
} else {
    Write-LogError "Chocolatey installation verification failed - continuing anyway"
}

Write-Log "=== Chocolatey Installation Complete ==="
