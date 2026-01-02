vm_virtio_iso_file = "virtio-win-0.1.204.iso"

vm_iso_file = "Win2012r2_9600.17050.WINBLUE_REFRESH.140317-1640_X64FRE_SERVER_EVAL_EN-US-IR3_SSS_X64FREE_EN-US_DV9.ISO"
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
winrm_username        = "Administrator"
winrm_password        = "REDACTED"
winrm_timeout         = "1h"
winrm_port            = "5985"
winrm_use_ssl         = false
winrm_insecure        = true

windows_image_index     = "2"

boot_command = [
  "<enter>"
]
