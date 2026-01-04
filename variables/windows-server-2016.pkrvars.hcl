vm_iso_file = "Win2016_Datacenter_EVAL_en-us_14393_refresh.ISO"
vm_id       = "7952"

template_name     = "windows-server-2016-template"
template_hostname = "windows-server-2016"

vm_disk_size      = "40G"

vm_bios           = "ovmf"
vm_os             = "win10"
vm_cpu            = "4"
vm_sockets        = "1"
vm_ram            = "8192"
vm_disk_type      = "sata"
vm_nic_model      = "e1000"

boot_wait         = "5s"

communicator          = "winrm"

windows_image_index     = "2"

boot_command = [
  "<enter>"
]
