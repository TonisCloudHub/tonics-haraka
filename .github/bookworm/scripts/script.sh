#!/bin/bash

# Launch Instance
lxc launch images:debian/bookworm/amd64 tonics-haraka

# Dependencies
lxc exec tonics-haraka -- bash -c "apt update -y && apt install build-essential -y"

lxc exec tonics-haraka -- bash -c "apt install curl whois -y && curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && apt-get install -y nodejs"

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

# Necessary Files
lxc exec tonics-haraka -- bash -c "touch /root/tonics_haraka/config/tls.ini && touch /root/tonics_haraka/config/auth_enc_file.ini"

# Haraka Plugins Setup
cat << EOF | sudo tee -a tonics_haraka.plugins
dnsbl
helo.checks
tls
mail_from.is_resolvable
spf
rcpt_to.in_host_list
headers
dkim_sign
queue/smtp_forward
haraka-plugin-auth-enc-file
EOF

lxc file push tonics_haraka.plugins tonics-haraka/root/tonics_haraka/config/plugins

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
lxc exec tonics-haraka -- bash -c "apt clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*"

# Haraka Version
Version=$(lxc exec tonics-haraka -- haraka -v | grep -oP "Version: \K[\d.]+")

# Publish Image
mkdir images && lxc stop tonics-haraka && lxc publish tonics-haraka --alias tonics-haraka

# Export Image
lxc start tonics-haraka
lxc image export tonics-haraka images/haraka-bookworm-$Version

# Image Info
lxc image info tonics-haraka >> images/info.txt
