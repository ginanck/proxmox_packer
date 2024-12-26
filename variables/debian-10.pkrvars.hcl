vm_iso_file = "debian-10.13.0-amd64-DVD-1.iso"
vm_id = "811"

template_name = "debian-10-template"
template_hostname = "debian-10"

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
