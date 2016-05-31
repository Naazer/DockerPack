#!/bin/sh

# Fail on errors
set -e

MOUNT_POINT=/mnt/sda1
DOCKER_COMPOSE_VERSION=$1

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

matches() {
    input="$1"
    pattern="$2"
    echo "$input" | grep -q "$pattern"
}

# Install docker-compose
echo "Checking docker-compose version to be $DOCKER_COMPOSE_VERSION..."
CURRENT_DOCKER_COMPOSE_VERSION=`sudo /var/lib/boot2docker/bin/docker-compose --version` 2>/dev/null || CURRENT_DOCKER_COMPOSE_VERSION=""
if [ -n "$CURRENT_DOCKER_COMPOSE_VERSION" ] && matches "$CURRENT_DOCKER_COMPOSE_VERSION" "$DOCKER_COMPOSE_VERSION"; then
    echo "Latest version already installed. Skipping..."
else
    sudo rm -rf /var/lib/boot2docker/bin/docker-compose  && \
    sudo curl -L https://github.com/docker/compose/releases/download/$DOCKER_COMPOSE_VERSION/docker-compose-`uname -s`-`uname -m` --create-dirs -o /var/lib/boot2docker/bin/docker-compose && \
    sudo chmod +x /var/lib/boot2docker/bin/docker-compose
fi

sudo mv /tmp/bootsync.sh /var/lib/boot2docker/bootsync.sh && \
sudo chown root:root /var/lib/boot2docker/bootsync.sh && \
sudo chmod +x /var/lib/boot2docker/bootsync.sh

sudo mv /tmp/id_rsa.pub /var/lib/boot2docker/id_rsa.pub && \
sudo chown root:root /var/lib/boot2docker/id_rsa.pub

sudo mv /tmp/aliases.sh /mnt/sda1/scripts/aliases.sh && \
sudo chown root:root /mnt/sda1/scripts/aliases.sh && \
sudo chmod +x /mnt/sda1/scripts/aliases.sh

# Installing certificates
sudo mv /tmp/ca.pem /var/lib/boot2docker/ca.pem && \
sudo chown root:root /var/lib/boot2docker/ca.pem && \
sudo chmod 644 /var/lib/boot2docker/ca.pem

sudo mv /tmp/server.pem /var/lib/boot2docker/server.pem && \
sudo chown root:root /var/lib/boot2docker/server.pem && \
sudo chmod 644 /var/lib/boot2docker/server.pem

sudo mv /tmp/server-key.pem /var/lib/boot2docker/server-key.pem && \
sudo chown root:root /var/lib/boot2docker/server-key.pem && \
sudo chmod 644 /var/lib/boot2docker/server-key.pem


source /var/lib/boot2docker/bootsync.sh

sudo /etc/init.d/docker restart

# Enable SFTP
# (Already present by default)
# echo "Subsystem sftp /usr/local/lib/openssh/sftp-server" | sudo tee -a /var/lib/boot2docker/ssh/sshd_config
