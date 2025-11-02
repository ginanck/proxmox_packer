#!/bin/bash

# Set non-interactive frontend
export DEBIAN_FRONTEND=noninteractive

# Remove CD-ROM from sources list to prevent apt errors
sed -i '/cdrom:/d' /etc/apt/sources.list

# Update package lists
apt-get update
