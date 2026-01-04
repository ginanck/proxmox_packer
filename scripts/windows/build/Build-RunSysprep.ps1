# Run-Sysprep.ps1
# Final cleanup + Sysprep execution
# This MUST be the last script executed during image build

# ===============================
# LOGGING
# ===============================
$LogDir = "C:\Packer"
$Timestamp = Get-Date -Format "yyyy-MM-dd-HH-mm-ss"
$LogFile = Join-Path $LogDir "Build-RunSysprep-$Timestamp.log"

if (-not (Test-Path $LogDir)) {
    New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
}

function Write-Log {
    param([string]$Message)
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $msg = "[$ts] $Message"
    Write-Host $msg -ForegroundColor Green
    Add-Content -Path $LogFile -Value $msg
}

function Write-LogError {
    param([string]$Message)
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $msg = "[$ts] ERROR: $Message"
    Write-Host $msg -ForegroundColor Red
    Add-Content -Path $LogFile -Value $msg
}

Write-Log "=== Starting FINAL pre-sysprep phase ==="
Write-Log "Note: Pending reboot checks should have been handled by Build-PreSysprepReboot.ps1"

# ===============================
# FINAL CLEANUP (SAFE ORDER)
# ===============================
Write-Log "Performing final cleanup before Sysprep..."

# --- TEMP FILES ---
Write-Log "Cleaning temporary directories..."
try {
    # Clean user temp but EXCLUDE Packer's env files to avoid race condition
    Get-ChildItem "$env:TEMP\*" -Exclude "packer-ps-env-vars-*" -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue

    # Clean Windows Temp but EXCLUDE Packer's env files
    Get-ChildItem "C:\Windows\Temp\*" -Exclude "packer-ps-env-vars-*" -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue

    Write-Log "Temporary files cleaned (excluded Packer env files)"
} catch {
    Write-LogError "Temp cleanup failed: $_"
}

# --- EVENT LOGS (SAFE ON ALL VERSIONS) ---
Write-Log "Clearing event logs (System & Application only)..."
try {
    wevtutil cl System 2>$null
    wevtutil cl Application 2>$null
    Write-Log "Event logs cleared"
} catch {
    Write-LogError "Event log cleanup failed: $_"
}

# NOTE:
# - We intentionally DO NOT clear:
#   - Windows Update cache
#   - Security event log
# These cause servicing and security provider delays on 2016/2019

# ===============================
# CLOUDBASE-INIT SETUP
# ===============================
Write-Log "Configuring Cloudbase-Init SetupComplete hook..."

$setupPath = "C:\Windows\Setup\Scripts"
if (-not (Test-Path $setupPath)) {
    New-Item -Path $setupPath -ItemType Directory -Force | Out-Null
}

$setupComplete = @'
@echo off
echo Running Cloudbase-Init after Sysprep...
"C:\Program Files\Cloudbase Solutions\Cloudbase-Init\bin\cloudbase-init.exe" ^
 --config-file "C:\Program Files\Cloudbase Solutions\Cloudbase-Init\conf\cloudbase-init.conf"
'@

try {
    $setupComplete | Out-File "$setupPath\SetupComplete.cmd" -Encoding ASCII -Force
    Write-Log "SetupComplete.cmd created"
} catch {
    Write-LogError "Failed to write SetupComplete.cmd: $_"
}

# ===============================
# REMOVE BUILD AUTOLOGON ARTIFACTS
# ===============================
Write-Log "Removing autologon build artifacts..."

try {
    $winlogon = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"
    Remove-ItemProperty -Path $winlogon -Name AutoAdminLogon -Force -ErrorAction SilentlyContinue
    Remove-ItemProperty -Path $winlogon -Name DefaultUserName -Force -ErrorAction SilentlyContinue
    Remove-ItemProperty -Path $winlogon -Name DefaultPassword -Force -ErrorAction SilentlyContinue
    Write-Log "Autologon registry cleaned"
} catch {
    Write-LogError "Failed to clean autologon registry: $_"
}

Write-Log "=== Executing Sysprep ==="

$sysprepExe = "C:\Windows\System32\Sysprep\sysprep.exe"
$unattend   = "C:\Windows\System32\Sysprep\unattend-sysprep.xml"
$args       = "/generalize /oobe /shutdown /mode:vm /unattend:$unattend"

# Ensure an unattend file is present for Sysprep. Prefer files on the UNATTEND ISO, if available.
function Get-DriveByLabel {
    param([Parameter(Mandatory=$true)][string]$Label)

    # Modern Get-Volume approach
    try {
        $vol = Get-Volume -ErrorAction SilentlyContinue | Where-Object { $_.FileSystemLabel -eq $Label } | Select-Object -First 1
        if ($vol -and $vol.DriveLetter) { return "$($vol.DriveLetter):\" }
    } catch { }

    # Fallback for older OSes
    try {
        $wmi = Get-WmiObject Win32_Volume -ErrorAction SilentlyContinue | Where-Object { $_.Label -eq $Label } | Select-Object -First 1
        if ($wmi -and $wmi.DriveLetter) { return "$($wmi.DriveLetter):\" }
    } catch { }

    return $null
}

Write-Log "Checking for sysprep unattend file..."
$unattendDrive = Get-DriveByLabel -Label "UNATTEND"
if ($unattendDrive) {
    Write-Log "Found UNATTEND drive at $unattendDrive. Detecting OS to select correct sysprep file..."
    # Detect OS caption/version
    try {
        $os = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop
        $caption = $os.Caption
    } catch {
        try { $caption = (Get-WmiObject Win32_OperatingSystem).Caption } catch { $caption = "Windows" }
    }
    Write-Log "OS detected: $caption"

    # Choose file based on OS
    $candidate = "sysprep-unattend-modern.xml"
    if ($caption -match "(?i)2012") {
        $candidate = "sysprep-unattend-legacy.xml"
    } else {
        # For 2016/2019/2022 and Windows 10/11 keep modern
        $candidate = "sysprep-unattend-modern.xml"
    }

    $src = Join-Path $unattendDrive $candidate
    Write-Log "Attempting to copy candidate '$candidate' from $unattendDrive (source: $src) to $unattend"
    if (Test-Path $src) {
        try {
            Copy-Item -Path $src -Destination $unattend -Force -ErrorAction Stop
            if (Test-Path $unattend) {
                try {
                    $info = Get-Item -Path $unattend -ErrorAction Stop
                    $size = $info.Length
                } catch {
                    $size = "unknown"
                }
                Write-Log "Copied '$src' (size: $size bytes) to '$unattend'"
            } else {
                Write-LogError "Copy appeared successful but destination $unattend not found"
            }
        } catch {
            Write-LogError "Failed to copy '${src}' to '${unattend}': $($_)"
        }
    } else {
        Write-Log "Selected $candidate not found on UNATTEND drive; will proceed expecting an existing $unattend"
    }
} else {
    Write-Log "UNATTEND ISO not found; will proceed expecting an existing $unattend"
}

Write-Log "Command: $sysprepExe $args"
Write-Log "System will shutdown after completion"

try {
    $p = Start-Process -FilePath $sysprepExe -ArgumentList $args -PassThru -NoNewWindow

    # Wait up to 30 minutes (1800 seconds) for Sysprep to finish
    $timeoutSeconds = 30 * 60
    Write-Log "Waiting up to $timeoutSeconds seconds for Sysprep to complete..."

    # Use .WaitForExit(milliseconds) to detect timeout reliably
    $waitMs = $timeoutSeconds * 1000
    $finished = $p.WaitForExit($waitMs)

    if (-not $finished -or -not $p.HasExited) {
        Write-LogError "Sysprep did not finish within $timeoutSeconds seconds. Dumping Sysprep Panther logs for debugging."

        $panther = Join-Path $env:windir "System32\Sysprep\Panther"
        $logs = @("setupact.log","setuperr.log")
        foreach ($l in $logs) {
            $path = Join-Path $panther $l
            if (Test-Path $path) {
                Write-Log "---- Begin $l ----"
                try { Get-Content -Tail 500 $path -ErrorAction Stop | ForEach-Object { Write-Log $_ } } catch { Write-LogError "Failed to read ${path}: $_" }
                Write-Log "---- End $l ----"
            } else {
                Write-Log "Log not found: $path"
            }
        }

        # Attempt to terminate Sysprep process
        try {
            $p | Stop-Process -Force -ErrorAction SilentlyContinue
            Write-Log "Sysprep process terminated"
        } catch {
            Write-LogError "Failed to terminate Sysprep process: $_"
        }

        Write-LogError "Sysprep timed out"
        exit 1
    }

    # Refresh process object and check exit code if available
    $p.Refresh()

    # Try to read exit code safely (some environments may not expose it)
    $exitCode = $null
    try { $exitCode = $p.ExitCode } catch { $exitCode = $null }

    if ($p.HasExited) {
        # Consider Sysprep success if ExitCode == 0 OR (ExitCode unavailable but success tag exists)
        $successTag = "C:\Windows\System32\Sysprep\Sysprep_succeeded.tag"
        $successByTag = Test-Path $successTag
        $failure = $false

        if ($exitCode -ne $null) {
            if ($exitCode -ne 0) {
                Write-LogError "Sysprep failed with exit code $exitCode"
                $failure = $true
            } else {
                Write-Log "Sysprep exited successfully (exit code 0). System should shutdown shortly."
            }
        } else {
            if ($successByTag) {
                Write-Log "Sysprep exited but exit code is unavailable; found success tag ($successTag) - treating as success."
            } else {
                Write-LogError "Sysprep exited but exit code is unavailable and no success tag found (process id $($p.Id))."
                $failure = $true
            }
        }

        if ($failure) {
            Write-Log "Dumping Panther logs due to Sysprep failure..."
            $panther = Join-Path $env:windir "System32\Sysprep\Panther"
            $logs = @("setupact.log","setuperr.log")
            foreach ($l in $logs) {
                $path = Join-Path $panther $l
                if (Test-Path $path) {
                    Write-Log "---- Begin $l ----"
                    try { Get-Content -Tail 500 $path -ErrorAction Stop | ForEach-Object { Write-Log $_ } } catch { Write-LogError "Failed to read ${path}: $_" }
                    Write-Log "---- End $l ----"
                } else {
                    Write-Log "Log not found: $path"
                }
            }
            exit 1
        }
    }
}
catch {
    Write-LogError "Sysprep execution failed: $_"

    # Attempt to dump Panther logs on exception too
    $panther = Join-Path $env:windir "System32\Sysprep\Panther"
    $logs = @("setupact.log","setuperr.log")
    foreach ($l in $logs) {
        $path = Join-Path $panther $l
        if (Test-Path $path) {
            Write-Log "---- Begin $l ----"
            try { Get-Content -Tail 500 $path -ErrorAction Stop | ForEach-Object { Write-Log $_ } } catch { Write-LogError "Failed to read ${path}: $_" }
            Write-Log "---- End $l ----"
        }
    }

    exit 1
}
