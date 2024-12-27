#!/bin/bash

dnf -y update
dnf clean all
rm -rf /var/cache/dnf/*
cloud-init clean