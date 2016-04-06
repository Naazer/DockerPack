#!/bin/sh

# Fail on errors
set -e

MOUNT_POINT=/mnt/sda1

# Download extra packages to permanent storage
echo 'http://distro.ibiblio.org/tinycorelinux/' | sudo tee /opt/tcemirror
tce-load -w bash.tcz rsync.tcz
sudo cp -R ${MOUNT_POINT}/tmp/tce/optional /var/lib/boot2docker/tce

# Create bin directory for permanent storage of custom binaries
sudo mkdir -p /var/lib/boot2docker/bin

sudo mkdir -p ${MOUNT_POINT}/projects
sudo chown docker:staff ${MOUNT_POINT}/projects

sudo mkdir -p ${MOUNT_POINT}/ssl_certs
sudo chown docker:staff ${MOUNT_POINT}/ssl_certs

sudo mkdir -p ${MOUNT_POINT}/scripts
sudo chown docker:staff ${MOUNT_POINT}/scripts

sudo mv /tmp/bootsync.sh /var/lib/boot2docker/bootsync.sh
sudo chown root:root /var/lib/boot2docker/bootsync.sh
sudo chmod +x /var/lib/boot2docker/bootsync.sh

# Disable DOCKER_TLS
# sudo sed -i 's/DOCKER_TLS=.*/DOCKER_TLS=no/' /var/lib/boot2docker/profile
# sudo sed -i 's/2376/2375/' /var/lib/boot2docker/profile

# Append Docker IP and DNS configuration to EXTRA_ARGS
sudo sed -i "/EXTRA_ARGS='/a --dns 172.17.0.1 --dns 8.8.8.8" /var/lib/boot2docker/profile
sudo sed -i "/EXTRA_ARGS='/a --bip=172.17.0.1/24" /var/lib/boot2docker/profile

# Enable SFTP
# (Already present by default)
# echo "Subsystem sftp /usr/local/lib/openssh/sftp-server" | sudo tee -a /var/lib/boot2docker/ssh/sshd_config
