#!/bin/bash

# Launch Instance
lxc launch images:debian/bookworm/amd64 tonics-haraka

# Dependencies
lxc exec tonics-haraka -- bash -c "apt update -y && apt install build-essential -y"

lxc exec tonics-haraka -- bash -c "apt install curl -y && curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && apt-get install -y nodejs"

# Install Haraka
lxc exec tonics-haraka -- bash -c "npm install -g Haraka"

# Check Haraka Version 
lxc exec tonics-haraka -- haraka -v

# Instance of Haraka
lxc exec tonics-haraka -- haraka -i tonics_haraka

# Haraka AuthEnc Plugin
lxc exec tonics-haraka -- npm install haraka-plugin-auth-enc-file

# Install Certbot for Standalone Certificate Generation
lxc exec tonics-haraka -- apt-get -y install certbot

# SystemD Manager
lxc exec tonics-haraka -- touch  /etc/systemd/system/tonics_haraka.service

cat << EOF | sudo tee -a tonics_haraka.service
[Unit]
Description=Haraka Mail Server
After=network.target

[Service]
ExecStart=/usr/bin/haraka -c .
WorkingDirectory=/root/tonics_haraka
Restart=always
RestartSec=10
User=root

[Install]
WantedBy=multi-user.target
EOF

lxc file push tonics_haraka.service tonics-haraka/etc/systemd/system/tonics_haraka.service

lxc exec tonics-haraka -- systemctl daemon-reload

# Clean Debian Cache
lxc exec tonics-haraka -- apt clean

# Haraka Version
Version=$(lxc exec tonics-haraka -- haraka -v | grep -oP "Version: \K[\d.]+")

# Publish Image
mkdir images && lxc stop tonics-haraka && lxc publish tonics-haraka --alias tonics-haraka

# Export Image
lxc start tonics-haraka
lxc image export tonics-haraka images/haraka-bookworm-$Version

# Image Info
lxc image info tonics-haraka >> images/info.txt
