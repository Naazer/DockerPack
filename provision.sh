#!/usr/bin/env bash

DOCKER_MACHINE_VERSION="0.10.0"
BOOT2DOCKER_VERSION="v17.03.0-ce"
DOCKER_VERSION="17.03.0-ce"
DOCKER_COMPOSE_VERSION="1.11.2"
MACHINE_NAME="docker-host"
DEFAULT_MEMORY_SIZE="4096"
DEFAULT_CPU_COUNT="2"
DEFAULT_DISK_SIZE="51200"
VB_NETWORK="192.168.10.1/24"
B2D_ISO_CHECKSUM="88a752a5956b71af5a544abadc89c5a2c4fa8173c4f3b7855bd449d46dd1a4c9"
BOOT2DOCKER_URL="https://github.com/boot2docker/boot2docker/releases/download/v17.03.0-ce/boot2docker.iso"

arguments=$*
if [ $# -eq 0 ]; then
    noargs=1
fi

for i in "$@"
do
case $i in
    --install)
    install=1
    shift # past argument with no value
    ;;
    --build-iso)
    buildiso=1
    shift # past argument with no value
    ;;
    --rebuild)
    rebuild=1
    shift # past argument with no value
    ;;
    *)
    # unknown option
    ;;
esac
done

if [ "$(uname)" == "Darwin" ]; then
    echo "Darwin detected"
elif [ "$(expr substr $(uname -s) 1 5 2>/dev/null)" == "Linux" ]; then
    echo "Linux detected"
elif [ "$(expr substr $(uname -s) 1 6 2>/dev/null)" == "CYGWIN" ]; then
    echo "Windows detected"
fi

# Install docker
if [ -n "$install" ]
then

    UNAME_S=`uname -s`
    UNAME_P=`uname -p`
    UNAME_M=`uname -m`

    if [ "$(expr substr $(uname -s) 1 5 2>/dev/null)" != "Linux" ]
    then

        # Install docker-machine
        echo "Checking docker-machine version..."
        CURRENT_DOCKER_MACHINE_VERSION=`docker-machine --version`
        if [[ $CURRENT_DOCKER_MACHINE_VERSION == *$DOCKER_MACHINE_VERSION* ]]
        then
            echo "Latest version already installed. Skipping..."
        else
            if [ "$(expr substr $(uname -s) 1 6 2>/dev/null)" == "CYGWIN" ]; then
                echo "Docker machine of version $DOCKER_MACHINE_VERSION not found. Download latest docker-toolbox for Windows"
                exit
            else
                sudo curl -L https://github.com/docker/machine/releases/download/v$DOCKER_MACHINE_VERSION/docker-machine-$UNAME_S-$UNAME_M > /usr/local/bin/docker-machine && \
                chmod +x /usr/local/bin/docker-machine
            fi
        fi

        # Install docker-compose
        echo "Checking docker-compose version..."
        CURRENT_DOCKER_COMPOSE_VERSION=`docker-compose --version`
        if [[ $CURRENT_DOCKER_COMPOSE_VERSION == *$DOCKER_COMPOSE_VERSION* ]]
        then
            echo "Latest version already installed. Skipping..."
        else
            if [ "$(expr substr $(uname -s) 1 6 2>/dev/null)" == "CYGWIN" ]; then
                echo "Docker-compose of version $DOCKER_COMPOSE_VERSION not found. Download latest docker-toolbox for Windows"
                exit
            else
                rm -rf /usr/local/bin/docker
                sudo curl -L https://github.com/docker/compose/releases/download/$DOCKER_COMPOSE_VERSION/docker-compose-$UNAME_S-$UNAME_M > /usr/local/bin/docker-compose
                sudo chmod +x /usr/local/bin/docker-compose
            fi
        fi

        # Install docker
        echo "Checking docker version..."
        CURRENT_DOCKER_VERSION=`docker --version`
        if [[ $CURRENT_DOCKER_VERSION == *$DOCKER_VERSION* ]]
        then
            echo "Latest version already installed. Skipping..."
        else
            if [ "$(expr substr $(uname -s) 1 6 2>/dev/null)" == "CYGWIN" ]; then
                echo "Docker of version $DOCKER_VERSION not found. Download latest docker-toolbox for Windows"
                exit
            else
                sudo curl -L https://get.docker.com/builds/$UNAME_S/$UNAME_M/docker-$DOCKER_VERSION.tgz | tar -zxv -C /usr/local/bin --strip-components 1 > /usr/local/bin/docker
                sudo chmod +x /usr/local/bin/docker
            fi
        fi

        #Creating docker-machine instance
        echo "Creating docker-machine '$MACHINE_NAME'..."
        docker-machine ls | grep "^$MACHINE_NAME " && MACHINE_EXISTS=1
        if [ -n "$MACHINE_EXISTS" ]
        then
            read -r -p "Docker machine with name '$MACHINE_NAME' exists. Recreate? [yes/no]" response
        fi
        if [[ $response =~ ^([yY][eE][sS]|[yY])$ || -z "$MACHINE_EXISTS" ]]
        then
            read -r -p "CPU count? [$DEFAULT_CPU_COUNT]" cpucount
            cpucount=${cpucount:-$DEFAULT_CPU_COUNT}
            read -r -p "Memory size? [$DEFAULT_MEMORY_SIZE]" memorysize
            memorysize=${memorysize:-$DEFAULT_MEMORY_SIZE}
            read -r -p "Disk size? [$DEFAULT_DISK_SIZE]" disksize
            disksize=${disksize:-$DEFAULT_DISK_SIZE}

            echo "Selected CPU:$cpucount Memory:$memorysize Disk:$disksize"

            # Create virtual machine
            VBoxManage controlvm $MACHINE_NAME poweroff 2>/dev/null || true
            VBoxManage unregistervm $MACHINE_NAME --delete 2>/dev/null || true
            docker-machine rm --force $MACHINE_NAME 2>/dev/null || true
            docker-machine create --driver virtualbox \
                --virtualbox-memory $memorysize \
                --virtualbox-cpu-count $cpucount \
                --virtualbox-disk-size $disksize  \
                --virtualbox-hostonly-cidr $VB_NETWORK \
                --virtualbox-no-share \
                --virtualbox-boot2docker-url $BOOT2DOCKER_URL \
                $MACHINE_NAME
        else
            echo "Assuming 'No'"
        fi

        echo "Detect shell to write to the right .rc file"
        if [[ $SHELL == '/bin/bash' || $SHELL == '/bin/sh' ]]; then SOURCE_FILE=".bash_profile"; fi
        if [[ $SHELL == '/bin/zsh' ]]; then	SOURCE_FILE=".zshrc"; fi
        if [[ $SOURCE_FILE ]]; then
            echo "Replacement ... "
            echo $HOME/$SOURCE_FILE
            sed -iE "/DOCKER_TLS_VERIFY/d" $HOME/$SOURCE_FILE
            sed -iE "/DOCKER_HOST/d" $HOME/$SOURCE_FILE
            sed -iE "/DOCKER_CERT_PATH/d" $HOME/$SOURCE_FILE
            sed -iE "/DOCKER_MACHINE_NAME/d" $HOME/$SOURCE_FILE
            sed -iE "/# Run this command to configure your shell:/d" $HOME/$SOURCE_FILE
            sed -iE "/env $MACHINE_NAME/d" $HOME/$SOURCE_FILE
            docker-machine env $MACHINE_NAME >> $HOME/$SOURCE_FILE
            mkdir -p ~/scripts && cp machine/files/aliases.sh $HOME/scripts/aliases.sh
            grep "source ~/scripts/aliases.sh" < $HOME/$SOURCE_FILE > /dev/null 2>&1 || echo 'source ~/scripts/aliases.sh' >> $HOME/$SOURCE_FILE

        else
            echo -e "${red}Cannot detect your shell. Please manually add the following to your respective .rc or .profile file:${NC}"
            echo -e "$DOCKER_HOST_EXPORT"
        fi

        echo "Provisioning '$MACHINE_NAME'..."

        cp machine/certificates/ca.pem ~/.docker/machine/certs/ca.pem
        cp machine/certificates/ca-key.pem ~/.docker/machine/certs/ca-key.pem
        cp machine/certificates/cert.pem ~/.docker/machine/certs/cert.pem
        cp machine/certificates/key.pem ~/.docker/machine/certs/key.pem

        docker-machine scp machine/certificates/ca.pem $MACHINE_NAME:/tmp/ca.pem
        docker-machine scp machine/certificates/server.pem $MACHINE_NAME:/tmp/server.pem
        docker-machine scp machine/certificates/server-key.pem $MACHINE_NAME:/tmp/server-key.pem

        docker-machine scp machine/files/bootsync.sh $MACHINE_NAME:/tmp/bootsync.sh
        docker-machine scp machine/files/aliases.sh $MACHINE_NAME:/tmp/aliases.sh
        docker-machine scp machine/scripts/provision.sh $MACHINE_NAME:/tmp/provision.sh
        docker-machine scp ~/.ssh/id_rsa.pub $MACHINE_NAME:/tmp/id_rsa.pub
        docker-machine ssh $MACHINE_NAME /tmp/provision.sh $DOCKER_COMPOSE_VERSION

        sed -iE '/192.168.10.10/d' $HOME/.ssh/known_hosts

        sed -iE 's@export DOCKER_HOST=.*@export DOCKER_HOST=\"tcp://192.168.10.10:2376\"@' $HOME/$SOURCE_FILE
        eval $(docker-machine env $MACHINE_NAME)
    else

        # Install docker
        echo "Checking docker version..."
        CURRENT_DOCKER_VERSION=`docker --version`
        if [[ $CURRENT_DOCKER_VERSION == *$DOCKER_VERSION* ]]
        then
            echo "Latest version already installed. Skipping..."
        else
            if [ "$(expr substr $(uname -s) 1 6 2>/dev/null)" == "CYGWIN" ]; then
                echo "Docker of version $DOCKER_VERSION not found. Download latest docker-toolbox for Windows"
                exit
            else
                sudo curl -L https://get.docker.com/builds/$UNAME_S/$UNAME_M/docker-$DOCKER_VERSION.tgz | tar -zxv -C /usr/local/bin --strip-components 1 > /usr/local/bin/docker
                #sudo curl -L https://get.docker.com/builds/$UNAME_S/$UNAME_M/docker-$DOCKER_VERSION > /usr/bin/docker
                sudo chmod +x /usr/local/bin/docker
            fi
        fi

        killall docker

        sudo docker daemon &



    fi

fi


if [ -n "$buildiso" ]
then
    docker build -t boot2docker iso/docker
    # Generate Iso
    ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no docker@192.168.10.10 'docker run --rm boot2docker > boot2docker.iso'
    # Download Iso
    scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no docker@192.168.10.10:boot2docker.iso iso
    # Calculate SHA sum
    ACTUAL=`shasum -a256 iso/boot2docker.iso | awk '{print $1}'`
    echo $ACTUAL
    # Delete boot2docker on remote
    ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no docker@192.168.10.10 'rm -rf boot2docker.iso'
fi

docker rm -f dns > /dev/null 2>&1 || true
docker rm -f vhost-proxy > /dev/null 2>&1 || true
docker rm -f sinopia > /dev/null 2>&1 || true

if [ -n "$rebuild" ]
then
    docker rmi -f datasyntax/nginx-proxy > /dev/null 2>&1 || true
fi

echo "Building nginx-proxy image... "
docker build -t datasyntax/nginx-proxy dockers/nginx-proxy/

if [ "$(expr substr $(uname -s) 1 5 2>/dev/null)" != "Linux" ]
then

    #determine docker0 ip
    DOCKER0_IP=`docker-machine ssh $MACHINE_NAME "ip addr list docker0 | grep 'inet ' | cut -d' ' -f6 | cut -d'/' -f1"`
    DOCKER0_NETWORK=`docker-machine ssh $MACHINE_NAME "ip addr list docker0 | grep 'inet ' | cut -d' ' -f6"`

    echo "Starting system-wide DNS service... "
    docker run -d --name dns -p 53:53/udp --cap-add=NET_ADMIN \
    --restart always \
    --dns 8.8.8.8 -v /var/run/docker.sock:/var/run/docker.sock \
    jderusse/dns-gen > /dev/null
else

    #determine docker0 ip
    DOCKER0_IP=`ip addr list docker0 | grep 'inet ' | cut -d' ' -f6 | cut -d'/' -f1`
    DOCKER0_NETWORK=`ip addr list docker0 | grep 'inet ' | cut -d' ' -f6`
    
    echo "Starting system-wide DNS service... "
    docker run -d --name dns -p $DOCKER0_IP:53:53/udp --cap-add=NET_ADMIN \
    --restart always \
    --dns 8.8.8.8 -v /var/run/docker.sock:/var/run/docker.sock \
    jderusse/dns-gen > /dev/null
fi

echo "Starting system-wide HTTP reverse proxy bound to :80... "
docker run -d --name vhost-proxy -p  80:80 -p 443:443 \
--restart always \
--dns 8.8.8.8 --dns 8.8.4.4 \
-v /var/run/docker.sock:/tmp/docker.sock:ro \
-v /ssl_certs:/etc/nginx/certs \
datasyntax/nginx-proxy > /dev/null

echo "Starting Sinopia Docker... "
docker run -d --name sinopia -p 4873:4873 \
--restart always \
--dns 8.8.8.8 --dns 8.8.4.4 \
keyvanfatehi/sinopia:latest > /dev/null

echo "current ip is $DOCKER0_IP"
echo "current network is $DOCKER0_NETWORK"

# For OSX we can configure DNS resolver automatically
if [ "$(uname)" == "Darwin" ]; then
    sudo mkdir -p /etc/resolver
    echo "nameserver 192.168.10.10" | sudo tee /etc/resolver/docker >/dev/null
    sudo route add -net $DOCKER0_NETWORK 192.168.10.10 || sudo route change -net $DOCKER0_NETWORK 192.168.10.10
fi

# Setting DNS (only for Linux or inside docker-host
if [ "$(expr substr $(uname -s) 1 5 2>/dev/null)" == "Linux" ]
then
    sudo grep "nameserver $DOCKER0_IP" < /etc/resolv.conf > /dev/null 2>&1 || (echo "nameserver $DOCKER0_IP" | sudo cat - /etc/resolv.conf > temp && sudo mv temp /etc/resolv.conf)
fi
