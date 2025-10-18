vm_iso_file = "ubuntu-24.04.1-live-server-amd64.iso"
vm_id       = "8053"

template_name     = "ubuntu-2404-template"
template_hostname = "ubuntu-2404"

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
  "scripts/common/debian/01-update.sh",
  "scripts/common/debian/02-packages.sh",
  "scripts/common/debian/03-cleanup.sh",
  "scripts/ubuntu-2404/04-grub.sh"
]
