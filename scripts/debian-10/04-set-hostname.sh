#!/bin/bash

# Get the directory where the script is located
DIR_NAME=$(basename "$(pwd)")
hostnamectl set-hostname "$DIR_NAME"