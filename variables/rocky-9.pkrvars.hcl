vm_iso_file = "Rocky-9.4-x86_64-dvd.iso"
vm_id = "822"

template_name = "rocky-9-template"
template_hostname = "rocky-9"

ssh_username = "rocky"
ssh_password = "rocky"

boot_command = [
    "<tab>",
    " inst.cmdline inst.nosave=all rd.live.check=0 inst.ks=http://{{ .HTTPIP }}:{{ .HTTPPort }}/ks.cfg ",
    " <enter><wait>"
]
