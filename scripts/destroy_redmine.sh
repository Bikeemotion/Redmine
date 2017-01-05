#!/bin/bash

source environment_variables.temp > /dev/null 2>&1 || { echo -e "\nYou need to create your temporary environment_variables.temp based of environment_variables.tmpl!!!\n" && exit 1; }

for CONTAINER in "${ALL_CONTAINERS[@]}"; do
  docker inspect be-${CONTAINER}  > /dev/null 2>&1 && \
    docker kill be-${CONTAINER} > /dev/null 2>&1; \
    docker rm --volumes be-${CONTAINER} > /dev/null 2>&1; \
    if [[ "${CONTAINER}" != "maintenance" ]]; then sudo rm -rf ${HOST_MOUNTPOINT_FOR_CONTAINER_VOLUMES}${CONTAINER}/; fi
done
