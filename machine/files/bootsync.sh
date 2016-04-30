#!/bin/sh

# additional keys
sudo cat /var/lib/boot2docker/id_rsa.pub >> /home/docker/.ssh/authorized_keys
sudo rm -f /home/docker/.ssh/authorized_keys2

# install extra packages
sudo su -c "tce-load -i /var/lib/boot2docker/tce/*.tcz" docker

# symlink custom binaries
sudo chmod -R +x /var/lib/boot2docker/bin
for i in /var/lib/boot2docker/bin/*; do
	sudo chmod +x $i
	sudo ln -sf $i /usr/local/bin/$(basename $i)
done

# Start nfs client utilities
sudo /usr/local/etc/init.d/nfs-client start

# Assign default IP address to eth1
sudo ifconfig eth1 192.168.10.10 netmask 255.255.255.0 broadcast 192.168.10.255 up
sudo kill -KILL $(cat /var/run/udhcpc.eth1.pid) 2>/dev/null || echo "DHCP already killed"

#Create symlink to scripts folder
sudo ln -s -f /mnt/sda1/scripts /home/docker/scripts
sudo grep -q "for f in \~/scripts/\*.sh; do source \$f; done" /home/docker/.ashrc || sudo echo "for f in ~/scripts/*.sh; do source \$f; done" >> /home/docker/.ashrc

#Create symlink to projects folder
sudo ln -s -f /mnt/sda1/projects /projects
#Create symlink to certificates folder
sudo ln -s -f /mnt/sda1/ssl_certs /ssl_certs
