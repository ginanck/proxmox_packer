# ============================================================================
# Build-InstallChocolatey.ps1 (simplified)
# This minimal installer sets $env:chocolateyVersion according to a compatibility
# matrix and then executes the official one-liner to install Chocolatey.
# ============================================================================

# Fail fast on unexpected errors
$ErrorActionPreference = 'Stop'

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

Write-Output "=== Installing Chocolatey (minimal) ==="

# If already installed, exit successfully
if (Get-Command choco -ErrorAction SilentlyContinue) {
    Write-Output "Chocolatey already installed: $(choco --version)"
    exit 0
}

# Determine OS caption and PowerShell version
$psMajor = $PSVersionTable.PSVersion.Major

if ($psMajor -lt 5) {
    $os = Get-WmiObject Win32_OperatingSystem
} else {
    $os = Get-CimInstance Win32_OperatingSystem
}
$caption = $os.Caption

# Compatibility matrix -> set specific Chocolatey version
switch -Wildcard ($caption) {
    '*2012 R2*' { $env:chocolateyVersion = '0.10.15'; break }
    '*2016*'    { $env:chocolateyVersion = '1.4.0'; break }
    '*2019*'    { $env:chocolateyVersion = '2.6.0'; break }
    '*2022*'    { $env:chocolateyVersion = '2.6.0'; break }
    '*Windows 10*' { $env:chocolateyVersion = '2.6.0'; break }
    '*Windows 11*' { $env:chocolateyVersion = '2.6.0'; break }
    default {
        $env:chocolateyVersion = '2.6.0'; Write-Warning "Unknown OS '$caption' - defaulting Chocolatey version to $env:chocolateyVersion"
    }
}

Write-Output "Detected OS: $caption"
Write-Output "PowerShell version: $($PSVersionTable.PSVersion.ToString())"
Write-Output "Using Chocolatey version: $env:chocolateyVersion"

# Build installer command
if ($psMajor -ge 6) {
    $installerCmd = 'Set-ExecutionPolicy Bypass -Scope Process -Force; iwr https://community.chocolatey.org/install.ps1 | iex'
} else {
    $installerCmd = 'Set-ExecutionPolicy Bypass -Scope Process -Force; iwr https://community.chocolatey.org/install.ps1 -UseBasicParsing | iex'
}

try {
    Write-Output "Running official Chocolatey installer..."
    [Net.ServicePointManager]::SecurityProtocol = `
        [Net.SecurityProtocolType]::Tls12 `
        -bor [Net.SecurityProtocolType]::Tls11 `
        -bor [Net.SecurityProtocolType]::Tls

    $env:chocolateyUseWindowsCompression = 'true' # Recommended for 2012 R2
    Invoke-Expression $installerCmd
} catch {
    Write-Output "Chocolatey installer failed: $_"
    exit 1
}

# Verify installation
if (Get-Command choco -ErrorAction SilentlyContinue) {
    Write-Output "Chocolatey installed: $(choco --version)"
    exit 0
} else {
    Write-Output "Chocolatey not detected after installer"
    exit 1
}
