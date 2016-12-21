#!/bin/bash

ALL_CONTAINERS=(postgresql nginx gitolite redmine maintenance)

for CONTAINER in "${ALL_CONTAINERS[@]}"; do
  docker kill ${CONTAINER}
  docker rm --volumes ${CONTAINER} > /dev/null 2>&1
  if [[ "$?" -eq 0 ]]; then
    if [[ "${CONTAINER}" != "maintenance" ]]; then
      sudo rm -rf /home/$(whoami)/volumes-docker-containers/${CONTAINER}/
    fi
  fi
done
