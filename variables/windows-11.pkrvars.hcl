vm_iso_file = "Win11_25H2_English_x64.iso"
vm_id       = "7902"

template_name     = "windows-11-template"
template_hostname = "windows-11"

vm_disk_size      = "40G"

vm_bios           = "ovmf"
vm_os             = "win11"
vm_cpu            = "4"
vm_sockets        = "1"
vm_ram            = "8192"
vm_disk_type      = "sata"
vm_nic_model      = "e1000"

boot_wait         = "5s"

communicator          = "winrm"

windows_image_index     = "6"

boot_command = [
  "<enter>"
]
