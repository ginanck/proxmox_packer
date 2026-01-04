# Runtime-ManageDisks.ps1
# Terraform-callable: Automatic disk management for all drives
#
# Features:
#   - Brings offline disks online
#   - Initializes RAW/unpartitioned disks (GPT + NTFS)
#   - Extends all existing partitions to use unallocated space
#
# Idempotent: Safe to run multiple times - only performs necessary actions
#
# Note: CD-ROM relocation is handled by 01-CloudInit-RelocateCDROM.ps1 during first boot
#
# Usage:
#   .\Runtime-ManageDisks.ps1    # Runs all operations automatically

# Suppress PowerShell progress output (prevents CLIXML noise over WinRM)
$ProgressPreference = 'SilentlyContinue'
$ErrorActionPreference = "Continue"
$logFile = "C:\Windows\Temp\disk-management-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"

# Track changes for idempotency reporting
$script:changesApplied = @{
    DisksOnlined    = 0
    DisksInitialized = 0
    VolumesExtended  = 0
}

function Write-DiskLog {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    Write-Host $logMessage
    Add-Content -Path $logFile -Value $logMessage
}

Write-DiskLog "=== Automatic Disk Management Started ===" -Level "INFO"

# Rescan storage subsystem first
Write-DiskLog "Rescanning storage subsystem..."
try {
    Update-HostStorageCache -ErrorAction SilentlyContinue
} catch {
    Write-DiskLog "Storage rescan warning (non-fatal): $_" -Level "WARN"
}

# ============================================================================
# PHASE 1: BRING OFFLINE DISKS ONLINE
# ============================================================================
Write-DiskLog "--- Phase 1: Checking Offline Disks ---"

$allDisks = Get-Disk
$offlineDisks = $allDisks | Where-Object { $_.OperationalStatus -eq 'Offline' }

if ($offlineDisks.Count -eq 0) {
    Write-DiskLog "All disks already online - no action needed"
} else {
    foreach ($disk in $offlineDisks) {
        # Double-check disk is still offline (idempotency)
        $currentDisk = Get-Disk -Number $disk.Number -ErrorAction SilentlyContinue
        if ($currentDisk.OperationalStatus -eq 'Online') {
            Write-DiskLog "Disk $($disk.Number) already online - skipping"
            continue
        }

        try {
            Write-DiskLog "Bringing disk $($disk.Number) online (Size: $([math]::Round($disk.Size / 1GB, 2)) GB)"
            Set-Disk -Number $disk.Number -IsOffline $false -ErrorAction Stop
            Set-Disk -Number $disk.Number -IsReadOnly $false -ErrorAction SilentlyContinue
            Write-DiskLog "Disk $($disk.Number) is now online" -Level "SUCCESS"
            $script:changesApplied.DisksOnlined++
        } catch {
            Write-DiskLog "Failed to bring disk $($disk.Number) online: $_" -Level "ERROR"
        }
    }
}

# ============================================================================
# PHASE 2: INITIALIZE RAW/UNPARTITIONED DISKS
# ============================================================================
Write-DiskLog "--- Phase 2: Checking Unpartitioned Disks ---"

# Refresh disk list after bringing disks online
$rawDisks = Get-Disk | Where-Object { $_.PartitionStyle -eq 'RAW' -and $_.Size -gt 0 }

if ($rawDisks.Count -eq 0) {
    Write-DiskLog "All disks already initialized - no action needed"
} else {
    Write-DiskLog "Found $($rawDisks.Count) uninitialized disk(s)"

    foreach ($disk in ($rawDisks | Sort-Object Number)) {
        # Double-check disk is still RAW (idempotency)
        $currentDisk = Get-Disk -Number $disk.Number -ErrorAction SilentlyContinue
        if ($currentDisk.PartitionStyle -ne 'RAW') {
            Write-DiskLog "Disk $($disk.Number) already initialized - skipping"
            continue
        }

        try {
            $sizeGB = [math]::Round($disk.Size / 1GB, 2)
            Write-DiskLog "Initializing disk $($disk.Number) (Size: $sizeGB GB)"

            # Initialize as GPT
            Initialize-Disk -Number $disk.Number -PartitionStyle GPT -ErrorAction Stop
            Start-Sleep -Milliseconds 500

            # Create partition with auto-assigned drive letter
            $partition = New-Partition -DiskNumber $disk.Number -UseMaximumSize -AssignDriveLetter -ErrorAction Stop

            # Format as NTFS
            $label = "Data_Disk$($disk.Number)"
            $partition | Format-Volume -FileSystem NTFS -NewFileSystemLabel $label -Confirm:$false -ErrorAction Stop

            Write-DiskLog "Disk $($disk.Number) initialized as NTFS ($label) - Drive $($partition.DriveLetter):" -Level "SUCCESS"
            $script:changesApplied.DisksInitialized++

        } catch {
            Write-DiskLog "Failed to initialize disk $($disk.Number): $_" -Level "ERROR"
        }
    }
}

# ============================================================================
# PHASE 3: EXTEND ALL EXISTING VOLUMES
# ============================================================================
Write-DiskLog "--- Phase 3: Checking Volume Extensions ---"

$volumes = Get-Volume | Where-Object {
    $_.DriveLetter -ne $null -and $_.FileSystem -eq 'NTFS'
}

foreach ($volume in $volumes) {
    try {
        $partition = Get-Partition -DriveLetter $volume.DriveLetter -ErrorAction SilentlyContinue
        if (-not $partition) { continue }

        $supportedSize = Get-PartitionSupportedSize -DiskNumber $partition.DiskNumber -PartitionNumber $partition.PartitionNumber -ErrorAction SilentlyContinue
        if (-not $supportedSize) { continue }

        $maxSize = $supportedSize.SizeMax
        $currentSize = $partition.Size

        # Check if there's space to extend (at least 1MB)
        $diffBytes = $maxSize - $currentSize
        if ($diffBytes -gt 1MB) {
            $currentGB = [math]::Round($currentSize / 1GB, 2)
            $maxGB = [math]::Round($maxSize / 1GB, 2)
            $diffGB = [math]::Round($diffBytes / 1GB, 2)

            Write-DiskLog "Extending $($volume.DriveLetter): from $currentGB GB to $maxGB GB (+$diffGB GB)"

            Resize-Partition -DiskNumber $partition.DiskNumber -PartitionNumber $partition.PartitionNumber -Size $maxSize -ErrorAction Stop

            Write-DiskLog "$($volume.DriveLetter): extended successfully" -Level "SUCCESS"
            $script:changesApplied.VolumesExtended++
        }
    } catch {
        Write-DiskLog "Error extending $($volume.DriveLetter): - $_" -Level "ERROR"
    }
}

if ($script:changesApplied.VolumesExtended -eq 0) {
    Write-DiskLog "All volumes already at maximum size - no action needed"
}

# ============================================================================
# SUMMARY
# ============================================================================
$totalChanges = $script:changesApplied.DisksOnlined + $script:changesApplied.DisksInitialized + $script:changesApplied.VolumesExtended

if ($totalChanges -eq 0) {
    Write-DiskLog "=== Disk Management Complete (No changes needed) ===" -Level "INFO"
} else {
    Write-DiskLog "=== Disk Management Complete ===" -Level "INFO"
    Write-DiskLog "Changes applied: $($script:changesApplied.DisksOnlined) disks onlined, $($script:changesApplied.DisksInitialized) disks initialized, $($script:changesApplied.VolumesExtended) volumes extended"
}

Write-DiskLog "Log file: $logFile"

# Output JSON summary for Terraform
$summary = @{
    LogFile   = $logFile
    Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    Success   = $true
    Changed   = ($totalChanges -gt 0)
    Changes   = $script:changesApplied
}

$summary | ConvertTo-Json
