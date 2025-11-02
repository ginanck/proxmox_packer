# Install-VirtIO.ps1
# Installs VirtIO Guest Tools and starts QEMU Guest Agent

Write-Host "Installing VirtIO Guest Tools..." -ForegroundColor Green

# Install VirtIO Guest Tools silently
$virtioInstaller = "F:\virtio-win-guest-tools.exe"
if (Test-Path $virtioInstaller) {
    Start-Process -FilePath $virtioInstaller -ArgumentList "/S", "/norestart" -Wait -NoNewWindow
    Write-Host "VirtIO Guest Tools installed successfully" -ForegroundColor Green
} else {
    Write-Host "VirtIO installer not found at $virtioInstaller" -ForegroundColor Red
    exit 1
}

# Wait a few seconds for services to register
Start-Sleep -Seconds 5

# Start QEMU Guest Agent
try {
    Start-Service -Name 'QEMU-GA' -ErrorAction Stop
    Write-Host "QEMU Guest Agent started successfully" -ForegroundColor Green
} catch {
    Write-Host "Warning: Could not start QEMU Guest Agent: $_" -ForegroundColor Yellow
}

# Verify the service is running
$service = Get-Service -Name 'QEMU-GA' -ErrorAction SilentlyContinue
if ($service -and $service.Status -eq 'Running') {
    Write-Host "QEMU Guest Agent is running" -ForegroundColor Green
} else {
    Write-Host "QEMU Guest Agent status: $($service.Status)" -ForegroundColor Yellow
}

Write-Host "VirtIO installation completed!" -ForegroundColor Green
