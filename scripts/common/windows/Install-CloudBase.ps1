# Install CloudBase-Init and Configure for Terraform Integration
# This script downloads, installs, and configures Cloudbase-Init
# for use with Terraform's cloud-init provider in Proxmox environments

$LogFile = "C:\cloudbase-init-setup.log"
$CloudBaseInstaller = "CloudbaseInitSetup_Stable_x64.msi"
$CloudBaseUrl = "https://cloudbase.it/downloads/CloudbaseInitSetup_Stable_x64.msi"
$CloudBaseConfDir = "C:\Program Files\Cloudbase Solutions\Cloudbase-Init\conf"

function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] $Message"
    Write-Host $logMessage -ForegroundColor Green
    Add-Content -Path $LogFile -Value $logMessage
}

function Write-LogError {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] ERROR: $Message"
    Write-Host $logMessage -ForegroundColor Red
    Add-Content -Path $LogFile -Value $logMessage
}

Write-Log "=== Starting Cloudbase-Init Installation ==="

try {
    # Download Cloudbase-Init
    Write-Log "Downloading Cloudbase-Init from $CloudBaseUrl"
    Invoke-WebRequest -Uri $CloudBaseUrl -OutFile $CloudBaseInstaller -UseBasicParsing

    if (-not (Test-Path $CloudBaseInstaller)) {
        Write-LogError "Failed to download Cloudbase-Init installer"
        exit 1
    }
    Write-Log "Download completed: $CloudBaseInstaller"

    # Install Cloudbase-Init
    Write-Log "Installing Cloudbase-Init..."
    $installArgs = @(
        "/i",
        $CloudBaseInstaller,
        "/qb-",           # Quiet with basic UI
        "/norestart",     # Don't restart automatically
        "/l*v",           # Verbose logging
        "C:\cloudbase-init-install.log"
    )

    $cloudbase = Start-Process msiexec.exe -ArgumentList $installArgs -NoNewWindow -Wait -PassThru

    if ($cloudbase.ExitCode -ne 0) {
        Write-LogError "Cloudbase-Init installation failed with exit code: $($cloudbase.ExitCode)"
        Write-LogError "Check installation log: C:\cloudbase-init-install.log"
        exit 1
    }
    Write-Log "Cloudbase-Init installed successfully"

    # Wait for installation to complete and files to be available
    Start-Sleep -Seconds 5

    # Verify installation directory exists
    if (-not (Test-Path $CloudBaseConfDir)) {
        Write-LogError "Cloudbase-Init configuration directory not found: $CloudBaseConfDir"
        exit 1
    }

    # Copy configuration files from Packer CD to Cloudbase-Init directory
    # These files should be in the root of the Packer-generated CD (same location as this script)
    $configFiles = @(
        @{
            Source = "E:\cloudbase-init.conf"
            Dest = "$CloudBaseConfDir\cloudbase-init.conf"
            Description = "Main configuration file"
        },
        @{
            Source = "E:\cloudbase-init-unattend.conf"
            Dest = "$CloudBaseConfDir\cloudbase-init-unattend.conf"
            Description = "Unattend configuration file"
        }
    )

    foreach ($config in $configFiles) {
        if (Test-Path $config.Source) {
            Write-Log "Copying $($config.Description): $($config.Source) -> $($config.Dest)"
            Copy-Item -Path $config.Source -Destination $config.Dest -Force -ErrorAction Stop
            Write-Log "Successfully copied $($config.Description)"
        } else {
            Write-LogError "Configuration file not found: $($config.Source)"
            Write-LogError "Cloudbase-Init will use default configuration"
        }
    }

    # Verify configuration files are in place
    $mainConfig = "$CloudBaseConfDir\cloudbase-init.conf"
    $unattendConfig = "$CloudBaseConfDir\cloudbase-init-unattend.conf"

    if (Test-Path $mainConfig) {
        Write-Log "Main configuration verified: $mainConfig"
    } else {
        Write-LogError "Main configuration not found after copy attempt"
    }

    if (Test-Path $unattendConfig) {
        Write-Log "Unattend configuration verified: $unattendConfig"
    } else {
        Write-LogError "Unattend configuration not found after copy attempt"
    }

    # Verify Cloudbase-Init service exists
    $service = Get-Service -Name "cloudbase-init" -ErrorAction SilentlyContinue
    if ($service) {
        Write-Log "Cloudbase-Init service status: $($service.Status)"
        Write-Log "Cloudbase-Init service startup type: $($service.StartType)"
    } else {
        Write-LogError "Cloudbase-Init service not found"
    }

    # Clean up installer
    if (Test-Path $CloudBaseInstaller) {
        Remove-Item $CloudBaseInstaller -Force
        Write-Log "Cleaned up installer file"
    }

    Write-Log "=== Cloudbase-Init Installation and Configuration Completed ==="
    Write-Log "Next steps:"
    Write-Log "1. Cloudbase-Init will run automatically on next boot"
    Write-Log "2. Check logs: C:\Program Files\Cloudbase Solutions\Cloudbase-Init\log\"
    Write-Log "3. Terraform can now use cloud-init for this template"
}
catch {
    Write-LogError "Exception during Cloudbase-Init installation: $($_.Exception.Message)"
    Write-LogError "Stack trace: $($_.Exception.StackTrace)"
    exit 1
}
