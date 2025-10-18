vm_iso_file = "Rocky-10.0-x86_64-minimal.iso"
vm_id       = "8102"

template_name     = "rocky-10-template"
template_hostname = "rocky-10"

ssh_username = "rocky"
ssh_password = "rocky"

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
