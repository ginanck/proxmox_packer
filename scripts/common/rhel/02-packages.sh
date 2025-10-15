#!/bin/bash

dnf install -y \
    openssh-server \
    openssh-clients \
    sudo \
    curl \
    nano \
    git \
    python3 \
    python3-libselinux \
    cloud-init \
    cloud-utils-growpart \
    gdisk \
    bind-utils
