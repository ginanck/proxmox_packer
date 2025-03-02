#!/bin/bash

sed -i 's/^GRUB_DEFAULT=.*$/GRUB_DEFAULT="0"/' /etc/default/grub
sed -i 's/^GRUB_TIMEOUT_STYLE=.*$/GRUB_TIMEOUT_STYLE="hidden"/' /etc/default/grub
sed -i 's/^GRUB_TIMEOUT=.*$/GRUB_TIMEOUT="2"/' /etc/default/grub
sed -i 's/^GRUB_DISTRIBUTOR=.*$/GRUB_DISTRIBUTOR="`( . /etc/os-release; echo ${NAME:-Ubuntu} ) 2>/dev/null || echo Ubuntu`"/' /etc/default/grub
sed -i 's/^GRUB_CMDLINE_LINUX_DEFAULT=.*$/GRUB_CMDLINE_LINUX_DEFAULT=""/' /etc/default/grub
sed -i 's/^GRUB_CMDLINE_LINUX=.*$/GRUB_CMDLINE_LINUX=""/' /etc/default/grub
update-grub