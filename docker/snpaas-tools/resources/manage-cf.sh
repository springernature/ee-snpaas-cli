#!/usr/bin/env bash
set -o pipefail  # exit if pipe command fails
[ -z "$DEBUG" ] || set -x

PROGRAM=${PROGRAM:-$(basename "${BASH_SOURCE[0]}")}
PROGRAM_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROGRAM_LOG="${PROGRAM_LOG:-$(pwd)/$PROGRAM.log}"
PROGRAM_OPTS=$@

CF_CLI=${CF_CLI:-cf}
CREDHUB_CLI=${CREDHUB_CLI:-"credhub"}


###

usage() {
    cat <<EOF
Usage:
    $PROGRAM [options] <command> [subcommand-options]

Cloudfoundry client with extra power. 

Commands:
    help            Shows usage help

Also, this script can be sourced to automatically define a set of functions
useful to work with director in other scripts or in the command line by
sourcing this file.

You can use these environment variables to automatically target Cloudfoundry:

  CF_USER
  CF_PASSWORD
  CF_API

Optional:

  CF_ORG
  CF_SPACE

EOF
}

log() {
    local message=${1}
    local timestamp=`date +%y:%m:%d-%H:%M:%S`
    echo "${timestamp} :: ${message}" >> "${PROGRAM_LOG}"
}

echo_log() {
    local one=${1}
    shift
    local timestamp=`date +%y:%m:%d-%H:%M:%S`
    local color="${one} ${@}"
    case "${one}" in
      RUN) color="\e[34m${one}:> \e[1m${@}\e[0m" ;;
      ERROR) color="\e[31m${one}:> \e[1m${@}\e[0m" ;;
      OK) color="\e[92m${one}:> \e[1m${@}\e[0m" ;;
      INFO) color="\e[33m${one}:> \e[1m${@}\e[0m" ;;
      EXIT) color="\e[33m${one}:> \e[1m${@}\e[0m" ;;
    esac
    echo "${timestamp} :: ${one}:> ${@}" >> "${PROGRAM_LOG}"
    echo -e "${timestamp} :: ${color}"
}

# Print a message and exit with error
die() {
    echo_log "ERROR" "$1"
    exit 1
}

cf_system_check() {
    local path=$1

    if ! [ -x "$(command -v ${CF_CLI})" ]; then
        echo_log "ERROR" "CF client is not installed. Please download it from https://docs.cloudfoundry.org/cf-cli/install-go-cli.html"
        return 1
    fi
    return 0
}


cfenv() {
    local target=""
    local rvalue=0

    if ! ${CF_CLI} oauth-token > /dev/null 2>&1
    then
        if [ -n "${CF_USER}" ] && [ -n "${CF_PASSWORD}" ] && [ -n "${CF_API}" ]
        then
            ${CF_CLI} logout > /dev/null 2>&1
            if ! ${CF_CLI} login -a "${CF_API}" -u "${CF_USER}" -p "${CF_PASSWORD}" -o "system" -s "system" > /dev/null 2>&1
            then
                echo_log "ERROR" "Cannot login in CF with the provided environment variables"
                return 1
            fi
        else
            echo_log "ERROR" "Cannot login in CloudFoundry, please define/check environment variables"
            return 1
        fi
    fi
    [ -n "${CF_ORG}" ] && target="-o ${CF_ORG}"
    [ -n "${CF_SPACE}" ] && target="${target} -s ${CF_SPACE}"
    if [ -n "${target}" ]
    then
        if ! ${CF_CLI} target ${target} > /dev/null 2>&1
        then
            echo_log "ERROR" "Cannot target ORG/Space:  ${CF_ORG}/${CF_SPACE}"
            return 1
        fi
    fi
    return 0
}


cfrun() {
    local rvalue=1

    if cfenv
    then
        ${CF_CLI} $@
        rvalue=$?
    fi
    return ${rvalue}
}


cfexec() {
    local target=""
    local rvalue=0

    if ! ${CF_CLI} oauth-token > /dev/null 2>&1
    then
        if [ -n "${CF_USER}" ] && [ -n "${CF_PASSWORD}" ] && [ -n "${CF_API}" ]
        then
            ${CF_CLI} logout > /dev/null 2>&1
            if ! ${CF_CLI} login -a "${CF_API}" -u "${CF_USER}" -p "${CF_PASSWORD}" -o "system" -s "system" > /dev/null 2>&1
            then
                echo_log "ERROR" "Cannot login in CF with the provided environment variables"
                return 1
            fi
        else
            echo_log "ERROR" "Cannot login in CloudFoundry, please define/check environment variables"
            return 1
        fi
    fi
    [ -n "${CF_ORG}" ] && target="-o ${CF_ORG}"
    [ -n "${CF_SPACE}" ] && target="${target} -s ${CF_SPACE}"
    if [ -n "${target}" ]
    then
        {
            echo_log "RUN" "${CF_CLI} target ${target}"
            ${CF_CLI} target ${target}
            rvalue=$?
        }
    fi
    {
        echo_log "RUN" "${CF_CLI} $@"
        ${CF_CLI} $@
        rvalue=$?
    }
    return ${rvalue}
}


################################################################################

# Program
if [ "$0" == "${BASH_SOURCE[0]}" ]
then
    RVALUE=1
    SUBCOMMAND=$1
    shift  # Remove 'subcommand' from the argument list
    if [ "${SUBCOMMAND}" == "cf" ]
    then
        # Just execute silently and exit
        cfrun $@
        exit $?
    fi
    echo_log "Running '$0 $*' logging to '$(basename ${PROGRAM_LOG})'"
    case "${SUBCOMMAND}" in
        # Parse options to each sub command
        cf-help|help)
            usage
            exit 0
            ;;
        top|cf-top)
            cfexec top
            RVALUE=$?
            ;;
        disk|cf-disk)
            cfexec report-disk-usage --quiet
            RVALUE=$?
            ;;
        docker|dockers|cf-docker)
            cfexec docker-usage
            RVALUE=$?
            ;;
        mem|cf-mem)
            cfexec report-memory-usage --quiet
            RVALUE=$?
            ;;
        users|cf-users)
            cfexec report-users --quiet
            RVALUE=$?
            ;;
        usage|cf-usage)
            cfexec usage-report
            RVALUE=$?
            ;;
        app-stats|cf-app-stats)
            if [ -z "${1}" ]
            then
                if [ -z "${CF_ORG}" ] || [ -z "${CF_SPACE}" ]
                then
                    echo_log "Application stats requires a define the CF_ORG and CF_SPACE env vars!"
                else
                    cfexec statistics $1
                    RVALUE=$?
                fi
            else
                echo_log "Application stats requires an extra argument, the app!"
            fi
            ;;
        mysql|cf-mysql)
            if [ -z "${1}" ]
            then
                if [ -z "${CF_ORG}" ] || [ -z "${CF_SPACE}" ]
                then
                    echo_log "Mysql requires a define the CF_ORG and CF_SPACE env vars!"
                else
                    cfexec mysql $1
                    RVALUE=$?
                fi
            else
                echo_log "Mysql client requires an extra argument, the service!"
            fi
            ;;
        route-lookup|cf-route-lookup)
            if [ -z "${1}" ]
            then
                cfexec lookup-route $1
                RVALUE=$?
            else
                echo_log "Searching a route requires an extra argument, the route!"
            fi
            ;;
    esac
    if [ ${RVALUE} == 0 ]
    then
       echo_log "EXIT" "OK ${RVALUE}"
    else
       echo_log "EXIT" "ERROR, return code ${RVALUE}"
    fi
    exit ${RVALUE}
else
    cf_system_check "$(pwd)"
    cfenv
fi

