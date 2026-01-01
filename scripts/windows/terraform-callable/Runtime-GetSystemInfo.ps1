# Get-SystemInfo.ps1
# Terraform-callable: Collect comprehensive system diagnostics
# Includes: System info, disk status, network connectivity tests
#
# Usage Examples:
#   .\Get-SystemInfo.ps1              # Human-readable output
#   .\Get-SystemInfo.ps1 -Json        # JSON output for automation
#   .\Get-SystemInfo.ps1 -TestTargets "8.8.8.8","google.com"  # Custom connectivity tests

param(
    [switch]$Json,
    [string[]]$TestTargets = @("8.8.8.8", "1.1.1.1", "google.com")
)

$info = @{
    Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    Hostname = $env:COMPUTERNAME
    FQDN = [System.Net.Dns]::GetHostByName($env:COMPUTERNAME).HostName
    OS = @{
        Version = [System.Environment]::OSVersion.VersionString
        Architecture = if ([System.Environment]::Is64BitOperatingSystem) { "x64" } else { "x86" }
        BuildNumber = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion").CurrentBuild
        BootTime = (Get-CimInstance Win32_OperatingSystem).LastBootUpTime.ToString("yyyy-MM-dd HH:mm:ss")
        UptimeHours = [math]::Round(((Get-Date) - (Get-CimInstance Win32_OperatingSystem).LastBootUpTime).TotalHours, 2)
    }
    Hardware = @{
        CPU = (Get-CimInstance Win32_Processor).Name
        Cores = (Get-CimInstance Win32_Processor).NumberOfCores
        LogicalProcessors = (Get-CimInstance Win32_Processor).NumberOfLogicalProcessors
        MemoryGB = [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 2)
    }
    Network = @{
        Adapters = @(Get-NetAdapter | Where-Object { $_.Status -eq 'Up' } | Select-Object Name, Status, LinkSpeed, MacAddress)
        IPAddresses = @(Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.PrefixOrigin -ne 'WellKnown' } | Select-Object InterfaceAlias, IPAddress, PrefixLength)
        DefaultGateway = @(Get-NetRoute -AddressFamily IPv4 | Where-Object { $_.DestinationPrefix -eq '0.0.0.0/0' } | Select-Object InterfaceAlias, NextHop)
        DNS = @(Get-DnsClientServerAddress -AddressFamily IPv4 | Where-Object { $_.ServerAddresses.Count -gt 0 } | Select-Object InterfaceAlias, ServerAddresses)
    }
    Disks = @(Get-Disk | Select-Object Number, FriendlyName, PartitionStyle, @{N='SizeGB';E={[math]::Round($_.Size / 1GB, 2)}}, OperationalStatus, HealthStatus)
    Volumes = @(Get-Volume | Where-Object { $_.DriveLetter } | Select-Object DriveLetter, FileSystemLabel, FileSystem, @{N='SizeGB';E={[math]::Round($_.Size / 1GB, 2)}}, @{N='FreeGB';E={[math]::Round($_.SizeRemaining / 1GB, 2)}}, @{N='UsedPercent';E={[math]::Round((1 - ($_.SizeRemaining / $_.Size)) * 100, 1)}})
    DiskDetails = @()
    Users = @(Get-LocalUser | Select-Object Name, Enabled, @{N='LastLogon';E={if ($_.LastLogon) { $_.LastLogon.ToString("yyyy-MM-dd HH:mm:ss") } else { "Never" }}}, @{N='PasswordLastSet';E={if ($_.PasswordLastSet) { $_.PasswordLastSet.ToString("yyyy-MM-dd HH:mm:ss") } else { "Never" }}})
    Services = @{
        CloudbaseInit = (Get-Service cloudbase-init -ErrorAction SilentlyContinue | Select-Object Status, StartType)
        WinRM = (Get-Service WinRM -ErrorAction SilentlyContinue | Select-Object Status, StartType)
        QEMU_Agent = (Get-Service QEMU-GA -ErrorAction SilentlyContinue | Select-Object Status, StartType)
        SSH = (Get-Service sshd -ErrorAction SilentlyContinue | Select-Object Status, StartType)
    }
    Features = @{
        RDP_Enabled = (Get-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -Name fDenyTSConnections).fDenyTSConnections -eq 0
        UAC_Enabled = (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' -Name EnableLUA).EnableLUA -eq 1
        Firewall_Enabled = (Get-NetFirewallProfile -Profile Domain,Public,Private | Where-Object { $_.Enabled -eq $true }).Count -gt 0
    }
    ConnectivityTests = @()
}

# Collect detailed disk information with expansion opportunities
foreach ($disk in Get-Disk) {
    $partitions = @(Get-Partition -DiskNumber $disk.Number -ErrorAction SilentlyContinue | ForEach-Object {
        $volume = Get-Volume -Partition $_ -ErrorAction SilentlyContinue

        $canExpand = $false
        $expandableGB = 0

        if ($volume -and $_.Type -ne 'Reserved') {
            $supportedSize = Get-PartitionSupportedSize -DiskNumber $disk.Number -PartitionNumber $_.PartitionNumber -ErrorAction SilentlyContinue
            if ($supportedSize) {
                $expandableBytes = $supportedSize.SizeMax - $_.Size
                if ($expandableBytes -gt 100MB) {
                    $canExpand = $true
                    $expandableGB = [math]::Round($expandableBytes / 1GB, 2)
                }
            }
        }

        @{
            Number = $_.PartitionNumber
            DriveLetter = $_.DriveLetter
            SizeGB = [math]::Round($_.Size / 1GB, 2)
            Type = $_.Type
            FileSystem = if ($volume) { $volume.FileSystem } else { $null }
            Label = if ($volume) { $volume.FileSystemLabel } else { $null }
            CanExpand = $canExpand
            ExpandableGB = $expandableGB
        }
    })

    $info.DiskDetailDISK DETAILS (with expansion info) ===" -ForegroundColor Cyan
    foreach ($disk in $info.DiskDetails) {
        Write-Host "--- Disk $($disk.Number): $($disk.FriendlyName) ---" -ForegroundColor Green
        Write-Host "  Size: $($disk.SizeGB) GB | Style: $($disk.PartitionStyle) | Status: $($disk.OperationalStatus)/$($disk.HealthStatus)"

        foreach ($partition in $disk.Partitions) {
            Write-Host "    Partition $($partition.Number): $($partition.DriveLetter) - $($partition.SizeGB) GB [$($partition.FileSystem)]" -ForegroundColor White
            if ($partition.CanExpand) {
                Write-Host "      → CAN EXPAND by $($partition.ExpandableGB) GB" -ForegroundColor Cyan
            } else {
                Write-Host "      → At maximum size" -ForegroundColor Gray
            }
        }
        Write-Host ""
    }

    Write-Host "=== USERS ===" -ForegroundColor Cyan
    $info.Users | Format-Table -AutoSize

    Write-Host "=== SERVICES ===" -ForegroundColor Cyan
    $info.Services | Format-List

    Write-Host "=== FEATURES ===" -ForegroundColor Cyan
    $info.Features | Format-List

    Write-Host "=== CONNECTIVITY TESTS ===" -ForegroundColor Cyan
    $allPingSuccess = ($info.ConnectivityTests | Where-Object { $_.Ping.Success -eq $true }).Count
    $testStatus = if ($allPingSuccess -eq $info.ConnectivityTests.Count) { "HEALTHY" } else { "DEGRADED" }
    Write-Host "Overall Status: $testStatus" -ForegroundColor $(if ($testStatus -eq 'HEALTHY') { 'Green' } else { 'Yellow' })
    Write-Host ""

    foreach ($test in $info.ConnectivityTests) {
        Write-Host "Target: $($test.Target)" -ForegroundColor White

        if ($test.Ping.Success) {
            Write-Host "  Ping: SUCCESS ($($test.Ping.ResponseTimeMs) ms)" -ForegroundColor Green
        } else {
            Write-Host "  Ping: FAILED - $($test.Ping.Error)" -ForegroundColor Red
        }

        if ($test.DNS) {
            if ($test.DNS.Success) {
                Write-Host "  DNS: SUCCESS ($($test.DNS.Addresses -join ', '))" -ForegroundColor Green
            } else {
                Write-Host "  DNS: FAILED - $($test.DNS.Error)" -ForegroundColor Red
            }
        }

        if ($test.HTTP) {
            if ($test.HTTP.Success) {
                Write-Host "  HTTP: SUCCESS ($($test.HTTP.Protocol) - $($test.HTTP.StatusCode))" -ForegroundColor Green
            } else {
                Write-Host "  HTTP: FAILED - $($test.HTTP.Error)" -ForegroundColor Red
            }
        }

        Write-Host ""
    }ine
        IsReadOnly = $disk.IsReadOnly
        Partitions = $partitions
    }
}

# Network connectivity tests
foreach ($target in $TestTargets) {
    $testResult = @{
        Target = $target
        Ping = $null
        DNS = $null
        HTTP = $null
    }

    # Ping test
    try {
        $ping = Test-Connection -ComputerName $target -Count 2 -ErrorAction Stop
        if ($ping) {
            $testResult.Ping = @{
                Success = $true
                ResponseTimeMs = [math]::Round(($ping | Measure-Object -Property ResponseTime -Average).Average, 2)
                PacketsReceived = $ping.Count
            }
        }
    } catch {
        $testResult.Ping = @{
            Success = $false
            Error = $_.Exception.Message
        }
    }

    # DNS resolution test (only for hostnames)
    if ($target -notmatch '^\d+\.\d+\.\d+\.\d+$') {
        try {
            $dnsResult = Resolve-DnsName -Name $target -ErrorAction Stop
            $testResult.DNS = @{
                Success = $true
                Addresses = @($dnsResult | Where-Object { $_.Type -eq 'A' } | Select-Object -ExpandProperty IPAddress)
            }
        } catch {
            $testResult.DNS = @{
                Success = $false
                Error = $_.Exception.Message
            }
        }

        # HTTP/HTTPS test (only for hostnames)
        try {
            $httpTest = Invoke-WebRequest -Uri "https://$target" -TimeoutSec 5 -UseBasicParsing -ErrorAction Stop
            $testResult.HTTP = @{
                Success = $true
                StatusCode = $httpTest.StatusCode
                Protocol = "HTTPS"
            }
        } catch {
            try {
                $httpTest = Invoke-WebRequest -Uri "http://$target" -TimeoutSec 5 -UseBasicParsing -ErrorAction Stop
                $testResult.HTTP = @{
                    Success = $true
                    StatusCode = $httpTest.StatusCode
                    Protocol = "HTTP"
                }
            } catch {
                $testResult.HTTP = @{
                    Success = $false
                    Error = "HTTP/HTTPS not reachable"
                }
            }
        }
    }

    $info.ConnectivityTests += $testResult
}

if ($Json) {
    $info | ConvertTo-Json -Depth 10
} else {
    Write-Host "=== SYSTEM INFORMATION ===" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Timestamp: $($info.Timestamp)" -ForegroundColor Yellow
    Write-Host "Hostname: $($info.Hostname)" -ForegroundColor Yellow
    Write-Host "FQDN: $($info.FQDN)" -ForegroundColor Yellow
    Write-Host ""

    Write-Host "=== OPERATING SYSTEM ===" -ForegroundColor Cyan
    $info.OS | Format-List

    Write-Host "=== HARDWARE ===" -ForegroundColor Cyan
    $info.Hardware | Format-List

    Write-Host "=== NETWORK ===" -ForegroundColor Cyan
    Write-Host "Adapters:" -ForegroundColor Yellow
    $info.Network.Adapters | Format-Table -AutoSize
    Write-Host "IP Addresses:" -ForegroundColor Yellow
    $info.Network.IPAddresses | Format-Table -AutoSize
    Write-Host "Default Gateway:" -ForegroundColor Yellow
    $info.Network.DefaultGateway | Format-Table -AutoSize
    Write-Host "DNS Servers:" -ForegroundColor Yellow
    $info.Network.DNS | Format-Table -AutoSize

    Write-Host "=== DISKS ===" -ForegroundColor Cyan
    $info.Disks | Format-Table -AutoSize

    Write-Host "=== VOLUMES ===" -ForegroundColor Cyan
    $info.Volumes | Format-Table -AutoSize

    Write-Host "=== USERS ===" -ForegroundColor Cyan
    $info.Users | Format-Table -AutoSize

    Write-Host "=== SERVICES ===" -ForegroundColor Cyan
    $info.Services | Format-List

    Write-Host "=== FEATURES ===" -ForegroundColor Cyan
    $info.Features | Format-List
}
