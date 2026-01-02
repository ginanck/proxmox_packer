vm_iso_file = "Win2016_Datacenter_EVAL_en-us_14393_refresh.ISO"
vm_id       = "7952"

template_name     = "windows-server-2016-template"
template_hostname = "windows-server-2016"

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
