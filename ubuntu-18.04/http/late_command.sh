#!/bin/bash

echo 'ubuntu ALL=(ALL) NOPASSWD: ALL' > /target/etc/sudoers.d/ubuntu
chmod 440 /target/etc/sudoers.d/ubuntu

sed -i 's/^#PasswordAuthentication.*$/PasswordAuthentication yes/' /target/etc/ssh/sshd_config
sed -i 's/^#PermitRootLogin.*$/PermitRootLogin no/' /target/etc/ssh/sshd_config

mkdir -p /target/home/ubuntu/.ssh
echo 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEKPfGz+sMQ+ZwXjvgS0W4SJOoeJQA72Kx24tRW+Uf5p gkorkmaz' > /target/home/ubuntu/.ssh/authorized_keys
