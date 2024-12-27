vm_iso_file = "ubuntu-20.04.6-live-server-amd64.iso"
vm_id = "802"

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
  "scripts/debian-based/01-update.sh",
  "scripts/debian-based/02-packages.sh",
  "scripts/debian-based/03-cleanup.sh"
]
