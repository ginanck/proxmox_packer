vm_iso_file = "AlmaLinux-8.10-x86_64-minimal.iso"
vm_id       = "8150"

template_name     = "alma-8-template"
template_hostname = "alma-8"

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
