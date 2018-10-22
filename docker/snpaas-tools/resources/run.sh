#!/bin/bash
set -eo pipefail
shopt -s nullglob

command=$1
shift

export PATH=$PATH:/usr/local/bin:/data/bin
[ -n "${GCP_ZONE}" ] && gcloud config set compute/zone ${GCP_ZONE} 2>&1 | awk '{ print "# "$0}'
[ -n "${GCP_REGION}" ] && gcloud config set compute/region ${GCP_REGION} 2>&1 | awk '{ print "# "$0}'
[ -n "${GCP_PROJECT}" ] && gcloud config set project ${GCP_PROJECT} 2>&1 | awk '{ print "# "$0}'
if [ -r ".envrc" ]
then
    . .envrc
else
    echo "# No '.envrc' file found!"
fi


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
  deploy|interpolate|int|destroy|import-secrets|export-secrets|list-secrets)
    exec manage-deployment.sh ${command} ${@}
  ;;
  -m|-p)
    exec manage-deployment.sh ${command} ${@}
  ;;
  *)
    exec ${command} ${@}
  ;;
esac

