vm_iso_file = "AlmaLinux-10.0-x86_64-minimal.iso"
vm_id       = "8152"

template_name     = "alma-10-template"
template_hostname = "alma-10"

ssh_username = "alma"
ssh_password = "alma"

boot_command = [
  "e",
  "<down><down><end>",
  " inst.cmdline inst.nosave=all rd.live.check=0 inst.ks=http://{{ .HTTPIP }}:{{ .HTTPPort }}/ks.cfg",
  "<f10>"
]

provisioning_scripts = [
  "scripts/common/rhel/01-update.sh",
  "scripts/common/rhel-10/02-packages.sh",
  "scripts/common/rhel/03-cleanup.sh"
]
