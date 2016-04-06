DOCKER_MACHINE_VERSION := 0.7.0
BOOT2DOCKER_VERSION := 1.10.3
DOCKER_VERSION := 1.10.3
DOCKER_COMPOSE_VERSION := 1.6.2
MACHINE_NAME := docker-host
VB_MEMORY := "4096"
VB_CPU_C := "2"
VB_NETWORK := 192.168.10.1/24

B2D_ISO_FILE := iso/boot2docker.iso
B2D_ISO_URL := https://github.com/boot2docker/boot2docker/releases/download/v$(BOOT2DOCKER_VERSION)/boot2docker.iso
B2D_ISO_CHECKSUM := $(shell cat iso/boot2docker.iso.checksum)

# OS & Architecture detection
# TODO: improvements can be added
ifeq ($(OS),Windows_NT)
    CCFLAGS += -D WIN32
    ifeq ($(PROCESSOR_ARCHITECTURE),AMD64)
        CCFLAGS += -D AMD64
    endif
    ifeq ($(PROCESSOR_ARCHITECTURE),x86)
        CCFLAGS += -D IA32
    endif
else
    UNAME_S := $(shell uname -s)
    ifeq ($(UNAME_S),Linux)
        CCFLAGS += -D LINUX
    endif
    ifeq ($(UNAME_S),Darwin)
        CCFLAGS += -D OSX
    endif
    UNAME_P := $(shell uname -p)
    UNAME_M := $(shell uname -m)
    ifeq ($(UNAME_P),x86_64)
        CCFLAGS += -D AMD64
    endif
    ifneq ($(filter %86,$(UNAME_P)),)
        CCFLAGS += -D IA32
    endif
    ifneq ($(filter arm%,$(UNAME_P)),)
        CCFLAGS += -D ARM
    endif
endif

all: virtualbox

upgrade:
ifeq ($(OS),Windows_NT)
	echo "You are on Windows. The only way for now is downloading latest docker toolbox. Go to docker site and do it."
else ifeq ($(UNAME_S),Darwin)
	sudo curl -L https://github.com/docker/machine/releases/download/v$(DOCKER_MACHINE_VERSION)/docker-machine-$(UNAME_S)-$(UNAME_M) > /usr/local/bin/docker-machine && \
	chmod +x /usr/local/bin/docker-machine
	# Install docker-compose
	sudo curl -L https://github.com/docker/compose/releases/download/$(DOCKER_COMPOSE_VERSION)/docker-compose-$(UNAME_S)-$(UNAME_M) > /usr/local/bin/docker-compose
	sudo chmod +x /usr/local/bin/docker-compose
	# Install docker
	sudo curl -L https://get.docker.com/builds/$(UNAME_S)/$(UNAME_M)/docker-$(DOCKER_VERSION) > /usr/local/bin/docker
	sudo chmod +x /usr/local/bin/docker
else ifeq ($(UNAME_S),Linux)
	curl -sSL https://get.docker.com/ | sh
	# Install docker-compose
	curl -L https://github.com/docker/compose/releases/download/$(DOCKER_COMPOSE_VERSION)/docker-compose-$(UNAME_S)-$(UNAME_M) | sudo tee /usr/local/bin/docker-compose >/dev/null
	sudo chmod +x /usr/local/bin/docker-compose
endif

build-docker-machine: download-iso
	VBoxManage controlvm $(MACHINE_NAME) poweroff | true
	VBoxManage unregistervm $(MACHINE_NAME) --delete || true
	docker-machine rm $(MACHINE_NAME) || true
	docker-machine create --driver=virtualbox --virtualbox-memory=$(VB_MEMORY) --virtualbox-cpu-count=$(VB_CPU_C) \
	--virtualbox-boot2docker-url=iso/boot2docker.iso --virtualbox-hostonly-cidr=$(VB_NETWORK) \
	--virtualbox-no-share \
	$(MACHINE_NAME)
	# Download docker-compose to permanent storage.
	docker-machine ssh $(MACHINE_NAME) 'sudo curl -L https://github.com/docker/compose/releases/download/$(DOCKER_COMPOSE_VERSION)/docker-compose-`uname -s`-`uname -m` --create-dirs -o /var/lib/boot2docker/bin/docker-compose'
	# Copy bootsync to docker machine
	docker-machine scp machine/files/bootsync.sh $(MACHINE_NAME):/tmp/bootsync.sh
	# Run provisioning script.
	docker-machine ssh $(MACHINE_NAME) < machine/scripts/provision.sh
	# Copy SSH Public Key from id_rsa.pub to VM
	cat ~/.ssh/id_rsa.pub | docker-machine ssh docker-host "cat >> /home/docker/.ssh/authorized_keys
	# Restart VM to apply settings.
	docker-machine stop $(MACHINE_NAME)
	VBoxManage modifyvm $(MACHINE_NAME) --natpf1 docker,tcp,127.0.0.1,2375,,2375
	VBoxManage modifyvm $(MACHINE_NAME) --natpf1 docker-ssl,tcp,127.0.0.1,2376,,2376
	# Restart VM to apply settings.
	docker-machine start $(MACHINE_NAME)

build-iso:
	docker build -t boot2docker iso/docker
	# Generate Iso
	ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -i vagrant_insecure_key docker@192.168.10.10 'docker run --rm boot2docker > boot2docker.iso'
	# Download Iso
	scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -i vagrant_insecure_key docker@192.168.10.10:boot2docker.iso iso
	# Calculate SHA sum
	ACTUAL=$(shasum -a256 iso/boot2docker.iso | awk '{print $1}')
	echo $ACTUAL > iso/boot2docker.iso.checksum
	# Delete boot2docker on remote
	ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -i vagrant_insecure_key docker@192.168.10.10 'rm -rf boot2docker.iso'

download-iso:
	chmod +x iso/download.sh && iso/download.sh ${B2D_ISO_URL} ${B2D_ISO_CHECKSUM}

virtualbox:	clean-virtualbox build-virtualbox

parallels: clean-parallels build-parallels test-parallels

build-virtualbox: download-iso
	packer build -parallel=false -only=virtualbox-iso \
		-var 'B2D_ISO_FILE=${B2D_ISO_FILE}' \
		-var 'B2D_ISO_CHECKSUM=${B2D_ISO_CHECKSUM}' \
		box/template.json
	vagrant box add -f --name datasyntax/boot2docker box/boot2docker_virtualbox.box

build-parallels: download-iso
	packer build -parallel=false -only=parallels-iso \
		-var 'B2D_ISO_FILE=${B2D_ISO_FILE}' \
		-var 'B2D_ISO_CHECKSUM=${B2D_ISO_CHECKSUM}' \
		box/template.json

clean-virtualbox:
	rm -f box/*_virtualbox.box

clean-parallels:
	rm -f box/*_parallels.box

test-virtualbox:
	@cd box/tests/virtualbox; bats --tap *.bats

test-parallels:
	@cd box/tests/parallels; bats --tap *.bats

.PHONY: all virtualbox parallels \
	clean-virtualbox build-virtualbox test-virtualbox \
	clean-parallels build-parallels test-parallels
