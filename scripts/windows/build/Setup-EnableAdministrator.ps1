# Configure-Administrator.ps1
# Configures the built-in Administrator account for cloud-init integration
# CloudBase-Init will set the password from Terraform cloud-init metadata at clone time
#
# Configuration:
# - Enables Administrator account
# - Sets password to never expire
# - Adds to Remote Desktop Users group
# - Does NOT set password (handled by CloudBase-Init)

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

Write-Log "=== Configuring Built-in Administrator Account ==="

# Enable the Administrator account
Write-Log "Enabling built-in Administrator account..."
net user Administrator /active:yes

if ($LASTEXITCODE -eq 0) {
    Write-Log "Administrator account enabled successfully"
} else {
    Write-Log "ERROR: Failed to enable Administrator account"
}

# DO NOT set password here - let CloudBase-Init handle it from Terraform metadata
# The password will be set via cloud-init user-data when the VM is cloned
Write-Log "NOTE: Administrator password will be set by CloudBase-Init at clone time"
Write-Log "NOTE: Use Terraform cloud-init metadata to specify the password"

# Ensure Administrator account password never expires (for service accounts)
Write-Log "Setting password to never expire..."
net user Administrator /expires:never
wmic useraccount where "name='Administrator'" set PasswordExpires=FALSE 2>&1 | Out-Null

Write-Log "=== Administrator Account Configuration Complete ==="
Write-Log "IMPORTANT: Set password via Terraform cloud-init when deploying from this template"
