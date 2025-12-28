vm_iso_file = "Windows_Server_2012R2_Eval.iso"
vm_id       = "7951"

template_name     = "windows-server-2012r2-template"
template_hostname = "windows-server-2012r2"

vm_disk_size      = "40G"

vm_bios           = "ovmf"
vm_os             = "win8"
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

windows_image_index     = "2"
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
