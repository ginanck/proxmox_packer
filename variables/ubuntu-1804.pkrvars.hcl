# Download from (https://askubuntu.com/questions/1186183/how-do-i-obtain-the-debian-installer-for-ubuntu-server-18-04-3-lts)
# https://old-releases.ubuntu.com/releases/bionic/ubuntu-18.04.3-server-amd64.iso
# https://old-releases.ubuntu.com/releases/bionic/ubuntu-18.04.5-server-amd64.iso

# Ubuntu Server ISO images with debian-installer continue to be available, including for 18.04.3 LTS. There is no need to use media for an earlier point release. You most likely want ubuntu-18.04.3-server-amd64.iso, though other architectures are available.
# On the main download page, the Use the traditional installer link takes you to a section for the "Alternative Ubuntu Server installer." These are the non-live ISO images for Ubuntu Server that use debian-installer (as Ubuntu Server has used exclusively for most of its history). This is in contrast to the more recently introduced live server images, which use curtin.
# The link there for 18.04.3 LTS takes you to http://cdimage.ubuntu.com/releases/18.04.3/release/. The alternative server ISOs have names like ubuntu-18.04.3-server-arm64.iso; this indicates they use debian-installer. This is in contrast to the server ISOs offered at http://releases.ubuntu.com/18.04.3/, which have names like ubuntu-18.04.3-live-server-amd64.iso and use curtin.
# http://cdimage.ubuntu.com/releases/18.04.3/release/ has other architectures, .torrent and .jigdo files (including for the alternative server ISO), the preinstalled images, and manifest and checksum files for everything offered there.

vm_iso_file = "ubuntu-18.04.3-server-amd64.iso"
vm_id = "8050"

template_name = "ubuntu-1804-template"
template_hostname = "ubuntu-1804"

ssh_username = "ubuntu"
ssh_password = "ubuntu"

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
  "scripts/ubuntu-1804/02-packages.sh",
  "scripts/common/debian/03-cleanup.sh",
  "scripts/ubuntu-1804/04-grub.sh"
]
