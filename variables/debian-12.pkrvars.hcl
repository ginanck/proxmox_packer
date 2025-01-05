vm_iso_file = "debian-12.8.0-amd64-DVD-1.iso"
vm_id = "8002"

template_name = "debian-12-template"
template_hostname = "debian-12"

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
  "scripts/common/debian/01-update.sh",
  "scripts/common/debian/02-packages.sh",
  "scripts/common/debian/03-cleanup.sh"
]
