#!/bin/bash

source environment_variables.temp > /dev/null 2>&1 || { echo -e "\nYou need to create your temporary environment_variables.temp based of environment_variables.tmpl!!!\n" && exit 1; }

if [[ ! -f ../postgresql/Dockerfile && ! -f ../nginx/Dockerfile && ! -f ../gitolite/Dockerfile && ! -f ../redmine/Dockerfile && ! -f ../maintenance/Dockerfile ]]; then
  export REGISTRY FROM_DOCKERFILE_TAG
  VARIABLES_TO_REPLACE='$FROM_DOCKERFILE_TAG:$REGISTRY'
  envsubst "$VARIABLES_TO_REPLACE" < "../postgresql/Dockerfile.tmpl" > "../postgresql/Dockerfile"
  envsubst "$VARIABLES_TO_REPLACE" < "../nginx/Dockerfile.tmpl" > "../nginx/Dockerfile"
  envsubst "$VARIABLES_TO_REPLACE" < "../gitolite/Dockerfile.tmpl" > "../gitolite/Dockerfile"
  envsubst "$VARIABLES_TO_REPLACE" < "../redmine/Dockerfile.tmpl" > "../redmine/Dockerfile"
  envsubst "$VARIABLES_TO_REPLACE" < "../maintenance/Dockerfile.tmpl" > "../maintenance/Dockerfile"
fi

docker build --rm -t="${REGISTRY}postgresql${IMAGE_TAG}" ../postgresql
docker build --rm -t="${REGISTRY}nginx${IMAGE_TAG}" ../nginx
docker build --rm -t="${REGISTRY}gitolite${IMAGE_TAG}" ../gitolite
docker build --rm -t="${REGISTRY}redmine${IMAGE_TAG}" ../redmine
docker build --rm -t="${REGISTRY}maintenance${IMAGE_TAG}" ../maintenance
