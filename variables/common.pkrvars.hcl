proxmox_url = ""
proxmox_username = ""
proxmox_api_token = ""

locale = "en_US.UTF-8"

vm_cpu_type = "host"
vm_os = "l26"
vm_cpu = "2"
vm_sockets = "1"
vm_ram = "4096"
vm_scsi_controller = "virtio-scsi-single"
vm_disk_type = "virtio"
vm_disk_size = "10G"
vm_disk_cache = "writeback"
vm_disk_format = "qcow2"
vm_disk_io_thread = "false"
vm_disk_discard = "true"
vm_storage_pool = "data"
vm_nic_bridge = "vmbr1"
vm_nic_model = "virtio"
vm_nic_firewall = "false"

node_name = "oxygen"

http_bind_address = "10.50.0.2"
http_bind_port = "8080"

os_type = ""
os_version = ""

boot_wait = "10s"
task_timeout = "10m"
qemu_agent = true
ssh_wait_timeout = "30m"
