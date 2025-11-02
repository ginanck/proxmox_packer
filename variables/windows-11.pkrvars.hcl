vm_iso_file = "Win11_24H2_English_x64.iso"
vm_id       = "8201"

template_name     = "windows-11-template"
template_hostname = "windows-11"

vm_disk_size      = "40G"

vm_bios           = "ovmf"
vm_os             = "win11"
vm_cpu            = "2"
vm_sockets        = "1"
vm_ram            = "4096"
vm_disk_type      = "sata"
vm_nic_model      = "e1000"

boot_wait         = "5s"

communicator          = "winrm"
winrm_username        = "packer"
winrm_password        = "packer"
winrm_timeout         = "1h"
winrm_port            = "5985"
winrm_use_ssl         = false
winrm_insecure        = true

# Windows-specific settings
windows_image_index    = "6"  # 6 = Windows 11 Pro, 1 = Windows 11 Home
administrator_password = "REDACTED"
packer_user_password   = "packer"
ansible_user_password  = "ansible"

# Drive letter assignments (based on IDE device order in Proxmox)
unattend_cd_drive = "E:"
virtio_cd_drive   = "F:"

boot_command = [
  "<enter>"
]
