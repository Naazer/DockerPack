#!/usr/bin/env bash

DOCKER_MACHINE_VERSION="0.7.0"
BOOT2DOCKER_VERSION="1.11.1"
DOCKER_VERSION="1.11.1"
DOCKER_COMPOSE_VERSION="1.7.0"
MACHINE_NAME="docker-host"
VB_MEMORY="4096"
VB_CPU_C="2"
VB_DISK_SIZE="51200"
VB_NETWORK="192.168.10.1/24"

B2D_ISO_URL="https://github.com/boot2docker/boot2docker/releases/download/v$BOOT2DOCKER_VERSION/boot2docker.iso"
B2D_ISO_CHECKSUM="61414d91109d198fee0b9113c7997f37065a0a019e8508ab5e383d4077274c82"

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
    --global-containers)
    globalcontainers=1
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
    if [ "$(uname)" == "Darwin" ]; then
        UNAME_S=`uname -s`
        UNAME_P=`uname -p`
        UNAME_M=`uname -m`
        sudo curl -L https://github.com/docker/machine/releases/download/v$DOCKER_MACHINE_VERSION/docker-machine-$UNAME_S-$UNAME_M > /usr/local/bin/docker-machine && \
        chmod +x /usr/local/bin/docker-machine
        # Install docker-compose
        sudo curl -L https://github.com/docker/compose/releases/download/$DOCKER_COMPOSE_VERSION/docker-compose-$UNAME_S-$UNAME_M > /usr/local/bin/docker-compose
        sudo chmod +x /usr/local/bin/docker-compose
        # Install docker
        sudo curl -L https://get.docker.com/builds/$UNAME_S/$UNAME_M/docker-$DOCKER_VERSION.tgz | tar -zxv -C /usr/local/bin --strip-components 1 > /usr/local/bin/docker
        sudo chmod +x /usr/local/bin/docker

        # Redownkoad iso if necessary
        chmod +x iso/download.sh && iso/download.sh $B2D_ISO_URL $B2D_ISO_CHECKSUM
        # Create virtual machine
        VBoxManage controlvm $MACHINE_NAME poweroff 2>/dev/null || true
        VBoxManage unregistervm $MACHINE_NAME --delete 2>/dev/null || true
        docker-machine rm $MACHINE_NAME 2>/dev/null || true
        docker-machine create --driver=virtualbox --virtualbox-memory=$VB_MEMORY --virtualbox-cpu-count=$VB_CPU_C \
            --virtualbox-boot2docker-url=iso/boot2docker.iso --virtualbox-hostonly-cidr=$VB_NETWORK \
            --virtualbox-disk-size=$VB_DISK_SIZE \
            --virtualbox-no-share \
            $MACHINE_NAME
        # Download docker-compose to permanent storage.
        docker-machine ssh $MACHINE_NAME 'sudo curl -L https://github.com/docker/compose/releases/download/$DOCKER_COMPOSE_VERSION/docker-compose-`uname -s`-`uname -m` --create-dirs -o /var/lib/boot2docker/bin/docker-compose'
        # Copy bootsync to docker machine
        docker-machine scp machine/files/bootsync.sh $MACHINE_NAME:/tmp/bootsync.sh
        docker-machine scp ~/.ssh/id_rsa.pub $MACHINE_NAME:/tmp/id_rsa.pub
        # Run provisioning script.
        docker-machine ssh $MACHINE_NAME < machine/scripts/provision.sh
        # Restart VM to apply settings.
        docker-machine stop $MACHINE_NAME
        VBoxManage modifyvm $MACHINE_NAME --natpf1 docker,tcp,127.0.0.1,2375,,2375
        VBoxManage modifyvm $MACHINE_NAME --natpf1 docker-ssl,tcp,127.0.0.1,2376,,2376
        # Restart VM to apply settings.
        docker-machine start $MACHINE_NAME
        #set TLS
        sed -iE '/192.168.10.10/d' $HOME/.ssh/known_hosts
        docker-machine regenerate-certs -f $MACHINE_NAME
        eval $(docker-machine env $MACHINE_NAME)

        # Detect shell to write to the right .rc file
        if [[ $SHELL == '/bin/bash' || $SHELL == '/bin/sh' ]]; then SOURCE_FILE=".bash_profile"; fi
        if [[ $SHELL == '/bin/zsh' ]]; then	SOURCE_FILE=".zshrc"; fi
        if [[ $SOURCE_FILE ]]; then
            echo $HOME/$SOURCE_FILE
            sed -iE '/DOCKER_TLS_VERIFY/d' $HOME/$SOURCE_FILE
            sed -iE '/DOCKER_HOST/d' $HOME/$SOURCE_FILE
            sed -iE '/DOCKER_CERT_PATH/d' $HOME/$SOURCE_FILE
            sed -iE '/DOCKER_MACHINE_NAME/d' $HOME/$SOURCE_FILE
            sed -iE '/# Run this command to configure your shell:/d' $HOME/$SOURCE_FILE
            sed -iE '/eval $(docker-machine env/d' $HOME/$SOURCE_FILE
            docker-machine env $MACHINE_NAME >> $HOME/$SOURCE_FILE
        else
            echo -e "${red}Cannot detect your shell. Please manually add the following to your respective .rc or .profile file:${NC}"
            echo -e "$DOCKER_HOST_EXPORT"
        fi


    elif [ "$(expr substr $(uname -s) 1 5 2>/dev/null)" == "Linux" ]; then
        echo "Linux detected"
    elif [ "$(expr substr $(uname -s) 1 6 2>/dev/null)" == "CYGWIN" ]; then
        echo "You are on Windows. The only way for now is downloading latest docker toolbox. Go to docker site and do it."
    fi

    exit
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


# If no parameters specified
if [ -n "$noargs" ]
then
    # Only for Linux set docker parameters
    if [ "$(expr substr $(uname -s) 1 5 2>/dev/null)" == "Linux" ]; then
        # Update docker daemon options and restart
        if sudo grep -q "^DOCKER_OPTS=" /etc/default/docker
        then
            sudo sed -ri "s/^DOCKER_OPTS=.*$/DOCKER_OPTS=\"--bip=172.17.42.1\/24 --dns=172.17.42.1 --dns 8.8.8.8 --dns 8.8.4.4\"/" /etc/default/docker
        else
            echo "DOCKER_OPTS=\"--bip=172.17.42.1/24 --dns=172.17.42.1 --dns 8.8.8.8 --dns 8.8.4.4\""  | sudo tee --append /etc/default/docker
        fi

        if systemctl status docker >/dev/null 2>&1
        then
            echo "Ubuntu systemd detected. Adjusting configuration files."
            sudo mkdir -p /etc/systemd/system/docker.service.d

            cat <<'SCRIPT' | sudo tee /etc/systemd/system/docker.service.d/ubuntu.conf
[Service]
# workaround to include default options
EnvironmentFile=/etc/default/docker
ExecStart=
ExecStart=/usr/bin/docker daemon -H fd:// $DOCKER_OPTS
SCRIPT
            sudo systemctl daemon-reload
            sudo systemctl restart docker

        else
            sudo /etc/init.d/docker restart > /dev/null 2>&1 || sudo service docker restart
        fi
    fi

    if [ "$(expr substr $(uname -s) 1 5 2>/dev/null)" != "Linux" ]; then
        scp -q dockers/aliases.sh docker@192.168.10.10:/home/docker/scripts
    else
        #add some aliases
        if [[ $SOURCE_FILE ]]; then
            mkdir -p ~/scripts && cp dockers/aliases.sh ~/scripts/aliases.sh
            grep "source ~/scripts/aliases.sh" < ~/$SOURCE_FILE > /dev/null 2>&1 || echo 'source ~/scripts/aliases.sh' >> ~/$SOURCE_FILE
        fi
        sudo mkdir -p /ssl_certs
    fi
fi


docker rm -f dns > /dev/null 2>&1 || true
docker rm -f vhost-proxy > /dev/null 2>&1 || true
docker rm -f sinopia > /dev/null 2>&1 || true


if [ -n "$rebuild" ]
then
    docker rmi -f datasyntax/nginx-proxy > /dev/null 2>&1 || true
fi


if [ -n "$noargs" ] || [ -n "$globalcontainers" ] || [ -n "rebuild" ]
then

    echo "Building nginx-proxy image... "
    docker build -t datasyntax/nginx-proxy dockers/nginx-proxy/

    echo "Starting system-wide DNS service... "
    docker run -d --name dns -p 172.17.42.1:53:53/udp --cap-add=NET_ADMIN \
    --restart always \
    --dns 8.8.8.8 -v /var/run/docker.sock:/var/run/docker.sock \
    jderusse/dns-gen > /dev/null

    # For OSX we can configure DNS resolver automatically
    if [ "$(uname)" == "Darwin" ]; then
        sudo mkdir -p /etc/resolver
        sudo tee /etc/resolver/docker >/dev/null <<EOF
nameserver 172.17.42.1
EOF
    fi

    # Setting DNS (only for Linux or inside docker-host
    if [ "$(expr substr $(uname -s) 1 5 2>/dev/null)" == "Linux" ]
    then
        sudo grep "nameserver 172.17.42.1" < /etc/resolv.conf > /dev/null 2>&1 || (echo "nameserver 172.17.42.1" | sudo cat - /etc/resolv.conf > temp && sudo mv temp /etc/resolv.conf)
    else
        ssh -q docker@192.168.10.10 "sudo grep \"nameserver 172.17.42.1\" < /etc/resolv.conf > /dev/null 2>&1 || (echo 'nameserver 172.17.42.1' | sudo cat - /etc/resolv.conf > temp && sudo mv temp /etc/resolv.conf)"
    fi

    echo "Starting system-wide HTTP reverse proxy bound to :80... "
    docker run -d --name vhost-proxy -p  80:80 -p 443:443 \
    --restart always \
    -v /var/run/docker.sock:/tmp/docker.sock:ro \
    -v /ssl_certs:/etc/nginx/certs \
    datasyntax/nginx-proxy > /dev/null

    echo "Starting Sinopia Docker... "
    docker run -d --name sinopia -p 4873:4873 \
    --restart always \
    keyvanfatehi/sinopia:latest > /dev/null
fi
