#!/bin/bash

source environment_variables.temp > /dev/null 2>&1 || { echo -e "\nYou need to create your temporary environment_variables.temp based of environment_variables.tmpl!!!\n" && exit 1; }

CONTAINER_VOLUME=""
ENV_VARIABLES_POSTGRESQL="-e POSTGRESQL_USER=${POSTGRESQL_USER} -e POSTGRESQL_PASSWORD=${POSTGRESQL_PASSWORD} -e POSTGRESQL_DATABASE=${POSTGRESQL_DATABASE} -e POSTGRESQL_NODE_TYPE=${POSTGRESQL_NODE_TYPE} -e POSTGRESQL_REPLICATION_ENABLED=${POSTGRESQL_REPLICATION_ENABLED} -e PUMA_RAILS_MAX_THREADS=${PUMA_RAILS_MAX_THREADS}"
ENV_VARIABLES_NGINX="-e DNS_DOMAIN=${DNS_DOMAIN} -e PUMA_HOST=${PUMA_HOST}"
ENV_VARIABLES_GITOLITE=""
ENV_VARIABLES_REDMINE="-e SENDGRID_USER=${SENDGRID_USER} -e SENDGRID_PASSWORD=${SENDGRID_PASSWORD} -e POSTGRESQL_HOST=${POSTGRESQL_HOST} -e POSTGRESQL_USER=${POSTGRESQL_USER} -e POSTGRESQL_PASSWORD=${POSTGRESQL_PASSWORD} -e POSTGRESQL_DATABASE=${POSTGRESQL_DATABASE} -e PUMA_RAILS_MAX_THREADS=${PUMA_RAILS_MAX_THREADS}"
ENV_VARIABLES_MAINTENANCE=""

# script
mkdir -p ${HOST_MOUNTPOINT_FOR_CONTAINER_VOLUMES}

if [[ -z "${CPUSET_CPUS}" ]]; then
  CONTAINER_CPUSET=""
else
  CONTAINER_CPUSET="--cpuset-cpus ${CPUSET_CPUS}"
fi

# deploy of all containers
CONTAINER_ALL_VARIABLES=()
for CONTAINER in "${ALL_CONTAINERS[@]}"; do
  CONTAINER_UPPER=$(echo ${CONTAINER} | tr '[:lower:]' '[:upper:]')

  docker stats --no-stream be-${CONTAINER} > /dev/null 2>&1
  if [[ "$?" -eq 0 ]]; then
    docker start be-${CONTAINER}
  else
    CONTAINER_RAM="RAM_${CONTAINER_UPPER}"
    ENV_VARIABLES_CONTAINER="ENV_VARIABLES_${CONTAINER_UPPER}"
    DOCKER_ALL_PORTS="$(fgrep "EXPOSE" ../${CONTAINER}/Dockerfile.tmpl | cut -d' ' -f 2-)"
    DOCKER_ALL_PORTS=(${DOCKER_ALL_PORTS})
    DOCKER_PUBLISH=""
    for PORT in "${DOCKER_ALL_PORTS[@]}"; do
      DOCKER_PUBLISH="${DOCKER_PUBLISH} --publish ${PORT}:${PORT}"
    done
    HOST_MOUNTPOINT_FOR_CONTAINER_VOLUME="${HOST_MOUNTPOINT_FOR_CONTAINER_VOLUMES}/${CONTAINER}"
    CONTAINER_VOLUME=$(awk -F'=' '/ENV/ && / CONTAINER_VOLUME/ {print $2}' ../${CONTAINER}/Dockerfile.tmpl)

    if [[ "${CONTAINER}" = "maintenance" ]]; then
      VOLUMES="/var/run/docker.sock:/var/run/docker.sock"
    else
      VOLUMES="${HOST_MOUNTPOINT_FOR_CONTAINER_VOLUME}:${CONTAINER_VOLUME}"
    fi
  
    if [[ "${CONTAINER}" = "redmine" ]]; then
      VOLUMES="${VOLUMES} --volumes-from be-gitolite"
    fi

    docker run \
      ${CONTAINER_CPUSET} \
      --detach \
      ${!ENV_VARIABLES_CONTAINER} \
      --hostname docker-${CONTAINER} \
      --memory ${!CONTAINER_RAM}m \
      --memory-swap -1 \
      --memory-swappiness 10 \
      --name be-${CONTAINER} \
      ${DOCKER_PUBLISH} \
      --volume ${VOLUMES} \
      ${REGISTRY}${CONTAINER}${IMAGE_TAG}
  fi
done
