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

variable "locale" {}
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
variable "vm_id" {}

variable boot_wait {}
variable task_timeout {}
variable qemu_agent {}
variable ssh_wait_timeout {}

variable "template_name" {}
variable "template_hostname" {}

variable "ssh_username" {}
variable "ssh_password" {}

variable "node_name" {}

variable "http_bind_address" {}
variable "http_port_min" {}
variable "http_port_max" {}

variable "os_type" {}
variable "os_version" {}

variable "provisioning_scripts" {
  type        = list(string)
  description = "List of scripts to run during provisioning"
}

source "proxmox-iso" "proxmox-vm-linux" {
  proxmox_url = var.proxmox_url
  username    = var.proxmox_username
  token       = var.proxmox_api_token
  node        = var.node_name
  memory      = var.vm_ram
  cores       = var.vm_cpu
  cpu_type    = var.vm_cpu_type
  os          = var.vm_os
  sockets     = var.vm_sockets
  vm_id       = var.vm_id

  boot_iso {
    type     = "scsi"
    iso_file = "${var.vm_storage_pool}:iso/${var.vm_iso_file}"
    unmount  = true
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

  http_directory          = "files/${var.os_type}-${var.os_version}"
  http_bind_address       = var.http_bind_address
  cloud_init              = true
  cloud_init_storage_pool = var.vm_storage_pool

  insecure_skip_tls_verify = true

  template_description = "${var.template_name}, generated on ${timestamp()}"
  template_name        = var.template_name
  scsi_controller      = var.vm_scsi_controller

  boot_command = var.boot_command

  ssh_username     = var.ssh_username
  ssh_password     = var.ssh_password
  ssh_wait_timeout = var.ssh_wait_timeout
  boot_wait        = var.boot_wait
  task_timeout     = var.task_timeout
  qemu_agent       = var.qemu_agent
}

build {
  name = "${var.template_name}"
  sources = [
    "source.proxmox-iso.proxmox-vm-linux"
  ]

  provisioner "shell" {
    inline = [
      "echo Running provisioner for ${var.os_type}-${var.os_version}"
    ]
    expect_disconnect = true
    valid_exit_codes  = [0, 2300218]
  }

  provisioner "shell" {
    scripts           = var.provisioning_scripts
    expect_disconnect = true
    valid_exit_codes  = [0, 2300218]
    execute_command   = "sudo -S bash '{{.Path}}'"
  }
}
