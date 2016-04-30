# DockerPack
DockerPack is a toolbox for developer, which helps managing multiple dockerized projects, supporting all major OSes (Windows, OSX, Linux) and virtual environments (VirtualBox, Parallels etc).

Inside DockerPack some global containers are included:
* nginx-proxy  - provides HTTP and HTTPS proxy for multiple running containers
* jderusse/dns-gen     - provides dynamic DNS resolution for containers & docker host
* sinopia - private nodejs repository for caching nodejs modules (makes npm install ultra-fast in docker)

### Installation

Differs depending on the OS. Please refer to [wiki](https://github.com/DataSyntax/DockerPack/wiki).

### Provision script usage
* `provision.sh --install`  should be run one time only - installs the subsystem
* `provision.sh`  just reruns the standard containers



