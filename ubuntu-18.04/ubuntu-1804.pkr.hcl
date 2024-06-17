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
  default = "901"
}

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

variable "ssh_fullname" {
  type    = string
  default = "ubuntu"
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
  default = "helium"
}

variable "http_directory" {
  type    = string
  default = "http"
}

variable "http_bind_address" {
  type    = string
  default = "10.0.1.40"
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
  iso_file    = "${var.vm_storage_pool}:iso/${var.vm_iso_file}"
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
  unmount_iso           = true
  scsi_controller       = var.scsi_controller

  boot_command        = [
    "<esc><wait>",
    "<f6><wait><esc><wait>",
    "/install/vmlinuz ",
    "auto ",
    "locale=en_US ",
    "keyboard-configuration/layoutcode=us ",
    "netcfg/get_hostname=ubuntu-1804 ",
    "fb=false ",
    "debconf/frontend=noninteractive ",
    "preseed/url=http://{{ .HTTPIP }}:{{ .HTTPPort }}/preseed.cfg ",
    "initrd=/install/initrd.gz ",
    "console-setup/ask_detect=false ",
    "setup_bash_url=http://{{ .HTTPIP }}:{{ .HTTPPort }}/late_command.sh ",
    " -- <enter>"
  ]

  ssh_username      = var.ssh_username
  ssh_password      = var.ssh_password
  ssh_wait_timeout  = "60m"
  boot_wait         = "5s"
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
