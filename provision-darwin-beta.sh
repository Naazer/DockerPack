#!/usr/bin/env bash
docker rm -f dns
docker run -d --name dns -p 53:53/udp --cap-add=NET_ADMIN --restart always --dns 8.8.8.8 -v /var/run/docker.sock:/var/run/docker.sock jderusse/dns-gen

docker rm -f sinopia
docker run -d --name sinopia -p 4873:4873 --restart always --dns 8.8.8.8 --dns 8.8.4.4 keyvanfatehi/sinopia:latest