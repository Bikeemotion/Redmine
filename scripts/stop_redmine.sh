#!/bin/bash

ALL_CONTAINERS=(postgresql nginx gitolite redmine maintenance)

for CONTAINER in "${ALL_CONTAINERS[@]}"; do
  docker stop ${CONTAINER}
  if [[ "$?" -eq 0 ]]; then
    docker rm --volumes ${CONTAINER} > /dev/null 2>&1
  fi
done
