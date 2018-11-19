#!/bin/bash
set -eo pipefail
shopt -s nullglob

command=$1
shift

export PATH=$PATH:/usr/local/bin:/data/bin:bin

[ -n "${GCP_ZONE}" ] && gcloud config set compute/zone ${GCP_ZONE} 2>&1 | awk '{ print "# "$0}'
[ -n "${GCP_REGION}" ] && gcloud config set compute/region ${GCP_REGION} 2>&1 | awk '{ print "# "$0}'
[ -n "${GCP_PROJECT}" ] && gcloud config set project ${GCP_PROJECT} 2>&1 | awk '{ print "# "$0}'

# .envrc file in the volume
if [ -r "/data/.envrc" ]
then
    pushd /data > /dev/null
        . .envrc
        echo "# Done loading MAIN .envrc"
    popd > /dev/null
else
    echo "# No '.envrc' file found in the root repo!"
fi

if  [ "$(pwd)" != "/data" ]
then
    # .envrc file in the current path : working dir
    if [ -r ".envrc" ]
    then
        . .envrc
        echo "# Done loading .envrc"
    else
        echo "# No '.envrc' file found in current folder!"
    fi
fi

echo "# Running snpaas cli version ${VERSION}"
echo

usage() {
    echo
    cat "/Readme.md"
    for e in $(env | awk -F'=' '/^SNPAAS_/{ print $1 }')
    do
        echo "$(echo $e | awk '{ sub(/SNPAAS_/,"",$1); sub(/_VERSION/,"",$1);  print "  "$1}'):  ${!e}"
    done
    echo
}

case ${command} in
  help)
    usage
    exit 0
  ;;
  deploy|interpolate|int|destroy|import-secrets|export-secrets|list-secrets|-m|-p)
    exec manage-deployment.sh ${command} ${@}
  ;;
  *)
    exec ${command} ${@}
  ;;
esac

