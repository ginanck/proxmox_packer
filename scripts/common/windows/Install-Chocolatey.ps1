# ============================================================================
# Install-Chocolatey.ps1
# Works on Windows Desktop and Windows Server
# ============================================================================

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

Write-Host "=== Installing Chocolatey ===" -ForegroundColor Cyan

# Check if already installed
if (Get-Command choco -ErrorAction SilentlyContinue) {
    Write-Host "Chocolatey already installed:" (choco --version)
    exit 0
}

# Ensure TLS 1.2 (important for older Windows / Server)
[Net.ServicePointManager]::SecurityProtocol = `
    [Net.SecurityProtocolType]::Tls12

try {
    Invoke-Expression (
        (New-Object System.Net.WebClient).DownloadString(
            'https://community.chocolatey.org/install.ps1'
        )
    )
}
catch {
    Write-Error "Chocolatey installation failed: $_"
    exit 1
}

# Refresh PATH
$env:Path = [System.Environment]::GetEnvironmentVariable(
    'Path', [System.EnvironmentVariableTarget]::Machine
)

# Verify
if (Get-Command choco -ErrorAction SilentlyContinue) {
    Write-Host "Chocolatey installed successfully:" (choco --version)
} else {
    Write-Error "Chocolatey installation verification failed"
    exit 1
}

Write-Host "=== Chocolatey Installation Complete ===" -ForegroundColor Green
