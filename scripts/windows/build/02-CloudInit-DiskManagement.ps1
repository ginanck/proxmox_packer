# CloudInit-DiskManagement.ps1
# Automatically initializes and formats all offline/uninitialized disks
# Runs during CloudBase-Init first boot via LocalScripts

$ErrorActionPreference = "Continue"

# Setup logging
$LogDir = "C:\Packer"
$Timestamp = Get-Date -Format "yyyy-MM-dd-HH-mm-ss"
$LogFile = Join-Path $LogDir "CloudInit-DiskManagement-$Timestamp.log"

if (-not (Test-Path $LogDir)) {
    New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
}

function Write-Log {
    param([string]$Message)
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$ts] $Message"
    Write-Host $logMessage -ForegroundColor Green
    Add-Content -Path $LogFile -Value $logMessage
}

function Write-LogError {
    param([string]$Message)
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$ts] ERROR: $Message"
    Write-Host $logMessage -ForegroundColor Red
    Add-Content -Path $LogFile -Value $logMessage
}

Write-Log "=== Auto-Initializing Additional Disks ==="

# Get all offline disks
$offlineDisks = Get-Disk | Where-Object { $_.OperationalStatus -eq 'Offline' }
foreach ($disk in $offlineDisks) {
    Write-Log "Bringing disk $($disk.Number) online..."
    Set-Disk -Number $disk.Number -IsOffline $false
}

# Get all uninitialized disks
$rawDisks = Get-Disk | Where-Object { $_.PartitionStyle -eq 'RAW' }

if ($rawDisks.Count -eq 0) {
    Write-Log "No uninitialized disks found. Checking for extension..."

    # Extend existing volumes that have unallocated space
    $volumes = Get-Volume | Where-Object { $_.DriveLetter -ne $null }
    foreach ($volume in $volumes) {
        $partition = Get-Partition | Where-Object { $_.DriveLetter -eq $volume.DriveLetter }
        if ($partition) {
            $disk = Get-Disk -Number $partition.DiskNumber
            $maxSize = (Get-PartitionSupportedSize -DiskNumber $partition.DiskNumber -PartitionNumber $partition.PartitionNumber).SizeMax

            if ($partition.Size -lt $maxSize) {
                $sizeDiffGB = [math]::Round(($maxSize - $partition.Size) / 1GB, 2)
                Write-Log "Extending $($volume.DriveLetter): by $sizeDiffGB GB..."
                Resize-Partition -DiskNumber $partition.DiskNumber -PartitionNumber $partition.PartitionNumber -Size $maxSize
                Write-Log "Volume $($volume.DriveLetter): extended successfully"
            }
        }
    }

    exit 0
}

Write-Log "Found $($rawDisks.Count) uninitialized disk(s)"

# Available drive letters (skip A, B, C, D which are typically reserved)
$usedLetters = (Get-Volume | Where-Object { $_.DriveLetter -ne $null }).DriveLetter
$availableLetters = 69..90 | ForEach-Object { [char]$_ } | Where-Object { $usedLetters -notcontains $_ }

$letterIndex = 0

foreach ($disk in $rawDisks) {
    try {
        Write-Log "Initializing disk $($disk.Number) (Size: $([math]::Round($disk.Size / 1GB, 2)) GB)..."

        # Initialize as GPT
        Initialize-Disk -Number $disk.Number -PartitionStyle GPT -ErrorAction Stop

        # Create partition using all available space
        $partition = New-Partition -DiskNumber $disk.Number -UseMaximumSize -ErrorAction Stop

        # Assign drive letter
        if ($letterIndex -lt $availableLetters.Count) {
            $driveLetter = $availableLetters[$letterIndex]
            $partition | Set-Partition -NewDriveLetter $driveLetter -ErrorAction Stop
            Write-Log "Assigned drive letter: ${driveLetter}:"
        } else {
            Write-Log "No available drive letters, disk will not have a letter"
        }

        # Format as NTFS
        $volume = $partition | Format-Volume -FileSystem NTFS -NewFileSystemLabel "Data$($disk.Number)" -Confirm:$false -ErrorAction Stop

        Write-Log "Disk $($disk.Number) initialized and formatted successfully"
        $letterIndex++

    } catch {
        Write-LogError "Failed to initialize disk $($disk.Number): $_"
    }
}

Write-Log "=== Disk Initialization Complete ==="

# Extend existing volumes if they have unallocated space
Write-Log "Checking for volumes that can be extended..."
$volumes = Get-Volume | Where-Object { $_.DriveLetter -ne $null -and $_.FileSystem -eq 'NTFS' }
foreach ($volume in $volumes) {
    try {
        $partition = Get-Partition | Where-Object { $_.DriveLetter -eq $volume.DriveLetter }
        if ($partition) {
            $maxSize = (Get-PartitionSupportedSize -DiskNumber $partition.DiskNumber -PartitionNumber $partition.PartitionNumber).SizeMax

            if ($partition.Size -lt $maxSize) {
                $sizeDiffGB = [math]::Round(($maxSize - $partition.Size) / 1GB, 2)
                Write-Log "Extending $($volume.DriveLetter): by $sizeDiffGB GB..."
                Resize-Partition -DiskNumber $partition.DiskNumber -PartitionNumber $partition.PartitionNumber -Size $maxSize
                Write-Log "Volume $($volume.DriveLetter): extended successfully"
            }
        }
    } catch {
        Write-Log "Could not extend $($volume.DriveLetter): - $_"
    }
}

Write-Log "=== All Disk Operations Complete ==="
