[![GitHub license](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://github.com/Bikeemotion/CentOS/blob/master/LICENSE)

# Table of Contents
- [About](#about)
- [Configuration](#configuration)
  - [Postgresql](#postgresql)
  - [Nginx](#nginx)
  - [Redmine](#redmine)
  - [Gitolite](#gitolite)
  - [Maintenance](#maintenance)
- [Usage](#usage)
- [Issues](#issues)
- [TODO](#todo)
- [Contributing](#contributing)

# About

Dockerfiles to build various docker images that form our [Redmine](https://www.redmine.org/) installation. 

# Configuration

All the next Dockerfiles have the following configurations:
- built on top of our [CentOS image](https://github.com/Bikeemotion/CentOS)
- each container will have a volume that points to a cgroup Read-Only file system and another to store its permanent data
- all scripts (for configuration and start of PID 1) go to /usr/share/container_scripts

## Postgresql

We have choosen PostgreSQL for Redmine database backend. This image installs the following extra packages:
- `rh-postgresql95-postgresql-contrib`
- `rh-postgresql95-postgresql-server-9.5`
- `rsync`

Additionally, we did the following configurations:
- check that postgres user always have the same UID and GID (26)
- mounted a volume in /var/lib/pgsql to store all permanent data
- PGDATA was defined for /var/lib/pgsql/data
- exposed port 5432
- postgres user has sudo access to be able to configure PostgreSQL server (it will use the below environment variables for its configuration) before executing it

    Variable name | Description | Examples
    --- | --- | ---
    POSTGRESQL_DATABASE | database name where redmine will store its information | redmine_production
    POSTGRESQL_USER | redmine dabase owner | redmine 
    POSTGRESQL_PASSWORD | redmine dabase owner password | WhoWillGuessThisP@ssword?
    POSTGRESQL_REPLICATION_ENABLED | if will have streaming replication enabled. possible values true/false | false
    POSTGRESQL_NODE_TYPE | normally will be 'master' but if you enable streaming replication it can be 'standby' | master
    PUMA_RAILS_MAX_THREADS | how many connections have Redmine worker defined in its connection pool | 10

## Nginx

To be able to protect the access to Redmine application, we are going to use Nginx as a https proxy server and Let's Encrypt for its free SSL/TLS Certificates. This image installs the following extra packages:
- `certbot`
- `nginx`

Additionally, we did the following configurations:
- mounted a volume in /etc/letsencrypt to store all permanent data.
- exposed port 80 (force redirection for 443), 443, 8080 (for testing purposes)
- we defined a 2048bits Diffie–Hellman (D-H) key exchange (TLS)
- we will use the following environment variables for nginx configuration before executing it

    Variable name | Description | Examples
    --- | --- | ---
    DNS_DOMAIN | public FQDN for Redmine application | bikeemotion.com 
    PUMA_HOST | IP of the machine where Redmine container is running. as we are running all containers in the same host, we will be using docker gateway (docker0) | `$(ip -o -f inet addr show docker0 | awk '{print $4}' | cut -d'/' -f 1)`
    
## Redmine

This image installs the following extra packages:
- `bzip2`
- `gdbm`
- `git`
- `git-annex`
- `gitolite3`
- `ImageMagick`
- `ipa-pgothic-fonts`
- `libffi-devel`
- `libyaml-devel`
- `openssl-devel`
- `rh-postgresql95-postgresql`
- `rh-ruby23`
- `rh-ruby23-rubygem-bundler`
- `zlib-devel`

Additionally, we did the following configurations:
- check that redmine and gitolite3 user always have the same UID and GID (1051 and 1050 respectively)
- despite having a container for gitolite3 server, Redmine needs to have access to gitolite and git-annex binaries when using the Redmine Git Hosting plugin
- mounted a volume in /usr/local/src/redmine to store permanent data
- if the previous volume is empty, it will install the Redmine version defined in Dockerfile. If it isn't and the defined version in Dockerfile is higher than the one installed, it will backup PostgreSQL database, and install the new version in another folder.
- if for some reason you need to downgrade, you can only do it to a previously installed version. You should **only downgrade** when you don't have new data in the new installation. downgrading will restore the PostgreSQL backup to the state where it was before the upgrade to a newer version (that could be different from the one that you are using at this moment). For this reason, you should only have 2 Redmine installations in the previous volume
- exposed port 9292
- redmine user will have sudo access to be able to configure Redmine and Puma (it will use the below environment variables for its configuration) before executing it

    Variable name | Description | Examples
    --- | --- | ---
    SENDGRID_USER | [SendGrid](https://sendgrid.com/) user |
    SENDGRID_PASSWORD | [SendGrid](https://sendgrid.com/) password |
    POSTGRESQL_HOST | ip of the machine where postgresql container is running. as we are runing all containers in the same host, we will be using docker gateway (docker0) | `$(ip -o -f inet addr show docker0 | awk '{print $4}' | cut -d'/' -f 1)`
    POSTGRESQL_DATABASE | database name where redmine will store its information | redmine_production
    POSTGRESQL_USER | redmine dabase owner | redmine 
    POSTGRESQL_PASSWORD | redmine dabase owner password | WhoWillGuessThisP@ssword?
    PUMA_RAILS_MAX_THREADS | connection pool for each Redmine worker | 10
    GITOLITE_HOST | IP of the machine where Gitolite container is running. as we are running all containers in the same host, we will be using docker gateway (docker0) | `$(ip -o -f inet addr show docker0 | awk '{print $4}' | cut -d'/' -f 1)`
    
## Gitolite

> **Note**: This container it's optional!!!

We created this container because we use GIT for our version control system and Redmine only supports Gitolite. This image installs the following extra packages:
- `git-annex`
- `gitolite3`
- `openssh-server`
- `rh-ruby23`

Additionally we did the following configurations:
- check that gitolite3 user always have the same UID and GID (1050)
- regenerating ssh_host_ed25519_key and ssh_host_rsa_key so it doesn't use the default one
- installing ruby2.3 because Redmine Git Hosting plugin install ruby hooks in gitolite3
- mounted a volume in /var/lib/gitolite3 to store permanent data
- exposed port 2222

## Maintenance

We created this container to help us in the maintenance of ours containers without the need to install cron in each of the other containers (which go against one of the best Docker practices - Run only one process per container)
. This image installs the following extra packages:
- `cronie`
- `docker`

Additionally, we created various cronjobs:
- renew let's encrypt certificates when needed (daily)
- force auto vacuum of all PostgreSQL databases (daily)
- backups all PostgreSQL databases (hourly)

# Usage

At this moment if you want to use our images, you will have to build the images yourself using a Linux machine (we use bash in our scripts):

1. you need to have our centos image already built in your system. check instructions [here](https://github.com/Bikeemotion/CentOS/blob/master/README.md#usage)
2. define the variables that will be used in your build (you can see the template file environment_variables.tmpl - all containers RAM is defined for a total of 2G)

    ```bash
    cd scripts
    cp environment_variables.tmpl environment_variables.temp
    vi environment_variables.temp
    ```
    Variable name | Description | Examples
    --- | --- | ---
    ALL_CONTAINERS | all the containers that are going to be built with rebuild.sh script | (postgresql nginx gitolite redmine maintenance)
    CPUSET_CPUS | host CPUs in which you allocate execution of all containers (examples: 0-3 or 0 or 1. If you leave it empty it will use all available CPUs) | 
    HOST_MOUNTPOINT_FOR_CONTAINER_VOLUMES | where all the containers permanent volumes will be created in the host. **Note**: it should be terminated with a '/'  | `/home/$(whoami)/volumes-docker-containers/`
    FROM_DOCKERFILE_TAG | the tag that will be used when pulling our CentOS image. It's the tag of centos image that you build previously | :1.0
    REGISTRY | to which docker registry [registry/][username/] you are going push the image to. In the case that you only want to use it locally, you can use the username part (you shouldn't leave empty so it doesn't collide with upstream centos image) | quay.io/bikeemotion/
    IMAGE_TAG | the tag of the built image | :1.0
    RAM_POSTGRESQL | host memory that will be allocated to PostgreSQL container | 256
    RAM_GITOLITE | host memory that will be allocated to Gitolite container | 256
    RAM_NGINX | host memory that will be allocated to Nginx container | 32
    RAM_REDMINE | host memory that will be allocated to Redmine container | 1472
    RAM_MAINTENANCE | host memory that will be allocated to maintenance container | 32
    
3. build all the images itself

    ```bash
    ./rebuild.sh
    ```

4. start all container (Redmine will take a few minutes to go up in your first execution)

    ```bash
    ./start_redmine.sh
    ```
    
5. If you want to remove all containers you have 2 options:
  - without destroying all permanent data `./stop_redmine.sh`
  - destroying all permanent data `./destroy_redmine.sh`
  
# Issues

1. When configuring the nginx container with a private IP, the certbot will not be able to register the URL redmine.${DNS_DOMAIN} with the email backend@${DNS_DOMAIN} which will result in the container exiting. If you are using it locally that's not problem because you can use the URL http://127.0.0.1:9292 to access your Redmine installation

# Todo

1. Create Automated builds of this images in a public repository ([Docker Hub](https://hub.docker.com/), [Quay](https://quay.io/), ...)
2. Create a new container to block brute force attacks ([sshguard](http://www.sshguard.net/) or [Fail2ban](http://www.fail2ban.org/wiki/index.php/Main_Page) or ...)
3. Despite PostgreSQL container has the option to configure its self as standby (in streaming replication mode) it's still not working because would need to have at least 3 containers: one for PostgreSQL master, other for PostgreSQL in standby mode and another for connection pool like pgbouncer or pgpool


# Contributing

If you find this image useful here's how you can help:

- Send a Pull Request with your new features, documentation, and bug fixes 
- Help new users with [Issues](https://github.com/Bikeemotion/Redmine/issues) they may encounter
