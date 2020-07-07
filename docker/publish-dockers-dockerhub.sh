#!/usr/bin/env bash
# set -o pipefail  # exit if pipe command fails
[ -z "$DEBUG" ] || set -x
set -e

##

DOCKER_BASE_TAG=${DOCKER_BASE_TAG-platformengineering}
# build --squash is an experimental feature, you would need to enable the experimental
# feature in docker daemon https://docs.docker.com/engine/reference/commandline/dockerd/#daemon-configuration-file
DOCKER_BUILD_ARGS=${DOCKER_BUILD_ARGS---squash}
DOCKER=${DOCKER:-docker}

###


# You need bosh installed and with you credentials
if ! [ -x "$(command -v $DOCKER)" ]
then
    echo "ERROR: $DOCKER command not found! Please install it and make it available in the PATH"
    exit 1
fi


DOCKER_USER=$(docker info 2> /dev/null  | sed -ne 's/Username: \(.*\)/\1/p')
if [ -z "$DOCKER_USER" ]
then
    echo "ERROR: Not logged in Docker Hub!"
    echo "Please perform 'docker login' with your credentials in order to push images there."
    exit 1
fi


for dir in ./*/
do
  (
    pushd $dir
      dir=${dir%*/}
      NAME=${dir##*/}
      TAG="$DOCKER_BASE_TAG/$NAME"
      VERSION=$(sed -ne 's/^ARG.* VERSION=\(.*\)/\1/p' Dockerfile)

      echo "* Building Docker image with tag $NAME:$VERSION ..."
      $DOCKER build $DOCKER_BUILD_ARGS . -t $NAME
      $DOCKER tag $NAME $TAG

      # Uploading docker image
      echo "* Pusing Docker image to Docker Hub ..."
      $DOCKER push $TAG
      $DOCKER tag $NAME $TAG:$VERSION
      $DOCKER push $TAG
    popd
  )
done

exit 0
