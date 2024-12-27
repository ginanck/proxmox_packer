vm_iso_file = "AlmaLinux-8.10-x86_64-minimal.iso"
vm_id = "831"

template_name = "alma-8-template"
template_hostname = "alma-8"

ssh_username = "alma"
ssh_password = "alma"

boot_command = [
    "<tab>",
    " inst.cmdline inst.nosave=all rd.live.check=0 inst.ks=http://{{ .HTTPIP }}:{{ .HTTPPort }}/ks.cfg ",
    " <enter><wait>"
]

provisioning_scripts = [
  "scripts/rhel-based/01-update.sh",
  "scripts/rhel-based/02-packages.sh",
  "scripts/rhel-based/03-cleanup.sh"
]
