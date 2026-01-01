# Apply-DiskManagement.ps1
# Terraform-callable: Initialize new disks and extend existing volumes
#
# Usage Examples:
#   .\Apply-DiskManagement.ps1                          # Full operation: extend + initialize
#   .\Apply-DiskManagement.ps1 -ExtendOnly             # Only extend existing volumes
#   .\Apply-DiskManagement.ps1 -InitializeOnly         # Only initialize new disks
#   .\Apply-DiskManagement.ps1 -DriveLetter "C"        # Only extend C: drive

param(
    [switch]$ExtendOnly,
    [switch]$InitializeOnly,
    [string]$DriveLetter
)

$ErrorActionPreference = "Continue"
$logFile = "C:\Windows\Temp\disk-management-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"

function Write-DiskLog {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    Write-Host $logMessage
    Add-Content -Path $logFile -Value $logMessage
}

Write-DiskLog "=== Disk Management Operation Started ===" -Level "INFO"
Write-DiskLog "Parameters: ExtendOnly=$ExtendOnly, InitializeOnly=$InitializeOnly, DriveLetter=$DriveLetter"

# Rescan storage subsystem
Write-DiskLog "Rescanning storage subsystem..."
Update-HostStorageCache

if (-not $InitializeOnly) {
    # EXTEND EXISTING VOLUMES
    Write-DiskLog "Checking for extendable volumes..."
    $volumes = Get-Volume | Where-Object { $_.FileSystem -eq 'NTFS' -and $_.DriveLetter -ne $null }

    foreach ($volume in $volumes) {
        if ($DriveLetter -and $volume.DriveLetter -ne $DriveLetter) { continue }

        try {
            $partition = Get-Partition | Where-Object { $_.DriveLetter -eq $volume.DriveLetter }
            if ($partition) {
                $supportedSize = Get-PartitionSupportedSize -DiskNumber $partition.DiskNumber -PartitionNumber $partition.PartitionNumber
                $maxSize = $supportedSize.SizeMax
                $currentSize = $partition.Size

                if ($maxSize -gt $currentSize) {
                    $diffGB = [math]::Round(($maxSize - $currentSize) / 1GB, 2)
                    Write-DiskLog "Extending $($volume.DriveLetter): by $diffGB GB (from $([math]::Round($currentSize / 1GB, 2)) GB to $([math]::Round($maxSize / 1GB, 2)) GB)" -Level "INFO"

                    Resize-Partition -DiskNumber $partition.DiskNumber -PartitionNumber $partition.PartitionNumber -Size $maxSize -ErrorAction Stop
                    Write-DiskLog "Successfully extended $($volume.DriveLetter):" -Level "SUCCESS"
                } else {
                    Write-DiskLog "$($volume.DriveLetter): already at maximum size ($([math]::Round($currentSize / 1GB, 2)) GB)" -Level "INFO"
                }
            }
        } catch {
            Write-DiskLog "Error extending $($volume.DriveLetter): - $_" -Level "ERROR"
        }
    }
}

if (-not $ExtendOnly) {
    # INITIALIZE NEW DISKS
    Write-DiskLog "Checking for uninitialized disks..."

    # Bring offline disks online first
    $offlineDisks = Get-Disk | Where-Object { $_.OperationalStatus -eq 'Offline' }
    foreach ($disk in $offlineDisks) {
        Write-DiskLog "Bringing disk $($disk.Number) online..."
        Set-Disk -Number $disk.Number -IsOffline $false
    }

    $rawDisks = Get-Disk | Where-Object { $_.PartitionStyle -eq 'RAW' }

    if ($rawDisks.Count -eq 0) {
        Write-DiskLog "No uninitialized disks found" -Level "INFO"
    } else {
        Write-DiskLog "Found $($rawDisks.Count) uninitialized disk(s)" -Level "INFO"

        # Get available drive letters (skip A, B, C, D)
        $usedLetters = (Get-Volume | Where-Object { $_.DriveLetter -ne $null }).DriveLetter
        $availableLetters = 69..90 | ForEach-Object { [char]$_ } | Where-Object { $usedLetters -notcontains $_ }

        $letterIndex = 0

        foreach ($disk in $rawDisks) {
            try {
                Write-DiskLog "Initializing disk $($disk.Number) (Size: $([math]::Round($disk.Size / 1GB, 2)) GB)" -Level "INFO"

                # Initialize as GPT
                Initialize-Disk -Number $disk.Number -PartitionStyle GPT -ErrorAction Stop

                # Create partition using all available space
                $partition = New-Partition -DiskNumber $disk.Number -UseMaximumSize -ErrorAction Stop

                # Assign drive letter
                if ($letterIndex -lt $availableLetters.Count) {
                    $driveLetter = $availableLetters[$letterIndex]
                    $partition | Set-Partition -NewDriveLetter $driveLetter -ErrorAction Stop
                    Write-DiskLog "Assigned drive letter: ${driveLetter}:" -Level "INFO"
                } else {
                    Write-DiskLog "No available drive letters, disk will not have a letter" -Level "WARN"
                }

                # Format as NTFS
                $partition | Format-Volume -FileSystem NTFS -NewFileSystemLabel "Data$($disk.Number)" -Confirm:$false -ErrorAction Stop

                Write-DiskLog "Disk $($disk.Number) initialized and formatted successfully" -Level "SUCCESS"
                $letterIndex++

            } catch {
                Write-DiskLog "Failed to initialize disk $($disk.Number): $_" -Level "ERROR"
            }
        }
    }
}

Write-DiskLog "=== Disk Management Operation Complete ===" -Level "INFO"
Write-DiskLog "Log file: $logFile"

# Output summary for Terraform
$summary = @{
    LogFile = $logFile
    Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    Success = $true
}

$summary | ConvertTo-Json
