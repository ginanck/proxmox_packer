# Configure-WinRM.ps1
# Runs during Windows installation via AutoUnattend.xml FirstLogonCommands
# Configures WinRM for Packer remote connection (HTTP, insecure, unrestricted)

$ErrorActionPreference = "Continue"

Write-Host "=== Configuring WinRM for Packer Build Access ===" -ForegroundColor Cyan

# Enable PowerShell Remoting
Write-Host "Enabling PowerShell Remoting..."
Enable-PSRemoting -Force -SkipNetworkProfileCheck

# Configure WinRM Service
Write-Host "Configuring WinRM service..."
winrm quickconfig -q -force

# Allow unencrypted traffic (HTTP on port 5985)
Write-Host "Enabling unencrypted HTTP traffic..."
winrm set winrm/config/service '@{AllowUnencrypted="true"}'
winrm set winrm/config/client '@{AllowUnencrypted="true"}'

# Enable Basic authentication
Write-Host "Enabling Basic authentication..."
winrm set winrm/config/service/auth '@{Basic="true"}'
winrm set winrm/config/client/auth '@{Basic="true"}'

# Disable credential requirements (allow connections from any IP)
Write-Host "Removing IP restrictions..."
winrm set winrm/config/client '@{TrustedHosts="*"}'

# Configure service settings
Write-Host "Configuring service limits..."
winrm set winrm/config/winrs '@{MaxMemoryPerShellMB="1024"}'
winrm set winrm/config/winrs '@{MaxShellsPerUser="50"}'

# Configure firewall rule for WinRM HTTP
Write-Host "Configuring firewall for WinRM HTTP (port 5985)..."
netsh advfirewall firewall set rule name="Windows Remote Management (HTTP-In)" new action=allow profile=any remoteip=any
netsh advfirewall firewall add rule name="WinRM HTTP" dir=in action=allow protocol=TCP localport=5985 profile=any remoteip=any

# Set WinRM service to start automatically
Write-Host "Setting WinRM service to automatic startup..."
Set-Service -Name WinRM -StartupType Automatic

# Restart WinRM service to apply all settings
Write-Host "Restarting WinRM service..."
Restart-Service -Name WinRM -Force

# Verify WinRM is running
$winrmStatus = Get-Service -Name WinRM
Write-Host "WinRM Service Status: $($winrmStatus.Status)" -ForegroundColor Green

# Display WinRM configuration
Write-Host "`n=== WinRM Configuration Summary ===" -ForegroundColor Cyan
winrm get winrm/config/service
winrm get winrm/config/client

Write-Host "`n=== WinRM Configuration Complete ===" -ForegroundColor Green
