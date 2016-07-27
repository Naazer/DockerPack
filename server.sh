#!/bin/bash

docker build -t datasyntax/nginx-proxy dockers/nginx-proxy/

docker run -d --name dns -p 127.0.0.1:53:53/udp --cap-add=NET_ADMIN \
--restart always \
--dns 8.8.8.8 -v /var/run/docker.sock:/var/run/docker.sock \
jderusse/dns-gen > /dev/null

docker run -d --name vhost-proxy -p  127.0.0.1:9080:80 -p 127.0.0.1:9443:443 \
--restart always \
--dns 8.8.8.8 --dns 8.8.4.4 \
-v /var/run/docker.sock:/tmp/docker.sock:ro \
-v /ssl_certs:/etc/nginx/certs \
datasyntax/nginx-proxy > /dev/null

docker run -d --name sinopia -p 127.0.0.1:4873:4873 \
--restart always \
--dns 8.8.8.8 --dns 8.8.4.4 \
keyvanfatehi/sinopia:latest > /dev/null

