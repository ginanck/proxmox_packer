vm_iso_file = "Win10_22H2_English_x64v1.iso"
vm_id       = "8202"

template_name     = "windows-10-template"
template_hostname = "windows-10"

vm_disk_size      = "40G"

vm_bios           = "ovmf"
vm_os             = "win10"
vm_cpu            = "2"
vm_sockets        = "1"
vm_ram            = "4096"
vm_disk_type      = "sata"
vm_nic_model      = "e1000"

boot_wait         = "5s"

communicator          = "winrm"
winrm_username        = "ansible"
winrm_password        = "ansible"
winrm_timeout         = "1h"
winrm_port            = "5985"
winrm_use_ssl         = false
winrm_insecure        = true

windows_image_index     = "6"
win_iso_unattend_drive  = "E:"
win_iso_virtio_drive    = "F:"

boot_command = [
  "<enter>"
]

provisioning_scripts = [
  "scripts/common/windows/Install-CloudBase.ps1",
  "scripts/common/windows/Install-Chocolatey.ps1",
  "scripts/common/windows/Install-Python.ps1",
  "scripts/common/windows/Enable-Security.ps1",
  "scripts/common/windows/Run-Sysprep.ps1"
]
