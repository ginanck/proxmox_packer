#!/bin/bash

export DEBIAN_FRONTEND=noninteractive

apt-get clean
apt-get update
apt-get install -y software-properties-common

apt-get install -y \
    openssh-server \
    openssh-client \
    sudo \
    curl \
    nano \
    git \
    python3 \
    python3-selinux \
    python3-minimal \
    python3-distutils \
    python3-setuptools \
    python3-wheel \
    python3-pip \
    python3-jinja2 \
    python3-jsonpatch \
    python3-jsonschema \
    python3-oauthlib \
    build-essential \
    python3-dev \
    cloud-init \
    cloud-initramfs-growroot \
    dnsutils
