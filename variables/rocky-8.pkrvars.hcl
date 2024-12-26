vm_iso_file = "Rocky-8.10-x86_64-minimal.iso"
vm_id = "821"

template_name = "rocky-8-template"
template_hostname = "rocky-8"

ssh_username = "rocky"
ssh_password = "rocky"

boot_command = [
    "<tab>",
    " inst.cmdline inst.nosave=all rd.live.check=0 inst.ks=http://{{ .HTTPIP }}:{{ .HTTPPort }}/ks.cfg ",
    " <enter><wait>"
]
