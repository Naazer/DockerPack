#!/usr/bin/env bash

VB_NETWORK="192.168.10.1/24"

arguments=$*
if [ $# -eq 0 ]; then
    noargs=1
fi

for i in "$@"
do
case $i in
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
    exit
elif [ "$(expr substr $(uname -s) 1 5 2>/dev/null)" == "Linux" ]; then
    echo "Linux detected"
elif [ "$(expr substr $(uname -s) 1 6 2>/dev/null)" == "CYGWIN" ]; then
    echo "Windows detected"
    exit
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

#determine docker0 ip
DOCKER0_IP=`ip addr list docker0 | grep 'inet ' | cut -d' ' -f6 | cut -d'/' -f1`
DOCKER0_NETWORK=`ip addr list docker0 | grep 'inet ' | cut -d' ' -f6`
    
echo "Starting system-wide DNS service... "
docker run -d --name dns -p $DOCKER0_IP:53:53/udp --cap-add=NET_ADMIN \
--restart always \
--dns 8.8.8.8 -v /var/run/docker.sock:/var/run/docker.sock \
jderusse/dns-gen > /dev/null


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

# Setting DNS (only for Linux or inside docker-host
if [ "$(expr substr $(uname -s) 1 5 2>/dev/null)" == "Linux" ]
then
    sudo grep "nameserver $DOCKER0_IP" < /etc/resolv.conf > /dev/null 2>&1 || (echo "nameserver $DOCKER0_IP" | sudo cat - /etc/resolv.conf > temp && sudo mv temp /etc/resolv.conf)
fi
