vm_iso_file = "AlmaLinux-9.5-x86_64-minimal.iso"
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

provisioning_scripts = [
  "scripts/common/rhel/01-update.sh",
  "scripts/common/rhel/02-packages.sh",
  "scripts/common/rhel/03-cleanup.sh"
]
