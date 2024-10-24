vm_iso_file = "AlmaLinux-9.4-x86_64-dvd.iso"
vm_id = "832"

template_name = "alma-9-template"
template_hostname = "alma-9"

ssh_username = "alma"
ssh_password = "alma"

boot_command = [
    "<tab>",
    " inst.cmdline inst.nosave=all rd.live.check=0 inst.ks=http://{{ .HTTPIP }}:{{ .HTTPPort }}/ks.cfg ",
    " <enter><wait>"
]
