vm_iso_file = "ubuntu-22.04.5-live-server-amd64.iso"
vm_id = "803"

template_name = "ubuntu-2204-template"
template_hostname = "ubuntu-2204"

ssh_username = "ubuntu"
ssh_password = "ubuntu"

boot_command = [
    "<spacebar><wait><spacebar><wait><spacebar><wait><spacebar><wait><spacebar><wait>",
    "e<wait>",
    "<down><down><down><end>",
    " autoinstall ds=nocloud\\;s=http://{{ .HTTPIP }}:{{ .HTTPPort }}/",
    " locale=en_US",
    " keyboard-configuration/layoutcode=us",
    " fsck.mode=skip",
    "<f10>"
]

provisioning_scripts = [
  "scripts/debian-based/01-update.sh",
  "scripts/debian-based/02-packages.sh",
  "scripts/debian-based/03-cleanup.sh"
]
