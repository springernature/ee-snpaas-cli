#!/bin/bash
set -eo pipefail
shopt -s nullglob

command=$1
shift

echo "# Running snpaas cli version ${SNPAAS_VERSION}: $0 ${command} $*"

SNPAAS_HOME=${SNPAAS_HOME:-/home/snpaas}

# find datadir (if it is provided by a docker workdir)
if workdir="$(git rev-parse --show-toplevel 2>/dev/null)"
then
    # If the command is being executed in a git repo, the volume will be the entire
    # git repo, and the workdir will be set to the current path
    SNPAAS_DATADIR="${workdir}"
else
    # If this is not a git repo, just use default datadir if not empty, otherwise
    # user the current folder
    SNPAAS_DATADIR=${SNPAAS_DATADIR:-/data}
    [ "$(ls -A $SNPAAS_DATADIR)" ] || SNPAAS_DATADIR="$(pwd)"
fi
echo "# Workdir root: $SNPAAS_DATADIR"

# Load the path for looking for commands. Also load home folder
# so in docker could potentially to be able to execute user commands!
export PATH=$PATH:/usr/local/bin:$SNPAAS_DATADIR/bin:$SNPAAS_HOME/bin

# Set default GCP settings
[ -n "${GCP_ZONE}" ] && gcloud config set compute/zone ${GCP_ZONE} 2>&1 | awk '{ print "# "$0}'
[ -n "${GCP_REGION}" ] && gcloud config set compute/region ${GCP_REGION} 2>&1 | awk '{ print "# "$0}'
[ -n "${GCP_PROJECT}" ] && gcloud config set project ${GCP_PROJECT} 2>&1 | awk '{ print "# "$0}'

# Load .envrc file in datadir (root of the repo)
if [ -r "$SNPAAS_DATADIR/.envrc" ]
then
    pushd $SNPAAS_DATADIR > /dev/null
        echo "# Loading repository .envrc"
        . .envrc
    popd > /dev/null
else
    echo "# No '.envrc' file found in the repository root!"
fi

# Load .envrc file in current folder
if  [ "$(pwd)" != "$SNPAAS_DATADIR" ]
then
    # .envrc file in the current path : working dir
    if [ -r ".envrc" ]
    then
        echo "# Loading .envrc"
        . .envrc
    else
        echo "# No '.envrc' file found in current folder!"
    fi
fi


case ${command} in
  help)
    echo
    cat "/Readme.md"
    for e in $(env | awk -F'=' '/^SNPAAS_/{ print $1 }')
    do
        echo "$(echo $e | awk '{ sub(/SNPAAS_/,"",$1); sub(/_VERSION/,"",$1);  print "  "$1}'):  ${!e}"
    done
    echo
    exit 0
  ;;
  bosh-*|deploy|interpolate|int|destroy|-m|-p)
    exec su --preserve-environment --shell /bin/bash $SNPAAS_USER -- /usr/local/bin/manage-deployment.sh ${command} ${@}
  ;;
  import-secrets|export-secrets|list-secrets|-p)
    # ~/.credhub/config.json is created with restrictive permissions, running as user does not work
    exec /usr/local/bin/manage-deployment.sh ${command} ${@}
  ;;
  cf-*)
    exec su --preserve-environment --shell /bin/bash $SNPAAS_USER -- /usr/local/bin/manage-cf.sh ${command} ${@}
  ;;
  *)
    exec ${command} ${@}
  ;;
esac

