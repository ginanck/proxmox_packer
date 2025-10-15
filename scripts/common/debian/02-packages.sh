#!/bin/bash

export DEBIAN_FRONTEND=noninteractive
apt-get install -y \
    openssh-server \
    openssh-client \
    sudo \
    curl \
    nano \
    git \
    python3 \
    python3-selinux \
    cloud-init \
    cloud-guest-utils \
    gdisk \
    dnsutils \
    openvswitch-switch
