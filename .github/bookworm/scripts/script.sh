#!/bin/bash

# Init incus
sudo incus admin init --auto

# Launch Instance
sudo incus launch images:debian/bookworm/amd64 tonics-haraka

# Dependencies
sudo incus exec tonics-haraka -- bash -c "apt update -y && apt install build-essential -y"

sudo incus exec tonics-haraka -- bash -c "apt install curl whois -y && curl -fsSL https://deb.nodesource.com/setup_22.x | bash - && apt-get install -y nodejs"

# Install Haraka
sudo incus exec tonics-haraka -- bash -c "npm install -g Haraka"

# Check Haraka Version 
sudo incus exec tonics-haraka -- haraka -v

# Instance of Haraka
sudo incus exec tonics-haraka -- haraka -i tonics_haraka

# Haraka AuthEnc Plugin
sudo incus exec tonics-haraka -- npm install haraka-plugin-auth-enc-file

# Install Certbot for Standalone Certificate Generation [NOT NEEDED, TonicsCloud ACME should do the job]
# sudo incus exec tonics-haraka -- apt-get -y install certbot

# Necessary Files
sudo incus exec tonics-haraka -- bash -c "touch /root/tonics_haraka/config/{tls.ini,auth_enc_file.ini,aliases.json,dkim_sign.ini,relay.ini,rcpt_to.access.blacklist_regex,rcpt_to.access.whitelist,relay_dest_domains.ini}"

# Haraka Plugins Setup
cat << EOF | sudo tee -a tonics_haraka.plugins
# Should be above plugins that run hook_rcpt
aliases

# CONNECT
#toobusy
#karma
relay

# control which IPs, rDNS hostnames, HELO hostnames, MAIL FROM addresses, and
# RCPT TO address you accept mail from. See 'haraka -h access'.
access
fcrdns

# HELO
helo.checks

tls
#
# AUTH plugins require TLS before AUTH is advertised, see
haraka-plugin-auth-enc-file

# MAIL FROM
# Only accept mail where the MAIL FROM domain is resolvable to an MX record
mail_from.is_resolvable
spf

# RCPT TO
# At least one rcpt_to plugin is REQUIRED for inbound email. The simplest
# plugin is in_host_list, see 'haraka -h rcpt_to.in_host_list' to configure.
rcpt_to.in_host_list

# DATA
#bounce
# Check mail headers are valid
headers
dkim_sign
EOF

sudo incus file push tonics_haraka.plugins tonics-haraka/root/tonics_haraka/config/plugins

# SystemD Manager
sudo incus exec tonics-haraka -- touch  /etc/systemd/system/tonics_haraka.service

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

sudo incus file push tonics_haraka.service tonics-haraka/etc/systemd/system/tonics_haraka.service

sudo incus exec tonics-haraka -- systemctl daemon-reload

# Clean Debian Cache
sudo incus exec tonics-haraka -- bash -c "apt clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*"

# Haraka Version
Version=$(sudo incus exec tonics-haraka -- haraka -v | grep -oP "Version: \K[\d.]+")

# Publish Image
mkdir images && sudo incus stop tonics-haraka && sudo incus publish tonics-haraka --alias tonics-haraka

# Export Image
sudo incus start tonics-haraka
sudo incus image export tonics-haraka images/haraka-bookworm-$Version

# Image Info
sudo incus image info tonics-haraka >> images/info.txt
