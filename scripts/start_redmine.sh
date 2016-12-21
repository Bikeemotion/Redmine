#!/bin/bash

# mv this variables to other-files/environment/*config ?
# no because start never reads environment/*config (it only has access in shell when we run build_deploy)
HOST_MOUNTPOINT_FOR_CONTAINER_VOLUMES="/home/$(whoami)/volumes-docker-containers"
CONTAINER_VOLUME=""
ALL_CONTAINERS=(postgresql nginx gitolite redmine maintenance)

if [[ ! -f "environment_variables.temp" ]]; then
  echo "You need to use the template environment_variables.tmpl to create the temporary file environment_variables.temp that contains all docker variables for this environment"
  exit 1
else
  source environment_variables.temp
fi

ENV_VARIABLES_POSTGRESQL="-e POSTGRESQL_USER=${POSTGRESQL_USER} -e POSTGRESQL_PASSWORD=${POSTGRESQL_PASSWORD} -e POSTGRESQL_DATABASE=${POSTGRESQL_DATABASE} -e POSTGRESQL_NODE_TYPE=${POSTGRESQL_NODE_TYPE} -e POSTGRESQL_REPLICATION_ENABLED=${POSTGRESQL_REPLICATION_ENABLED} -e PUMA_RAILS_MAX_THREADS=${PUMA_RAILS_MAX_THREADS}"
ENV_VARIABLES_NGINX="-e DNS_DOMAIN=${DNS_DOMAIN} -e PUMA_HOST=${PUMA_HOST}"
ENV_VARIABLES_GITOLITE=""
ENV_VARIABLES_REDMINE="-e SENDGRID_USER=${SENDGRID_USER} -e SENDGRID_PASSWORD=${SENDGRID_PASSWORD} -e POSTGRESQL_HOST=${POSTGRESQL_HOST} -e POSTGRESQL_USER=${POSTGRESQL_USER} -e POSTGRESQL_PASSWORD=${POSTGRESQL_PASSWORD} -e POSTGRESQL_DATABASE=${POSTGRESQL_DATABASE} -e PUMA_RAILS_MAX_THREADS=${PUMA_RAILS_MAX_THREADS}"
ENV_VARIABLES_MAINTENANCE=""

# script
mkdir -p ${HOST_MOUNTPOINT_FOR_CONTAINER_VOLUMES}

#CONTAINER_CPUSET
CONTAINER_CPUSET="0-"$(awk -v TC=${TOTAL_CPU} 'BEGIN { print TC-1 }')
if [[ "${CONTAINER_CPUSET}" = "0-0" ]]; then
  CONTAINER_CPUSET=0
fi

# all container can share the same RO temp /sys/fs/cgroup/
MNTDIR="/run/docker-containers-ro-cgroup-fs"
ls ${MNTDIR} > /dev/null 2>&1 || sudo mkdir ${MNTDIR}
MOUNTS=$(findmnt -n -m -R /sys/fs/cgroup/ | awk '{ print $1 }'| tail -n +2)
for M in ${MOUNTS}; do
  ls ${MNTDIR}${M} > /dev/null 2>&1 || sudo mkdir -p ${MNTDIR}${M}
  cat /proc/mounts | grep ${MNTDIR}${M} > /dev/null 2>&1 || sudo mount --bind -o ro ${M} ${MNTDIR}${M}
done
CGROUP_VOLUME="${MNTDIR}/sys/fs/cgroup:/sys/fs/cgroup"

# deploy of all containers
CONTAINER_ALL_VARIABLES=()
for CONTAINER in "${ALL_CONTAINERS[@]}"; do
  CONTAINER_UPPER=$(echo ${CONTAINER} | tr '[:lower:]' '[:upper:]')

  docker stats --no-stream ${CONTAINER} > /dev/null 2>&1
  if [[ "$?" -eq 0 ]]; then
    docker start ${CONTAINER}
  else
    CONTAINER_RAM="RAM_${CONTAINER_UPPER}"
    ENV_VARIABLES_CONTAINER="ENV_VARIABLES_${CONTAINER_UPPER}"
    # Detect all env variables to be definied with this container
    #mapfile -t CONTAINER_ALL_VARIABLES < <(compgen -A variable | grep ^${CONTAINER_UPPER})
    #DOCKER_ENV=""
    #for ENV in "${CONTAINER_ALL_VARIABLES[@]}"; do
    #  DOCKER_ENV="${DOCKER_ENV} --env ${ENV}=${!ENV}"
    #done
    # Detec all ports to be exposed in this host
    DOCKER_ALL_PORTS="$(fgrep "EXPOSE" ../${CONTAINER}/Dockerfile.tmpl | cut -d' ' -f 2-)"
    DOCKER_ALL_PORTS=(${DOCKER_ALL_PORTS})
    DOCKER_PUBLISH=""
    for PORT in "${DOCKER_ALL_PORTS[@]}"; do
      DOCKER_PUBLISH="${DOCKER_PUBLISH} --publish ${PORT}:${PORT}"
    done
    HOST_MOUNTPOINT_FOR_CONTAINER_VOLUME="${HOST_MOUNTPOINT_FOR_CONTAINER_VOLUMES}/${CONTAINER}"
    CONTAINER_VOLUME=$(awk -F'=' '/ENV/ && / CONTAINER_VOLUME/ {print $2}' ../${CONTAINER}/Dockerfile.tmpl)

    if [[ "${CONTAINER}" = "maintenance" ]]; then
      NEXT_VOLUMES="/var/run/docker.sock:/var/run/docker.sock"
    else
      NEXT_VOLUMES="${HOST_MOUNTPOINT_FOR_CONTAINER_VOLUME}:${CONTAINER_VOLUME}"
    fi
  
    if [[ "${CONTAINER}" = "redmine" ]]; then
      NEXT_VOLUMES="${NEXT_VOLUMES} --volumes-from gitolite"
    fi

    docker run \
      --cpuset-cpus ${CONTAINER_CPUSET} \
      --detach \
      ${!ENV_VARIABLES_CONTAINER} \
      --hostname docker-${CONTAINER} \
      --memory ${!CONTAINER_RAM}m \
      --memory-swap -1 \
      --name ${CONTAINER} \
      ${DOCKER_PUBLISH} \
      --volume ${CGROUP_VOLUME} --volume ${NEXT_VOLUMES} \
      bikeemotion/${CONTAINER}${IMAGE_TAG}
  fi
done
