vm_iso_file = "Win10_22H2_English_x64v1.iso"
vm_id       = "7901"

template_name     = "windows-10-template"
template_hostname = "windows-10"

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

windows_image_index     = "6"

boot_command = [
  "<enter>"
]
