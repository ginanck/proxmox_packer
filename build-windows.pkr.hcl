packer {
  required_plugins {
    proxmox = {
      version = ">= 1.2.3"
      source  = "github.com/hashicorp/proxmox"
    }
  }
}

variable "proxmox_url" {}
variable "proxmox_username" {}
variable "proxmox_api_token" {}

variable "boot_command" {
  type = list(string)
}

variable "vm_cpu_type" {}
variable "vm_bios" {}
variable "vm_os" {}
variable "vm_cpu" {}
variable "vm_sockets" {}
variable "vm_ram" {}
variable "vm_scsi_controller" {}
variable "vm_disk_type" {}
variable "vm_disk_size" {}
variable "vm_disk_cache" {}
variable "vm_disk_format" {}
variable "vm_disk_io_thread" {}
variable "vm_disk_discard" {}
variable "vm_storage_pool" {}
variable "vm_nic_bridge" {}
variable "vm_nic_model" {}
variable "vm_nic_firewall" {}
variable "vm_iso_file" {}
variable "vm_virtio_iso_file" {}
variable "vm_id" {}

variable boot_wait {}
variable task_timeout {}
variable qemu_agent {}
variable ssh_wait_timeout {}

variable "template_name" {}
variable "template_hostname" {}

variable "communicator" {}
variable "winrm_username" {}
variable "winrm_password" {}
variable "winrm_timeout" {}
variable "winrm_port" {}
variable "winrm_use_ssl" {}
variable "winrm_insecure" {}

variable "node_name" {}

variable "http_bind_address" {}
variable "http_port_min" {}
variable "http_port_max" {}

variable "os_type" {}
variable "os_version" {}

# Windows-specific variables
variable "windows_image_index" {}

source "proxmox-iso" "proxmox-vm-windows" {
  proxmox_url = var.proxmox_url
  username    = var.proxmox_username
  token       = var.proxmox_api_token
  node        = var.node_name
  memory      = var.vm_ram
  cores       = var.vm_cpu
  cpu_type    = var.vm_cpu_type
  os          = var.vm_os
  bios        = var.vm_bios
  sockets     = var.vm_sockets
  vm_id       = var.vm_id

  boot_iso {
    type     = "ide"
    iso_file = "${var.vm_storage_pool}:iso/${var.vm_iso_file}"
    unmount  = true
  }

  additional_iso_files {
    type = "ide"
    cd_content = {
      "AutoUnattend.xml" = templatefile(
        "${path.root}/files/${var.os_type}-${var.os_version}/AutoUnattend.xml.pkrtpl.hcl",
        {
          windows_image_index            = var.windows_image_index
          win_administrator_password     = var.winrm_password
        }
      )
      "Setup-VirtIO.ps1"              = file("${path.root}/scripts/windows/build/Setup-VirtIO.ps1")
      "Setup-WinRM.ps1"               = file("${path.root}/scripts/windows/build/Setup-WinRM.ps1")
      "cloudbase-init.conf"           = file("${path.root}/files/common/windows/cloudbase-init.conf")
      "cloudbase-init-unattend.conf"  = file("${path.root}/files/common/windows/cloudbase-init-unattend.conf")
      "RedHat.cer"                    = file("${path.root}/files/common/windows/RedHat.cer")
    }
    cd_label = "UNATTEND"
    iso_storage_pool = var.vm_storage_pool
    unmount = true
  }

  additional_iso_files {
    type = "sata"
    iso_file = "${var.vm_storage_pool}:iso/${var.vm_virtio_iso_file}"
    unmount = true
  }

  efi_config {
    efi_storage_pool  = var.vm_storage_pool
    efi_type          = "4m"
    efi_format        = var.vm_disk_format
    pre_enrolled_keys = true
  }

  disks {
    type         = var.vm_disk_type
    disk_size    = var.vm_disk_size
    cache_mode   = var.vm_disk_cache
    format       = var.vm_disk_format
    io_thread    = var.vm_disk_io_thread
    discard      = var.vm_disk_discard
    storage_pool = var.vm_storage_pool
  }

  network_adapters {
    bridge   = var.vm_nic_bridge
    model    = var.vm_nic_model
    firewall = var.vm_nic_firewall
  }

  cloud_init              = true
  cloud_init_storage_pool = var.vm_storage_pool

  insecure_skip_tls_verify = true

  template_description = "${var.template_name}, generated on ${timestamp()}"
  template_name        = var.template_name
  scsi_controller      = var.vm_scsi_controller

  boot_command = var.boot_command

  communicator          = var.communicator
  winrm_username        = var.winrm_username
  winrm_password        = var.winrm_password
  winrm_timeout         = var.winrm_timeout
  winrm_port            = var.winrm_port
  winrm_use_ssl         = var.winrm_use_ssl
  winrm_insecure        = var.winrm_insecure

  boot_wait        = var.boot_wait
  task_timeout     = var.task_timeout
  qemu_agent       = var.qemu_agent
}

build {
  name = "${var.template_name}"
  sources = [
    "source.proxmox-iso.proxmox-vm-windows"
  ]

  # Phase 1: Prepare build environment (disable security, configure admin, enable RDP)
  provisioner "powershell" {
    scripts = [
      "${path.root}/scripts/windows/build/Build-ManageSecurity.ps1",
      "${path.root}/scripts/windows/build/Setup-EnableAdministrator.ps1",
      "${path.root}/scripts/windows/build/Setup-EnableRDP.ps1"
    ]
    environment_vars = [
      "SECURITY_ACTION=Disable"
    ]
    execution_policy = "Bypass"
  }

  # Phase 2: Install required software (Cloudbase-Init creates directories)
  provisioner "powershell" {
    scripts = [
      "${path.root}/scripts/windows/build/Build-InstallCloudbase.ps1",
      "${path.root}/scripts/windows/build/Build-InstallChocolatey.ps1"
    ]
    execution_policy = "Bypass"
  }

  # Phase 3: Deploy runtime and first-boot scripts (after Cloudbase-Init is installed)
  provisioner "file" {
    source      = "${path.root}/scripts/windows/terraform-callable/"
    destination = "C:\\Program Files\\Cloudbase Solutions\\Cloudbase-Init\\pc2_scripts\\"
    pause_before = "30s"
  }

  # LocalScripts run in alphabetical order - 01 runs before 02
  provisioner "file" {
    source      = "${path.root}/scripts/windows/build/01-CloudInit-RelocateCDROM.ps1"
    destination = "C:\\Program Files\\Cloudbase Solutions\\Cloudbase-Init\\LocalScripts\\01-CloudInit-RelocateCDROM.ps1"
  }

  provisioner "file" {
    source      = "${path.root}/scripts/windows/build/02-CloudInit-DiskManagement.ps1"
    destination = "C:\\Program Files\\Cloudbase Solutions\\Cloudbase-Init\\LocalScripts\\02-CloudInit-DiskManagement.ps1"
  }

  # Phase 4: Finalize and generalize template (re-enable security, run sysprep)
  provisioner "powershell" {
    scripts = [
      "${path.root}/scripts/windows/build/Build-ManageSecurity.ps1",
      "${path.root}/scripts/windows/build/Build-RunSysprep.ps1"
    ]
    environment_vars = [
      "SECURITY_ACTION=Enable"
    ]
    execution_policy = "Bypass"
  }

}
