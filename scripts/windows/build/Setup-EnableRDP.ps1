# Enables Remote Desktop Protocol (RDP) for remote access

$LogFile = "C:\windows-rdp-setup.log"

function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] $Message"
    Write-Host $logMessage -ForegroundColor Green
    Add-Content -Path $LogFile -Value $logMessage
}

Write-Log "=== Enabling Remote Desktop (RDP) ==="

# Enable Remote Desktop
Write-Log "Enabling Remote Desktop..."
Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -Name "fDenyTSConnections" -Value 0 -Force

# Enable RDP through Windows Firewall
Write-Log "Configuring Windows Firewall for RDP..."
Enable-NetFirewallRule -DisplayGroup "Remote Desktop"

# Allow RDP connections (NLA - Network Level Authentication)
Write-Log "Configuring Network Level Authentication..."
Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp' -Name "UserAuthentication" -Value 1 -Force

# Verify configuration
$rdpEnabled = (Get-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server').fDenyTSConnections
if ($rdpEnabled -eq 0) {
    Write-Log "RDP enabled successfully"
} else {
    Write-Log "ERROR: RDP enable failed"
}

Write-Log "=== RDP Configuration Complete ==="
