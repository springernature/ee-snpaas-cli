#!/usr/bin/env bash
set -o pipefail  # exit if pipe command fails
[ -z "$DEBUG" ] || set -x

BOSH_CLI=${BOSH_CLI:-bosh}
GRACEDAYS=60

if [ "$1" == "-h" ] || [ "$1" == "--help" ]
then
   cat <<EOF
Usage:
    $0 [deployment-name]

Helps finding VMs which need to be recreated when rotating Bosh Agent certificates.

Scan Bosh vms of a deployment (if provided as argument, otherwise it will scan all vms)
looking for Bosh Agent certificates, warning those vms with certificates about to expire
in less than ${GRACEDAYS} days.

If you want concise output, grep the output of the script matching 'RESULT:'.
EOF
    exit 0
fi

tmpdir=$(mktemp -d -t bosh-XXXXXXXXXX)
trap "rm -rf ${tmpdir}" EXIT SIGINT

if [ -n "${1}" ]
then
    deployments="${1}"
else
    deployments="$(${BOSH_CLI} --json  deployments | jq -r '.Tables[].Rows[].name')"
fi

pushd ${tmpdir} >/dev/null
    for deployment in ${deployments}
    do
        echo "* Deployment: ${deployment}"
        vms="$(${BOSH_CLI} --json -d ${deployment} instances | jq -r '.Tables[].Rows[].instance')"
        expiring=0
        for vm in ${vms}
        do
           echo "    VM: ${vm}"
           rm -f xx*
           vmcerts=0
           ${BOSH_CLI} -d "${deployment}" ssh --json -r "${vm}" 'sudo cat /var/vcap/bosh/settings.json' | jq -r '.Tables[].Rows[].stdout' | jq -r '.env.bosh.mbus.cert.ca' | csplit - '/-----BEGIN CERTIFICATE-----/' '{*}' >/dev/null
           for f in xx*
           do
               if [ -s "${f}" ]
               then
                   endate=$(openssl x509 -in "${f}" -noout -enddate | sed -e 's#notAfter=##')
                   subject=$(openssl x509 -in "${f}" -noout -subject)
                   ssldate=$(date -d "${endate}" '+%s')
                   nowdate=$(date '+%s')
                   diff=$((${ssldate}-${nowdate}))
                   days=$((${diff}/3600/24))
                   msg="${f##*xx0} certificate ${subject} expire in ${days} days."
                   if [ "${GRACEDAYS}" -gt "${days}" ]
                   then
                        vmcerts=$((vmcerts+1))
                        echo -e "\e[31mW   \e[1m${msg}\e[0m"
                   else
                        vmcerts=$((vmcerts-1))
                        echo -e "    \e[92m\e[1m${msg}\e[0m"
                   fi
               fi
           done
           [ "${vmcerts}" -ne 0 ] && expiring=$((expiring+1))
        done
        echo "  RESULT: ${deployment}, $(wc -w <<<${vms}) vms scanned, ${expiring} certificates about to expire in less than ${GRACEDAYS} days."
    done
popd >/dev/null

exit 0

