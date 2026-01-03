# Build-PreSysprepReboot.ps1
# Handles pending reboots before sysprep execution
# This script checks for pending Windows Updates or other reboot requirements
# and performs a reboot if needed. Packer's windows-restart provisioner will handle the restart.

# ===============================
# LOGGING
# ===============================
$LogDir = "C:\Packer"
$Timestamp = Get-Date -Format "yyyy-MM-dd-HH-mm-ss"
$LogFile = Join-Path $LogDir "Build-PreSysprepReboot-$Timestamp.log"

if (-not (Test-Path $LogDir)) {
    New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
}

function Write-Log {
    param([string]$Message)
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $msg = "[$ts] $Message"
    Write-Host $msg -ForegroundColor Cyan
    Add-Content -Path $LogFile -Value $msg
}

function Write-LogError {
    param([string]$Message)
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $msg = "[$ts] ERROR: $Message"
    Write-Host $msg -ForegroundColor Red
    Add-Content -Path $LogFile -Value $msg
}

Write-Log "=== Pre-Sysprep Reboot Check ==="

# ===============================
# PENDING REBOOT DETECTION
# ===============================

function Test-PendingReboot {
    Write-Log "Checking for pending reboot indicators..."
    $pending = $false
    $reasons = @()

    # Component Based Servicing
    try {
        if (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending') {
            $pending = $true
            $reasons += "Component Based Servicing"
        }
    } catch { }

    # Pending File Rename Operations
    try {
        $pf = (Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager' -Name PendingFileRenameOperations -ErrorAction SilentlyContinue).PendingFileRenameOperations
        if ($pf) {
            $pending = $true
            $reasons += "Pending File Rename Operations"
        }
    } catch { }

    # Windows Update
    try {
        if (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired') {
            $pending = $true
            $reasons += "Windows Update"
        }
    } catch { }

    # Update Exe Volatile
    try {
        if ((Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Updates' -Name UpdateExeVolatile -ErrorAction SilentlyContinue).UpdateExeVolatile) {
            $pending = $true
            $reasons += "Update Exe Volatile"
        }
    } catch { }

    # Computer Rename
    try {
        $activeComputerName = (Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\ComputerName\ActiveComputerName' -ErrorAction SilentlyContinue).ComputerName
        $pendingComputerName = (Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\ComputerName\ComputerName' -ErrorAction SilentlyContinue).ComputerName
        if ($activeComputerName -and $pendingComputerName -and ($activeComputerName -ne $pendingComputerName)) {
            $pending = $true
            $reasons += "Computer Rename Pending"
        }
    } catch { }

    # Check if reboot is in progress (from previous restart provisioner)
    try {
        $bootTime = (Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue).LastBootUpTime
        if (-not $bootTime) {
            $bootTime = (Get-WmiObject Win32_OperatingSystem -ErrorAction SilentlyContinue).ConvertToDateTime((Get-WmiObject Win32_OperatingSystem).LastBootUpTime)
        }
        $uptime = (Get-Date) - $bootTime
        Write-Log "System uptime: $($uptime.TotalMinutes.ToString('F2')) minutes"
    } catch {
        Write-Log "Could not determine system uptime"
    }

    return @{
        IsPending = $pending
        Reasons = $reasons
    }
}

# ===============================
# MAIN LOGIC
# ===============================

$rebootStatus = Test-PendingReboot

if ($rebootStatus.IsPending) {
    Write-Log "Pending reboot detected. Reasons:"
    foreach ($reason in $rebootStatus.Reasons) {
        Write-Log "  - $reason"
    }
    Write-Log "A reboot is required before sysprep can run safely."
    Write-Log "Packer's windows-restart provisioner will handle the reboot."
    Write-Log "After reboot, the build process will continue with sysprep."

    # Exit with special code to indicate reboot is needed
    # Packer's windows-restart provisioner will detect this and reboot
    exit 0
} else {
    Write-Log "No pending reboot detected."
    Write-Log "System is ready for sysprep execution."
    exit 0
}
