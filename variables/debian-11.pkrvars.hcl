vm_iso_file = "debian-11.11.0-amd64-DVD-1.iso"
vm_id = "8001"

template_name = "debian-11-template"
template_hostname = "debian-11"

ssh_username = "debian"
ssh_password = "debian"

boot_command = [
    "<esc><wait>",
    "<f6><wait><esc><wait>",
    "install auto=true priority=critical url=http://{{ .HTTPIP }}:{{ .HTTPPort }}/preseed.cfg ",
    "debian-installer/locale=en_US ",
    "keyboard-configuration/layoutcode=us ",
    "languagechooser/language-name=English ",
    "<enter>"
]

provisioning_scripts = [
  "scripts/debian/01-update.sh",
  "scripts/common/debian/02-packages.sh",
  "scripts/common/debian/03-cleanup.sh",
  "scripts/debian-11/04-set-hostname.sh"
]