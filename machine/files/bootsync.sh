#!/bin/sh

# vagrant key
# sudo rm -f /home/docker/.ssh/authorized_keys2
echo "ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEA6NF8iallvQVp22WDkTkyrtvp9eWW6A8YVr+kz4TjGYe7gHzIw+niNltGEFHzD8+v1I2YJ6oXevct1YeS0o9HZyN1Q9qgCgzUFtdOKLv6IedplqoPkcmF0aYet2PkEDo3MlTBckFXPITAMzF8dJSIFo9D8HfdOV0IAdx4O7PtixWKn5y2hMNG0zQPyUecp4pzC6kivAIhyfHilFR61RGL+GPXQ2MWZWFYbAGjyiYJnAmCP3NOTd0jMZEnDkbUvxhMmBYSdETk1rRgm+R4LOzFUGaHqHDLKLX+FIPKcF96hrucXzcWyLbIbEgE98OHlnVYCzRdK8jlqm8tehUc9c9WhQ== vagrant insecure public key" >> /home/docker/.ssh/authorized_keys

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
sudo kill -KILL $(cat /var/run/udhcpc.eth1.pid)

#Create symlink to scripts folder
sudo -u docker ln -s /mnt/sda1/scripts /home/docker/scripts
sudo -u docker grep -q "for f in ~/scripts/*.sh; do source \$f; done" /home/docker/.ashrc || sudo -u docker echo "for f in ~/scripts/*.sh; do source \$f; done" >> /home/docker/.ashrc

#Create symlink to projects folder
ln -s /mnt/sda1/projects /projects
#Create symlink to certificates folder
ln -s /mnt/sda1/ssl_certs /ssl_certs
