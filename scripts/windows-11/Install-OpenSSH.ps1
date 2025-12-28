# ===============================
# Install & Configure OpenSSH
# ===============================

$LogFile = "C:\openssh-install.log"
$ErrorActionPreference = "Stop"

function Log {
    param($Msg)
    $line = "[{0}] {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $Msg
    Write-Host $line
    Add-Content $LogFile $line
}

function Is-Admin {
    ([Security.Principal.WindowsPrincipal] `
        [Security.Principal.WindowsIdentity]::GetCurrent()
    ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Is-Admin)) {
    Log "ERROR: Script must be run as Administrator"
    exit 1
}

Log "Starting OpenSSH installation"

# -------------------------------
# Install OpenSSH
# -------------------------------
$server = Get-WindowsCapability -Online | Where-Object Name -like "OpenSSH.Server*"
if ($server.State -ne "Installed") {
    Log "Installing OpenSSH Server"
    Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0
}

$client = Get-WindowsCapability -Online | Where-Object Name -like "OpenSSH.Client*"
if ($client.State -ne "Installed") {
    Log "Installing OpenSSH Client"
    Add-WindowsCapability -Online -Name OpenSSH.Client~~~~0.0.1.0
}

# -------------------------------
# Services
# -------------------------------
Log "Configuring services"
Set-Service sshd -StartupType Automatic
Start-Service sshd

Set-Service ssh-agent -StartupType Automatic
Start-Service ssh-agent

# -------------------------------
# Firewall
# -------------------------------
if (-not (Get-NetFirewallRule -Name "OpenSSH-Server-In-TCP" -ErrorAction SilentlyContinue)) {
    Log "Creating firewall rule"
    New-NetFirewallRule `
        -Name "OpenSSH-Server-In-TCP" `
        -DisplayName "OpenSSH Server" `
        -Direction Inbound `
        -Protocol TCP `
        -LocalPort 22 `
        -Action Allow
}

# -------------------------------
# sshd_config
# -------------------------------
$config = "$env:ProgramData\ssh\sshd_config"
if (Test-Path $config) {
    Log "Updating sshd_config"

    Copy-Item $config "$config.bak" -Force

    (Get-Content $config) `
        -replace '^#?PubkeyAuthentication.*','PubkeyAuthentication yes' `
        -replace '^#?PasswordAuthentication.*','PasswordAuthentication yes' `
        -replace '^#?PermitEmptyPasswords.*','PermitEmptyPasswords no' |
        Set-Content $config

    Restart-Service sshd
}

# -------------------------------
# CloudBase-Init support
# -------------------------------
$authKeys = "$env:ProgramData\ssh\administrators_authorized_keys"
if (-not (Test-Path $authKeys)) {
    New-Item -ItemType File -Path $authKeys -Force | Out-Null
    Log "Prepared administrators_authorized_keys for CloudBase-Init"
}

# -------------------------------
# Default shell
# -------------------------------
New-Item -Path "HKLM:\SOFTWARE\OpenSSH" -Force | Out-Null
New-ItemProperty `
    -Path "HKLM:\SOFTWARE\OpenSSH" `
    -Name DefaultShell `
    -Value "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe" `
    -Force | Out-Null

Log "Installation complete"
Log "CloudBase-Init plugin:"
Log "  SetUserSSHPublicKeysPlugin"
