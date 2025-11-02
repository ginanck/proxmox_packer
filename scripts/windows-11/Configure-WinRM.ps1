# Configures WinRM for Packer provisioning

Write-Host "Configuring WinRM..." -ForegroundColor Green

# Enable PS Remoting
Enable-PSRemoting -Force

# Set Network to Private
Set-NetConnectionProfile -NetworkCategory Private

# Configure WinRM
winrm quickconfig -q
winrm set winrm/config/service/auth '@{Basic="true"}'
winrm set winrm/config/service '@{AllowUnencrypted="true"}'
winrm set winrm/config/winrs '@{MaxMemoryPerShellMB="2048"}'
winrm set winrm/config/client/auth '@{Basic="true"}'
winrm set winrm/config/client '@{AllowUnencrypted="true"}'

# Enable remote access for local accounts
reg add HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System /v LocalAccountTokenFilterPolicy /t REG_DWORD /d 1 /f

# Configure firewall
netsh advfirewall firewall set rule name="Windows Remote Management (HTTP-In)" new action=allow remoteip=any

# Restart WinRM
Stop-Service winrm
Start-Service winrm

Write-Host "WinRM configuration completed!" -ForegroundColor Green
