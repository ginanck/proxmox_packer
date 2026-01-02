# CloudInit-RelocateCDROM.ps1
# Moves the CloudConfig/Cloud-Init CD-ROM drive to a late drive letter (Z:)
# to free up early letters (D:, E:, etc.) for data volumes
#
# This script should run BEFORE disk management scripts

$ErrorActionPreference = "Continue"

# Target drive letter for CD-ROM (use a late letter that won't conflict)
$TargetDriveLetter = "Z"

# Setup logging
$LogDir = "C:\Packer"
$Timestamp = Get-Date -Format "yyyy-MM-dd-HH-mm-ss"
$LogFile = Join-Path $LogDir "CloudInit-RelocateCDROM-$Timestamp.log"

if (-not (Test-Path $LogDir)) {
    New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
}

function Write-Log {
    param([string]$Message)
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$ts] $Message"
    Write-Host $logMessage -ForegroundColor Cyan
    Add-Content -Path $LogFile -Value $logMessage
}

function Write-LogError {
    param([string]$Message)
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$ts] ERROR: $Message"
    Write-Host $logMessage -ForegroundColor Red
    Add-Content -Path $LogFile -Value $logMessage
}

Write-Log "=== Relocating Cloud-Init CD-ROM Drive to ${TargetDriveLetter}: ==="

try {
    # Find all CD-ROM drives
    $cdromDrives = Get-WmiObject -Class Win32_CDROMDrive

    if ($cdromDrives.Count -eq 0) {
        Write-Log "No CD-ROM drives found, nothing to relocate"
        exit 0
    }

    foreach ($cdrom in $cdromDrives) {
        $currentLetter = $cdrom.Drive
        Write-Log "Found CD-ROM: $($cdrom.Caption) at $currentLetter"

        # Skip if already at target letter
        if ($currentLetter -eq "${TargetDriveLetter}:") {
            Write-Log "CD-ROM already at target drive letter ${TargetDriveLetter}:, skipping"
            continue
        }

        # Get the volume for this CD-ROM
        $volume = Get-WmiObject -Class Win32_Volume | Where-Object {
            $_.DriveLetter -eq $currentLetter -and $_.DriveType -eq 5
        }

        if ($volume) {
            Write-Log "Changing drive letter from $currentLetter to ${TargetDriveLetter}:"

            # Check if target letter is in use
            $targetInUse = Get-WmiObject -Class Win32_Volume | Where-Object {
                $_.DriveLetter -eq "${TargetDriveLetter}:"
            }

            if ($targetInUse) {
                Write-LogError "Target drive letter ${TargetDriveLetter}: is already in use"
                # Try alternative letters
                $altLetters = @("Y", "X", "W", "Q")
                foreach ($alt in $altLetters) {
                    $altInUse = Get-WmiObject -Class Win32_Volume | Where-Object {
                        $_.DriveLetter -eq "${alt}:"
                    }
                    if (-not $altInUse) {
                        $TargetDriveLetter = $alt
                        Write-Log "Using alternative drive letter: ${TargetDriveLetter}:"
                        break
                    }
                }
            }

            # Change the drive letter
            $volume.DriveLetter = "${TargetDriveLetter}:"
            $result = $volume.Put()

            if ($result.ReturnValue -eq 0 -or $result -ne $null) {
                Write-Log "Successfully moved CD-ROM from $currentLetter to ${TargetDriveLetter}:"
            } else {
                Write-LogError "Failed to change drive letter"
            }
        } else {
            Write-Log "Could not find volume for CD-ROM at $currentLetter, trying alternative method..."

            # Alternative method using diskpart-style commands via PowerShell
            $partition = Get-Partition | Where-Object {
                $_.DriveLetter -eq ($currentLetter -replace ":", "")
            }

            if ($partition) {
                try {
                    # Remove current letter
                    $partition | Remove-PartitionAccessPath -AccessPath $currentLetter -ErrorAction SilentlyContinue
                    # Add new letter
                    $partition | Add-PartitionAccessPath -AccessPath "${TargetDriveLetter}:" -ErrorAction Stop
                    Write-Log "Successfully moved drive from $currentLetter to ${TargetDriveLetter}: using partition method"
                } catch {
                    Write-LogError "Partition method failed: $_"
                }
            }
        }
    }

    Write-Log "CD-ROM relocation complete"

} catch {
    Write-LogError "Failed to relocate CD-ROM: $_"
    exit 1
}

# Refresh drive letters in explorer
$shell = New-Object -ComObject Shell.Application
$shell.NameSpace(17).Self.InvokeVerb("Refresh")

Write-Log "=== CD-ROM Relocation Script Complete ==="
