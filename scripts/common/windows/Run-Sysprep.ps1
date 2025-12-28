# Run-Sysprep.ps1
# Generalizes Windows installation for template cloning
# This script should be the LAST script run before template creation
#
# Sysprep performs:
# - Removes machine-specific SID (Security Identifier)
# - Clears hardware-specific drivers and settings
# - Resets Windows activation
# - Prepares for OOBE on first boot of cloned VMs

$LogFile = "C:\windows-sysprep.log"

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

Write-Log "=== Starting Sysprep Preparation ==="

# ============================================================================
# 1. PRE-SYSPREP CLEANUP
# ============================================================================
Write-Log "Performing pre-sysprep cleanup..."

# Clear Windows Update cache
Write-Log "Clearing Windows Update cache..."
try {
    Stop-Service -Name wuauserv -Force -ErrorAction SilentlyContinue
    Remove-Item -Path "C:\Windows\SoftwareDistribution\Download\*" -Recurse -Force -ErrorAction SilentlyContinue
    Start-Service -Name wuauserv -ErrorAction SilentlyContinue
    Write-Log "Windows Update cache cleared"
} catch {
    Write-LogError "Failed to clear Windows Update cache: $_"
}

# Clear temp files
Write-Log "Clearing temporary files..."
try {
    Remove-Item -Path "$env:TEMP\*" -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -Path "C:\Windows\Temp\*" -Recurse -Force -ErrorAction SilentlyContinue
    Write-Log "Temporary files cleared"
} catch {
    Write-LogError "Failed to clear temp files: $_"
}

# Clear event logs (optional - keeps template clean)
Write-Log "Clearing event logs..."
try {
    wevtutil cl System 2>&1 | Out-Null
    wevtutil cl Application 2>&1 | Out-Null
    wevtutil cl Security 2>&1 | Out-Null
    Write-Log "Event logs cleared"
} catch {
    Write-LogError "Failed to clear event logs: $_"
}

# ============================================================================
# 2. CREATE SYSPREP UNATTEND FILE
# ============================================================================
Write-Log "Creating Sysprep unattend file..."

# This unattend file is used BY sysprep during generalization
# It configures what happens on first boot after cloning
$sysprepUnattend = @'
<?xml version="1.0" encoding="utf-8"?>
<unattend xmlns="urn:schemas-microsoft-com:unattend">
    <settings pass="generalize">
        <component name="Microsoft-Windows-PnpSysprep" processorArchitecture="amd64"
                   publicKeyToken="31bf3856ad364e35" language="neutral"
                   versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State">
            <!-- Keep device drivers installed during generalization -->
            <PersistAllDeviceInstalls>true</PersistAllDeviceInstalls>
            <!-- Don't cleanup plug and play drivers -->
            <DoNotCleanUpNonPresentDevices>true</DoNotCleanUpNonPresentDevices>
        </component>
        <component name="Microsoft-Windows-Security-SPP" processorArchitecture="amd64"
                   publicKeyToken="31bf3856ad364e35" language="neutral"
                   versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State">
            <!-- Skip Windows reactivation on first boot -->
            <SkipRearm>1</SkipRearm>
        </component>
    </settings>
    <settings pass="specialize">
        <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64"
                   publicKeyToken="31bf3856ad364e35" language="neutral"
                   versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State">
            <!-- Random computer name - CloudBase-Init will set the real hostname -->
            <ComputerName>*</ComputerName>
        </component>
        <component name="Microsoft-Windows-Deployment" processorArchitecture="amd64"
                   publicKeyToken="31bf3856ad364e35" language="neutral"
                   versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State">
            <RunSynchronous>
                <RunSynchronousCommand wcm:action="add">
                    <Order>1</Order>
                    <Description>Enable Administrator Account</Description>
                    <Path>cmd /c net user Administrator /active:yes</Path>
                </RunSynchronousCommand>
            </RunSynchronous>
        </component>
    </settings>
    <settings pass="oobeSystem">
        <component name="Microsoft-Windows-International-Core" processorArchitecture="amd64"
                   publicKeyToken="31bf3856ad364e35" language="neutral"
                   versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State">
            <UserLocale>en-US</UserLocale>
            <SystemLocale>en-US</SystemLocale>
            <UILanguage>en-US</UILanguage>
            <InputLocale>0409:00000409</InputLocale>
        </component>
        <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64"
                   publicKeyToken="31bf3856ad364e35" language="neutral"
                   versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State">
            <OOBE>
                <!-- Skip OOBE screens - CloudBase-Init handles setup -->
                <HideEULAPage>true</HideEULAPage>
                <HideLocalAccountScreen>true</HideLocalAccountScreen>
                <HideOEMRegistrationScreen>true</HideOEMRegistrationScreen>
                <HideOnlineAccountScreens>true</HideOnlineAccountScreens>
                <HideWirelessSetupInOOBE>true</HideWirelessSetupInOOBE>
                <ProtectYourPC>3</ProtectYourPC>
                <UnattendEnableRetailDemo>false</UnattendEnableRetailDemo>
                <SkipMachineOOBE>true</SkipMachineOOBE>
                <SkipUserOOBE>true</SkipUserOOBE>
            </OOBE>
            <!-- Let CloudBase-Init set the hostname from Terraform metadata -->
            <ComputerName>*</ComputerName>
            <TimeZone>UTC</TimeZone>
        </component>
    </settings>
</unattend>
'@

$sysprepUnattendPath = "C:\Windows\System32\Sysprep\unattend-sysprep.xml"
try {
    $sysprepUnattend | Out-File -FilePath $sysprepUnattendPath -Encoding UTF8 -Force
    Write-Log "Sysprep unattend file created: $sysprepUnattendPath"
} catch {
    Write-LogError "Failed to create sysprep unattend file: $_"
    exit 1
}

# ============================================================================
# 3. CONFIGURE CLOUDBASE-INIT FOR POST-SYSPREP
# ============================================================================
Write-Log "Configuring CloudBase-Init for post-sysprep execution..."

# Ensure CloudBase-Init runs SetupComplete after sysprep
$setupCompletePath = "C:\Windows\Setup\Scripts"
if (-not (Test-Path $setupCompletePath)) {
    New-Item -Path $setupCompletePath -ItemType Directory -Force | Out-Null
}

# SetupComplete.cmd runs after Windows setup completes (after sysprep OOBE)
$setupCompleteCmd = @'
@echo off
REM SetupComplete.cmd - Runs after Sysprep OOBE completes
REM Triggers CloudBase-Init for final configuration

echo Starting CloudBase-Init post-sysprep configuration...
"C:\Program Files\Cloudbase Solutions\Cloudbase-Init\bin\cloudbase-init.exe" --config-file "C:\Program Files\Cloudbase Solutions\Cloudbase-Init\conf\cloudbase-init.conf"
'@

try {
    $setupCompleteCmd | Out-File -FilePath "$setupCompletePath\SetupComplete.cmd" -Encoding ASCII -Force
    Write-Log "SetupComplete.cmd created for CloudBase-Init execution"
} catch {
    Write-LogError "Failed to create SetupComplete.cmd: $_"
}

# ============================================================================
# 4. REMOVE PACKER BUILD ARTIFACTS
# ============================================================================
Write-Log "Cleaning up Packer build artifacts..."

# Remove the ansible user auto-logon (CloudBase-Init will manage users)
try {
    $winlogonPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"
    Remove-ItemProperty -Path $winlogonPath -Name "AutoAdminLogon" -Force -ErrorAction SilentlyContinue
    Remove-ItemProperty -Path $winlogonPath -Name "DefaultUserName" -Force -ErrorAction SilentlyContinue
    Remove-ItemProperty -Path $winlogonPath -Name "DefaultPassword" -Force -ErrorAction SilentlyContinue
    Write-Log "Auto-logon credentials removed"
} catch {
    Write-LogError "Failed to remove auto-logon: $_"
}

# ============================================================================
# 5. RUN SYSPREP
# ============================================================================
Write-Log "=== Executing Sysprep ==="
Write-Log "Sysprep parameters:"
Write-Log "  /generalize - Removes SID and machine-specific information"
Write-Log "  /oobe - Boot to Out-of-Box Experience on next start"
Write-Log "  /shutdown - Shutdown after sysprep completes"
Write-Log "  /mode:vm - Optimized for virtual machine environments"
Write-Log "  /unattend - Use custom unattend file for OOBE"

$sysprepExe = "C:\Windows\System32\Sysprep\sysprep.exe"
$sysprepArgs = "/generalize /oobe /shutdown /mode:vm /unattend:$sysprepUnattendPath"

Write-Log "Executing: $sysprepExe $sysprepArgs"
Write-Log "=== System will shutdown after Sysprep completes ==="

# Start sysprep - this will shutdown the VM
try {
    $process = Start-Process -FilePath $sysprepExe -ArgumentList $sysprepArgs -Wait -PassThru -NoNewWindow

    if ($process.ExitCode -ne 0) {
        Write-LogError "Sysprep failed with exit code: $($process.ExitCode)"
        Write-LogError "Check C:\Windows\System32\Sysprep\Panther\setuperr.log for details"
        exit 1
    }
} catch {
    Write-LogError "Failed to execute Sysprep: $_"
    exit 1
}

# Note: Script will not reach here as sysprep shuts down the system
Write-Log "Sysprep completed successfully"
