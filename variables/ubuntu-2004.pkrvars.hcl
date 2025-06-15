vm_iso_file = "ubuntu-20.04.5-live-server-amd64.iso"
vm_id = "8051"

template_name = "ubuntu-2004-template"
template_hostname = "ubuntu-2004"

ssh_username = "ubuntu"
ssh_password = "ubuntu"

boot_wait = "5s"

boot_command = [
    "<esc><wait><esc><wait><f6><wait><esc><wait>",
    " autoinstall ds=nocloud-net;s=http://{{ .HTTPIP }}:{{ .HTTPPort }}/",
    " locale=en_US",
    " keyboard-configuration/layoutcode=us",
    " fsck.mode=skip",
    "<enter><wait>"
]

provisioning_scripts = [
  "scripts/common/debian/01-update.sh",
  "scripts/common/debian/02-packages.sh",
  "scripts/common/debian/03-cleanup.sh",
  "scripts/ubuntu-2004/04-grub.sh"
]
