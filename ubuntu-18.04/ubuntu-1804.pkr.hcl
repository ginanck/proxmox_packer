variable "proxmox_url" {
  type    = string
  default = ""
}

variable "proxmox_username" {
  type    = string
  default = ""
}

variable "proxmox_api_token" {
  type    = string
  default = ""
}

variable "template_name" {
  type    = string
  default = "ubuntu-1804-template"
}

variable "template_hostname" {
  type    = string
  default = "ubuntu-1804"
}

variable "locale" {
  type    = string
  default = "en_US.UTF-8"
}

variable "vm_cpu_type" {
  type    = string
  default = "host"
}

variable "vm_os" {
  type    = string
  default = "l26"
}

variable "vm_id" {
  type    = string
  default = "801"
}

# Download from (https://askubuntu.com/questions/1186183/how-do-i-obtain-the-debian-installer-for-ubuntu-server-18-04-3-lts)
# https://old-releases.ubuntu.com/releases/bionic/ubuntu-18.04.3-server-amd64.iso
# https://old-releases.ubuntu.com/releases/bionic/ubuntu-18.04.5-server-amd64.iso

# Ubuntu Server ISO images with debian-installer continue to be available, including for 18.04.3 LTS. There is no need to use media for an earlier point release. You most likely want ubuntu-18.04.3-server-amd64.iso, though other architectures are available.
# On the main download page, the Use the traditional installer link takes you to a section for the "Alternative Ubuntu Server installer." These are the non-live ISO images for Ubuntu Server that use debian-installer (as Ubuntu Server has used exclusively for most of its history). This is in contrast to the more recently introduced live server images, which use curtin.
# The link there for 18.04.3 LTS takes you to http://cdimage.ubuntu.com/releases/18.04.3/release/. The alternative server ISOs have names like ubuntu-18.04.3-server-arm64.iso; this indicates they use debian-installer. This is in contrast to the server ISOs offered at http://releases.ubuntu.com/18.04.3/, which have names like ubuntu-18.04.3-live-server-amd64.iso and use curtin.
# http://cdimage.ubuntu.com/releases/18.04.3/release/ has other architectures, .torrent and .jigdo files (including for the alternative server ISO), the preinstalled images, and manifest and checksum files for everything offered there.

variable "vm_iso_file" {
  type    = string
  default = "ubuntu-18.04.3-server-amd64.iso"
}

variable "vm_cpu" {
  type    = string
  default = "2"
}

variable "vm_sockets" {
  type    = string
  default = "1"
}

variable "vm_ram" {
  type    = string
  default = "4096"
}

variable "scsi_controller" {
  type    = string
  default = "virtio-scsi-single"
}

variable "vm_disk_type" {
  type    = string
  default = "virtio"
}

variable "vm_disk_size" {
  type    = string
  default = "10G"
}

variable "vm_disk_cache" {
  type    = string
  default = "writeback"
}

variable "vm_disk_format" {
  type    = string
  default = "qcow2"
}

variable "vm_disk_io_thread" {
  type    = string
  default = "false"
}

variable "vm_disk_discard" {
  type    = string
  default = "true"
}

variable "vm_storage_pool" {
  type    = string
  default = "data"
}

variable "vm_nic_bridge" {
  type    = string
  default = "vmbr1"
}

variable "vm_nic_model" {
  type    = string
  default = "virtio"
}

variable "vm_nic_firewall" {
  type    = string
  default = "false"
}

variable "ssh_username" {
  type    = string
  default = "ubuntu"
}

variable "ssh_password" {
  type    = string
  default = "ubuntu"
}

variable "node_name" {
  type    = string
  default = "oxygen"
}

variable "http_directory" {
  type    = string
  default = "http"
}

variable "http_bind_address" {
  type    = string
  default = "10.18.23.2"
}

variable "http_bind_port" {
  type    = string
  default = "8080"
}

source "proxmox-iso" "ubuntu-cloud-init" {
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
    type      = "scsi"
    iso_file  = "${var.vm_storage_pool}:iso/${var.vm_iso_file}"
    unmount   = true
  }

  disks {
    type          = var.vm_disk_type
    disk_size     = var.vm_disk_size
    cache_mode    = var.vm_disk_cache
    format        = var.vm_disk_format
    io_thread     = var.vm_disk_io_thread
    discard       = var.vm_disk_discard
    storage_pool  = var.vm_storage_pool
  }

  network_adapters {
    bridge      = var.vm_nic_bridge
    model       = var.vm_nic_model
    firewall    = var.vm_nic_firewall
  }

  http_directory          = var.http_directory
  http_bind_address       = var.http_bind_address
  http_port_min           = var.http_bind_port
  http_port_max           = var.http_bind_port
  cloud_init              = true
  cloud_init_storage_pool = var.vm_storage_pool

  insecure_skip_tls_verify = true

  template_description  = "${var.template_name}, generated on ${timestamp()}"
  template_name         = var.template_name
  scsi_controller       = var.scsi_controller

  boot_command        = [
    "<esc><wait>",
    "<f6><wait><esc><wait>",
    "install auto=true priority=critical url=http://{{ .HTTPIP }}:{{ .HTTPPort }}/preseed.cfg debian-installer/locale=en_US keyboard-configuration/layoutcode=us languagechooser/language-name=English",
    "<enter>"
  ]

  ssh_username      = var.ssh_username
  ssh_password      = var.ssh_password
  ssh_wait_timeout  = "30m"
  boot_wait         = "10s"
  task_timeout      = "10m"
  qemu_agent        = true
}

build {
  sources = [
    "source.proxmox-iso.ubuntu-cloud-init"
  ]

  provisioner "shell" {
    inline = [
      "echo Inline Shell Expected Result"
    ]
    expect_disconnect = true
    valid_exit_codes  = [0, 2300218]
  }
}
