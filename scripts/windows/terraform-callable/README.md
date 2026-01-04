# Runtime Scripts Library

This directory contains PowerShell scripts that are embedded into the Windows template during Packer build and can be executed from Terraform using WinRM provisioners.

## 📂 Script Location in Template

All scripts are stored in: `C:\Program Files\Cloudbase Solutions\Cloudbase-Init\pc2_scripts\`

## ⚠️ Important Notes

- **RDP is enabled by default** during Packer build via `Setup-EnableRDP.ps1`
- **Administrator account** is configured during build and password set via Terraform cloud-init
- **User management** uses AWS-style approach: Administrator + `init_username` from Terraform
- **Disk management** happens automatically via LocalScripts on first boot, but can be triggered manually from Terraform

## 📋 Available Scripts (3 scripts)

### 1. **Runtime-ManageDisks.ps1**
Initialize new disks and extend existing volumes without rebooting.

**Usage from Terraform:**
```hcl
resource "null_resource" "extend_disks" {
  depends_on = [proxmox_virtual_environment_vm.vm]

  connection {
    type     = "winrm"
    host     = "172.16.2.19"
    user     = "Administrator"
    password = var.admin_password
    port     = 5985
    https    = false
    insecure = true
  }

  provisioner "remote-exec" {
    inline = [
      "powershell.exe -ExecutionPolicy Bypass -File 'C:\\Program Files\\Cloudbase Solutions\\Cloudbase-Init\\pc2_scripts\\Runtime-ManageDisks.ps1'"
    ]
  }
}
```

**Parameters:**
- `-ExtendOnly` - Only extend existing volumes
- `-InitializeOnly` - Only initialize new disks
- `-DriveLetter "C"` - Only extend specific drive

**Examples:**
```powershell
# Extend all volumes and initialize new disks (default)
.\Runtime-ManageDisks.ps1

# Only extend existing volumes
.\Runtime-ManageDisks.ps1 -ExtendOnly

# Only initialize new disks
.\Runtime-ManageDisks.ps1 -InitializeOnly

# Only extend C: drive
.\Runtime-ManageDisks.ps1 -DriveLetter "C"
```

---

### 2. **Runtime-GetSystemInfo.ps1**
Collect comprehensive system diagnostics including disk status and network connectivity tests.

**What's included:**
- System information (OS, hardware, uptime)
- Detailed disk status with expansion opportunities
- Volume information
- Network configuration
- Connectivity tests (ping, DNS, HTTP/HTTPS)
- User accounts
- Service status
- Security features

**Usage from Terraform:**
```hcl
resource "null_resource" "get_info" {
  connection {
    type     = "winrm"
    host     = "172.16.2.19"
    user     = "Administrator"
    password = var.admin_password
    port     = 5985
    https    = false
    insecure = true
  }

  provisioner "remote-exec" {
    inline = [
      "powershell.exe -ExecutionPolicy Bypass -File 'C:\\Program Files\\Cloudbase Solutions\\Cloudbase-Init\\pc2_scripts\\Runtime-GetSystemInfo.ps1'"
    ]
  }
}
```

**Parameters:**
- `-Json` - Output as JSON (for Terraform data source)
- `-TestTargets` - Array of targets to test connectivity (default: "8.8.8.8", "1.1.1.1", "google.com")

**Examples:**
```powershell
# Human-readable output with default connectivity tests
.\Runtime-GetSystemInfo.ps1

# JSON output
.\Runtime-GetSystemInfo.ps1 -Json

# Custom connectivity tests
.\Runtime-GetSystemInfo.ps1 -TestTargets "192.168.1.1","google.com","github.com"
```

---

### 3. **Runtime-RepairCloudbase.ps1**
Reset and repair Cloudbase-Init service.

**Usage from Terraform:**
```hcl
resource "null_resource" "repair_cloudbase" {
  connection {
    type     = "winrm"
    host     = "172.16.2.19"
    user     = "Administrator"
    password = var.admin_password
    port     = 5985
    https    = false
    insecure = true
  }

  provisioner "remote-exec" {
    inline = [
      "powershell.exe -ExecutionPolicy Bypass -File 'C:\\Program Files\\Cloudbase Solutions\\Cloudbase-Init\\pc2_scripts\\Runtime-RepairCloudbase.ps1'"
    ]
  }
}
```

**Parameters:**
- `-RestartOnly` - Only restart service without clearing state

**Examples:**
```powershell
# Full repair (clear state + restart)
.\Runtime-RepairCloudbase.ps1

# Just restart service
.\Runtime-RepairCloudbase.ps1 -RestartOnly
```

---

## 🚀 Complete Terraform Example

Here's a complete example showing how to use these scripts in a Terraform module:

```hcl
# main.tf
module "windows_vm" {
  source = "../../base"

  name        = "win-server-01"
  vm_id       = 200
  clone_vm_id = 7901  # Windows 10 template

  init_username = "gkorkmaz"
  init_password = var.user_password

  disk_size = 120
  disk_additional = [
    { size = 200, interface = "sata1" }
  ]

  is_windows = true
  win_admin_user     = "Administrator"
  win_admin_password = var.admin_password
}

# Wait for VM to be ready
resource "time_sleep" "wait_for_boot" {
  depends_on = [module.windows_vm]
  create_duration = "60s"
}

# Initialize and extend disks
resource "null_resource" "configure_disks" {
  depends_on = [time_sleep.wait_for_boot]

  connection {
    type     = "winrm"
    host     = split("/", module.windows_vm.ip_address)[0]
    user     = "Administrator"
    password = var.admin_password
    port     = 5985
    https    = false
    insecure = true
  }

  provisioner "remote-exec" {
    inline = [
      "powershell.exe -ExecutionPolicy Bypass -File 'C:\\Program Files\\Cloudbase Solutions\\Cloudbase-Init\\pc2_scripts\\Apply-DiskManagement.ps1'"
    ]
  }
}

# Create application user
resource "null_resource" "create_app_user" {
  depends_on = [time_sleep.wait_for_boot]

  connection {
    type     = "winrm"
    host     = split("/", module.windows_vm.ip_address)[0]
    user     = "Administrator"
    password = var.admin_password
    port     = 5985
    https    = false
    insecure = true
  }

  provisioner "remote-exec" {
    inline = [
      "powershell.exe -ExecutionPolicy Bypass -File 'C:\\Program Files\\Cloudbase Solutions\\Cloudbase-Init\\pc2_scripts\\Apply-UserManagement.ps1' -Username '${var.app_username}' -Password '${var.app_password}' -Groups 'Administrators','Remote Desktop Users'"
    ]
  }
}

# Test connectivity
resource "null_resource" "test_network" {
  depends_on = [module.windows_vm]

  connection {
    type     = "winrm"
    host     = split("/", module.windows_vm.ip_address)[0]
    user     = "Administrator"
    password = var.admin_password
    port     = 5985
    https    = false
    insecure = true
  }

  provisioner "remote-exec" {
    inline = [
      "powershell.exe -ExecutionPolicy Bypass -File 'C:\\Program Files\\Cloudbase Solutions\\Cloudbase-Init\\pc2_scripts\\Test-Connectivity.ps1'"
    ]
  }
}

# Get system information
output "vm_system_info" {
  value = "Run Get-SystemInfo.ps1 on the VM to see full details"
}
```

---

## 📝 Notes

1. **All scripts are already in the template** - No need to upload them from Terraform
2. **Scripts output JSON** when called with `-Json` parameter for easier parsing
3. **Log files** are created in `C:\Windows\Temp\` with timestamps
4. **Scripts are idempotent** - Can be run multiple times safely
5. **Error handling** - Scripts provide detailed error mes:

```hcl
# main.tf
module "windows_vm" {
  source = "../../base"

  name        = "win-server-01"
  vm_id       = 200
  clone_vm_id = 7901  # Windows 10 template

  init_username = "gkorkmaz"
  init_password = var.user_password

  disk_size = 120
  disk_additional = [
    { size = 200, interface = "sata1" }
  ]

  is_windows = true
  win_admin_user     = "Administrator"
  win_admin_password = var.admin_password
}

# Wait for VM to be ready
resource "time_sleep" "wait_for_boot" {
  depends_on = [module.windows_vm]
  create_duration = "90s"  # Allow time for CloudInit to run
}

# Manually trigger disk management if needed (optional - LocalScript handles this on boot)
resource "null_resource" "extend_disks" {
  depends_on = [time_sleep.wait_for_boot]

  connection {
    type     = "winrm"
    host     = split("/", module.windows_vm.ip_address)[0]
    user     = "Administrator"
    password = var.admin_password
    port     = 5985
    https    = false
    insecure = true
  }

  provisioner "remote-exec" {
    inline = [
      "powershell.exe -ExecutionPolicy Bypass -File 'C:\\Program Files\\Cloudbase Solutions\\Cloudbase-Init\\pc2_scripts\\Apply-DiskManagement.ps1'"
    ]
  }
}

# Get system information
resource "null_resource" "system_diagnostics" {
  depends_on = [time_sleep.wait_for_boot]

  connection {
    type     = "winrm"
    host     = split("/", module.windows_vm.ip_address)[0]
    user     = "Administrator"
    password = var.admin_password
    port     = 5985
    https    = false
    insecure = true
  }

  provisioner "remote-exec" {
    inline = [
      "powershell.exe -ExecutionPolicy Bypass -File 'C:\\Program Files\\Cloudbase Solutions\\Cloudbase-Init\\pc2_scripts\\Get-SystemInfo.ps1'"
    ]
  }
}
```

---

## 📝 Notes

1. **All scripts are already in the template** - No need to upload them from Terraform
2. **Scripts output JSON** when called with `-Json` parameter for easier parsing
3. **Log files** are created in `C:\Windows\Temp\` with timestamps
4. **Scripts are idempotent** - Can be run multiple times safely
5. **Error handling** - Scripts provide detailed error messages and exit codes
6. **Automatic disk management** - LocalScripts handle disk initialization on first boot
7. **User creation** - Handled by CloudInit LocalScript using `init_username` from Terraform

---

## 🔧 Disk Management Strategy

### Automatic (Recommended)
On first boot, LocalScript automatically:
1. Initializes new/unformatted disks
2. Extends existing volumes to match disk size
3. Assigns drive letters

**No Terraform action needed** - just add disks in Terraform config and boot the VM.

### Manual (When Needed)
If you resize disks after deployment or need to re-run disk management:
```hcl
resource "null_resource" "manual_disk_extend" {
  connection { ... }
  provisioner "remote-exec" {
    inline = [
      "powershell.exe -ExecutionPolicy Bypass -File 'C:\\Program Files\\Cloudbase Solutions\\Cloudbase-Init\\pc2_scripts\\Apply-DiskManagement.ps1'"
    ]
  }
}
```

---

## 👤 User Management Strategy (AWS-Style)

### Build Time
- **ansible** user: Created during Packer build for WinRM access (removed after sysprep)
- **Administrator**: Enabled, password set by CloudInit from Terraform

### Runtime (CloudInit LocalScript)
- Reads `init_username` and `init_password` from Terraform cloud-init metadata
- Creates user with Administrator + RDP access
- Result: 2 users after deployment:
  - **Administrator** (from Terraform `init_password`)
  - **{init_username}** (from Terraform `init_username` + `init_password`)

Example Terraform:
```hcl
module "windows_vm" {
  source = "../../base"

  init_username = "gkorkmaz"     # Creates this user
  init_password = "SecurePass!"  # Password for both Admin & gkorkmaz

  win_admin_user     = "Administrator"
  win_admin_password = "SecurePass!"  # Same password
}
```
