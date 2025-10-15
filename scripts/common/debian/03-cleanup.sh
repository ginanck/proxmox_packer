#!/bin/bash

apt-get clean
apt-get autoremove -y

rm -rf /var/lib/apt/lists/*
cloud-init clean
