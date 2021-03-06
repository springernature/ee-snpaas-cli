#!/usr/bin/env bash
set -o pipefail  # exit if pipe command fails
[ -z "$DEBUG" ] || set -x

PROGRAM=${PROGRAM:-$(basename "${BASH_SOURCE[0]}")}
PROGRAM_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROGRAM_LOG="${PROGRAM_LOG:-$(pwd)/$PROGRAM.log}"
PROGRAM_OPTS=$@

BOSH_CLI=${BOSH_CLI:-bosh}
BOSH_EXTRA_OPS="--tty --no-color"
CREDHUB_CLI=${CREDHUB_CLI:-credhub}
YQ=${YQ:-yq}
JQ=${JQ:-jq}
TERRAFORM=${TERRAFORM:-terraform}

DEPLOYMENT_STATE="${DEPLOYMENT_STATE:-state.json}"
DEPLOYMENT_CREDS="${DEPLOYMENT_CREDS:-secrets.yml}"
DEPLOYMENT_OPERATIONS="${DEPLOYMENT_OPERATIONS:-operations}"
DEPLOYMENT_VARS="${DEPLOYMENT_VARS:-variables}"
DEPLOYMENT_VARS_FILE="${DEPLOYMENT_VARS_FILE:-var-files.yml}"
DEPLOYMENT_RUNTIMEC="${DEPLOYMENT_RUNTIMEC:-runtime-config}"
DEPLOYMENT_CLOUDC="${DEPLOYMENT_CLOUDC:-cloud-config}"
# Next file are only used when deployed a Director
DEPLOYMENT_DEFAULT_RUNTIMEC="${DEPLOYMENT_DEFAULT_RUNTIMEC:-runtime-config.yml}"
DEPLOYMENT_DEFAULT_CLOUDC="${DEPLOYMENT_DEFAULT_CLOUDC:-cloud-config.yml}"
# This is setup to de name of the deployment, the idea is define env vars
# used in the interpolation process
DEPLOYMENT_NAME_VAR="${DEPLOYMENT_NAME_VAR:-deployment_name}"
# Pre/Post scripts
DEPLOYMENT_PREPARE_SCRIPT="${DEPLOYMENT_PREPARE_SCRIPT:-prepare.sh}"
DEPLOYMENT_FINISH_SCRIPT="${DEPLOYMENT_FINISH_SCRIPT:-finish.sh}"
DEPLOYMENT_TERRAFORM_INPUT="${DEPLOYMENT_TERRAFORM:-terraform}"
DEPLOYMENT_TERRAFORM_OUTPUT="${DEPLOYMENT_TERRAFORM_OUTPUT:-$DEPLOYMENT_VARS/terraform.yml}"

# You can predefine these vars
DEPLOYMENTS_PATH='.'

###

usage() {
    cat <<EOF
Usage:
    $PROGRAM [options] <subcommand> <deployment-folder> [subcommand-options]

Bosh-client manifest manager. By default it looks for a folder with the same
name as <deployment-folder>, reads the operations files, variables and
executes <subcommand>.

Options:
    -m      Specify a manifest file, instead of generating a random one
    -p      Deployments path. Default is $DEPLOYMENTS_PATH
    -h      Shows usage help

Subcommands:
    help            Shows usage help
    create-en       Deploy a Bosh Director
    delete-env      Destroy a Bosh Director
    interpolate     Create the manifest for an environment
    deploy [-f]     Update or upgrade deployment after applying cloud/runtime configs
    destroy [-f]    Delete deployment (does not delete cloud/runtime configs)
    cloud-config    Apply cloud-config from cloud.config.yml interpolating variables
    runtime-config  Apply runtime-config from runtime-config.yml interpolating variables
    import-secrets  Set secrets in Credhub from <deployment-folder>/$DEPLOYMENT_CREDS file
    list-secrets    List secrets from Credhub for <deployment-folder>
    export-secrets  Download secrets from Credhub to <deployment-folder>/$DEPLOYMENT_CREDS

Also, this script can be sourced to automatically define a set of functions
useful to work with director in other scripts or in the command line by
sourcing this file.

You can use your BOSH_CLIENT env variables if you set BOSH_USER_NAME to '' (empty).

If there is a script '$DEPLOYMENT_PREPARE_SCRIPT' next to the base manifest,
it will be launched before the action. If there is a script '$DEPLOYMENT_FINISH_SCRIPT'
it will be run after the action. Both scripts receive the action as first parameter.

Also you can define variables in the runtime/cloud configs or manifests/operations
files and the program will try to find those variables in the environment, with
the prefix of the folder, e.g. if the deployment folder is "cf-test" and you
have defined an variable "((stemcell))" in an operations file, you can
define a variable like "export CF_TEST_stemcell=ubuntu-xenial" and it will be
used.

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


# System check
# path=.
bosh_system_check() {
    local path=$1

    if ! [ -x "$(command -v ${BOSH_CLI})" ]; then
        echo_log "ERROR" "Bosh client is not installed. Please download it from https://bosh.io/docs/cli-v2.html"
        return 1
    fi
    if ! [ -x "$(command -v ${CREDHUB_CLI})" ]; then
        echo_log "ERROR" "Credhub client is not installed. Please download it from https://github.com/cloudfoundry-incubator/credhub-cli"
        return 1
    fi
    return 0
}


bosh_show_status() {
    echo_log "Showing the status of the targeting director. Running: ${BOSH_CLI} environment"
    ${BOSH_CLI} environment
    rvalue=$?
    [ ${rvalue} != 0 ] && echo_log "ERROR" "cannot query Bosh director!"
    return ${rvalue}
}


bosh_uuid() {
    ${BOSH_CLI} --tty --no-color environment | awk '/^UUID/{ print $2 }'
    return ${PIPESTATUS[0]}
}


bosh_director_name() {
    ${BOSH_CLI} --tty --no-color environment | awk '/^Name/{ print $2 }'
    return ${PIPESTATUS[0]}
}


bosh_cpi_platform() {
    ${BOSH_CLI} --tty --no-color environment | awk '/^CPI/{ split($2,a,"_"); print a[1] }'
    return ${PIPESTATUS[0]}
}


# Generate a manifest/cloud-config/runtime-config by interpolating files
# BE SURE THE FUNCTION GETS ALWAYS THE 4th parameters
bosh_interpolate() {
    local final_manifest_file="${1}"
    local base_manifest="${2}"
    local manifest_operations_path="${3}"
    local manifest_vars_path="${4}"
    local manifest_var_files_file="${5}"
    shift 5
    local args="${@}"

    local bosh_operations=()
    local bosh_varsfiles=()
    local bosh_varfiles=()
    local operations=()
    local rvalue
    local output
    local varid
    local varfile
    local cmd="${BOSH_CLI} interpolate"

    echo_log "INFO" "Generating interpolated manifests from operations ${manifest_operations_path} ..."
    if [ ! -d ${manifest_operations_path} ]
    then
        if [ -z "${base_manifest}" ]
        then
            echo_log "ERROR" "cannot find base manifest!"
            return 1
        fi
        cmd="${cmd} ${base_manifest}"
    else
        # Get list of operation files by order in the specific path
        while IFS=  read -r -d $'\0' line
        do
            bosh_operations+=("${line}")
        done < <(find -L ${manifest_operations_path} -type f \( -name "*.yml" -o -name "*.yaml" \) -print0 | sort -z)
        # check if there are files there
        if [ ${#bosh_operations[@]} == 0 ]
        then
            if [ -z "${base_manifest}" ]
            then
                echo_log "ERROR" "no base manifest and no files to interpolate!"
                return 1
            else
                echo_log "Using manifest with no interpolation files: ${manifest_operations_path} folder empty"
            fi
        fi
        if [ -z "${base_manifest}" ]
        then
            operations=("${bosh_operations[@]:1}")
            cmd="${cmd} ${bosh_operations[0]} ${operations[@]/#/-o }"
            base_manifest="${bosh_operations[0]}"
        else
            operations=("${bosh_operations[@]}")
            cmd="${cmd} ${base_manifest} ${operations[@]/#/-o }"
        fi
    fi
    # Load var-files
    if [ -n "${manifest_var_files_file}" ] && [ -r "${manifest_var_files_file}" ]
    then
        while read -r line
        do
            if [ -n "${line}" ]
            then
                varid="$(echo ${line%%:*})"
                varfile="$(echo ${line#*:})"
                # test if varfile is there
                if [ -r "${varfile}" ]
                then
                    bosh_varfiles+=("${varid}=${varfile}")
                else
                    echo_log "ERROR" "var-file ${varfile} not readable!"
                    return 1
                fi
            fi
        done <<<$(grep -v '^#' "${manifest_var_files_file}")
    fi
    cmd="${cmd} ${bosh_varfiles[@]/#/--var-file }"
    # Load vars files
    if [ -n "${manifest_vars_path}" ] && [ -d "${manifest_vars_path}" ]
    then
        while IFS=  read -r -d $'\0' line
        do
            bosh_varsfiles+=("${line}")
        done < <(find -L ${manifest_vars_path} -type f \( -name "*.yml" -o -name "*.yaml" \) -print0 | sort -z)
    fi
    # List of varsfiles with the proper path
    cmd="${cmd} ${bosh_varsfiles[@]/#/--vars-file }"
    echo_log "RUN" "${cmd} ${args} > ${final_manifest_file}"
    # Exec process
    output="$(${cmd} ${args} > >(tee -a ${PROGRAM_LOG}) 2>&1)"
    rvalue=$?
    if [ ${rvalue} == 0 ]
    then
        echo "${output}" > "${final_manifest_file}"
        echo_log "OK" "Manifest generated at ${final_manifest_file}"
    else
        echo_log "ERROR" ${output}
    fi
    return ${rvalue}
}


bosh_update_runtime_or_cloud_config() {
    local kind="${1}"
    local path="${2}"
    local force="${3}"
    local manifest="${4}"

    local rvalue=0
    local output
    local name=$(basename "${path}")
    local varsdir="${path}/${DEPLOYMENT_VARS}"
    local bosh_varsfiles=()
    local bosh_configfiles=()
    local varsenv=$(echo ${name^^} | tr '-' '_')
    local cmd=""
    local configdir
    local defaultmanifest
    local manifestfullpath
    local manifestfile
    local release

    if [ -z "${manifest}" ] || [ ! -r "${manifest}" ]
    then
        defaultmanifest=0
        if [ "${kind}" == "runtime" ]
        then
            configdir="${path}/${DEPLOYMENT_RUNTIMEC}"
        else
            # cloud-config
            configdir="${path}/${DEPLOYMENT_CLOUDC}"
        fi
        if [ ! -d "${configdir}" ]
        then
            echo_log "No ${kind} configuration. Ignoring!"
            return 1
        fi
        while IFS=  read -r -d $'\0' line
        do
            bosh_configfiles+=("${line}")
        done < <(find -L ${configdir} -type f \( -name "*.yml" -o -name "*.yaml" \) -print0 | sort -z)
        if [ -n "${force}" ] && [ "${force}" == "1" ]
        then
            cmd="${BOSH_CLI} -n update-config --type=${kind} --vars-env=${varsenv}"
        else
            cmd="${BOSH_CLI} update-config --type=${kind} --vars-env=${varsenv}"
        fi
        echo_log "INFO" "Updating ${kind} config with files from ${configdir} ..."
    else
        defaultmanifest=1
        if [ -n "${force}" ] && [ "${force}" == "1" ]
        then
            cmd="${BOSH_CLI} -n update-${kind}-config --vars-env=${varsenv}"
        else
            cmd="${BOSH_CLI} update-${kind}-config --vars-env=${varsenv}"
        fi
        bosh_configfiles+=("${manifest}")
        echo_log "INFO" "Updating DEFAULT ${kind} config ..."
    fi
    # Load vars files
    if [ -n "${varsdir}" ] && [ -d "${varsdir}" ]
    then
        while IFS=  read -r -d $'\0' line
        do
            bosh_varsfiles+=("${line}")
        done < <(find -L ${varsdir} -type f \( -name "*.yml" -o -name "*.yaml" \) -print0 | sort -z)
    fi
    # List of varsfiles with the proper path
    cmd="${cmd} ${bosh_varsfiles[@]/#/--vars-file }"
    for manifestfullpath in "${bosh_configfiles[@]}"
    do
        manifestfile=$(basename ${manifestfullpath})
        localcmd="${cmd}"
        [ "${defaultmanifest}" == "0" ] && localcmd="${localcmd} --name=${name}-${manifestfile%.*}"
        localcmd="${localcmd} ${manifestfullpath}"
        echo_log "RUN" "${localcmd}"
        exec 3>&1                     # Save the place that stdout (1) points to.
        {
            output="$(${localcmd} 2>&1 1>&3)"
            rvalue=$?
        } 2> >(tee -a ${PROGRAM_LOG} >&2)
        exec 3>&-                    # Close FD #3
        [ ${rvalue} != 0 ] && break
    done
    if [ ${rvalue} == 0 ] && [ "${kind}" == "runtime" ]
    then
        echo_log "INFO" "Updating/uploading runtime-config bosh releases ..."
        for manifestfullpath in "${bosh_configfiles[@]}"
        do
            for release in $(${YQ} read ${manifestfullpath} 'releases[*].url')
            do
                localcmd="${BOSH_CLI} upload-release ${release}"
                echo_log "RUN" "${localcmd}"
                exec 3>&1                     # Save the place that stdout (1) points to.
                {
                    output="$(${localcmd} 2>&1 1>&3)"
                    rvalue=$?
                } 2> >(tee -a ${PROGRAM_LOG} >&2)
                exec 3>&-                    # Close FD #3
                [ ${rvalue} != 0 ] && break
            done
        done
    fi
    if [ ${rvalue} == 0 ]
    then
        echo_log "OK" "${kind} updated!"
    else
        echo_log "ERROR" ${output}
    fi
    return ${rvalue}
}


run_terraform_output() {
    local path="${1}"

    local terraform_path="${path}/${DEPLOYMENT_TERRAFORM_INPUT}"
    if [ -d "${terraform_path}" ]
    then
        echo_log "INFO" "Executing terraform output to generate variables file' ..."
        echo_log "RUN" "${TERRAFORM} output --json | ${JQ} -M -r 'to_entries[] | \"\(.key): \(.value.value | @sh)\"' > ${path}/${DEPLOYMENT_TERRAFORM_OUTPUT}"
        (
            cd ${terraform_path}
            echo "# Automatically generated by snpaas cli during deploy by running: terraform output --json"
            exec ${TERRAFORM} output --json | ${JQ} -M -r 'to_entries[] | "\(.key): \(.value.value | @sh)"' 2> >(tee -a ${PROGRAM_LOG} >&2)
        ) > ${path}/${DEPLOYMENT_TERRAFORM_OUTPUT} &
        wait $!
        rvalue=$?
        if [ ${rvalue} != 0 ]
        then
            echo_log "ERROR" "Running terraform output!. Please make sure that you have initialized terraform, manually or in a pre-start script, by running: terraform init"
        fi
        return ${rvalue}
    else
        echo_log "No '${terraform_path}' found. Ignoring!"
    fi
    return 0
}


run_script() {
    local name="${1}"
    local path="${2}"
    local program="${3}"
    shift 3

    if [ -x "${path}/${program}" ]
    then
        echo_log "INFO" "Executing '${name}' ..."
        echo_log "RUN" "${path}/${program}"
        (
            cd ${path}
            exec ./${program} $@ > >(tee -a ${PROGRAM_LOG}) 2>&1
        ) &
        wait $!
        rvalue=$?
        if [ ${rvalue} != 0 ]
        then
            echo_log "ERROR" "Running script!"
        fi
        return ${rvalue}
    else
        echo_log "No '${path}/${program}' found. Ignoring!"
    fi
    return 0
}


# create-env, destroy-env interpolate bosh directors environments
# path=.
bosh_deployment_manage() {
    local path="${1}"
    local action="${2}"
    local manifest="${3}"
    local force="${4}"
    shift 4

    local rvalue
    local cmd
    local deployment="${path}"
    local prepare="${DEPLOYMENT_PREPARE_SCRIPT}"
    local finish="${DEPLOYMENT_FINISH_SCRIPT}"
    local base=""

    if [ ! -d "${path}" ]
    then
        echo_log "ERROR" "Could not find deployment folder ${path}!"
        return 1
    fi
    # Run prepare script
    run_script "prepare" "${path}" "${prepare}" "${action}"
    rvalue=$?
    [ ${rvalue} != 0 ] && return ${rvalue}
    case ${action} in
      interpolate|int|bosh-int|bosh-interpolate)
        bosh_interpolate_manifest "${deployment}" "${manifest}" ${@}
        rvalue=$?
        ;;
      destroy|bosh-destroy|delete|bosh-delete)
        bosh_destroy "${deployment}" ${@}
        rvalue=$?
        ;;
      deploy|bosh-deploy)
        bosh_deploy "${deployment}" "${manifest}" "${force}" ${@}
        rvalue=$?
        ;;
      create-env)
        bosh_manage_director "create-env" "${deployment}" "${manifest}" ${@}
        rvalue=$?
        ;;
      delete-env)
        bosh_manage_director "delete-env" "${deployment}" "${manifest}" "${force}" ${@}
        rvalue=$?
        ;;
      bosh-cloud-config|cloud-config)
        bosh_update_runtime_or_cloud_config "cloud" "${deployment}" "${force}"
        rvalue=$?
        ;;
      bosh-runtime-config|runtime-config)
        bosh_update_runtime_or_cloud_config "runtime" "${deployment}" "${force}"
        rvalue=$?
        ;;
      *)
        echo_log "ERROR" "Deployment action not supported!"
        rvalue=1
      ;;
    esac
    # Run finish script
    run_script "finish" "${path}" "${finish}" "${action}" "${rvalue}"
    #rvalue=$?
    return ${rvalue}
}


bosh_destroy() {
    local deployment="${1}"
    shift
    local args="${@}"

    local cmd="${BOSH_CLI} ${BOSH_EXTRA_OPS} -n -d ${deployment} delete-deployment --force"
    local output
    local rvalue
    local director_uuid
    local director_name
    local credentials
    local credential
    
    director_name=$(bosh_director_name 2>&1)
    rvalue=$?
    if [ ${rvalue} != 0 ]
    then
        echo_log "ERROR" "Could not get to Bosh Director: ${director_name}"
        return 1
    fi
    director_uuid=$(bosh_uuid)
    echo_log "INFO" "Deleting deployment ${deployment} on Bosh Director: ${director_name}  uuid=${director_uuid}"
    echo_log "RUN" "${cmd} ${args}"
    exec 3>&1                     # Save the place that stdout (1) points to.
    {
        output=$(${cmd} ${args} 2>&1 1>&3)
        rvalue=$?
    } 2> >(tee -a ${PROGRAM_LOG} >&2)
    exec 3>&-                    # Close FD #3
    if [ ${rvalue} == 0 ]
    then
        echo_log "OK" "Deployment deleted"
    else
        echo_log "ERROR" "${output}"
        return ${rvalue}
    fi
    echo_log "INFO" "Deleting deployment secrets in credhub ..."
    credentials=$(${CREDHUB_CLI} find -j -p "/${director_name}/${deployment}" | ${JQ} -r .credentials[].name)
    rvalue=$?
    if [ -z "${credentials}" ]
    then
        echo_log "INFO" "No credentials found in credhub"
    fi
    if [ ${rvalue} == 0 ] && [ -n "${credentials}" ]
    then
        for credential in ${credentials}
        do
            echo_log "RUN" "${CREDHUB_CLI} delete -n '${credential}'"
            ${CREDHUB_CLI} delete -n "${credential}" >> ${PROGRAM_LOG} 2>&1
        done
    else
        echo_log "ERROR" "Cannot delete credentials in Credhub"
    fi
    return ${rvalue}
}


bosh_deploy() {
    local deployment="${1}"
    local manifest="${2}"
    local force="${3}"
    shift 3

    local rvalue=0
    local director_uuid
    local director_name

    director_name=$(bosh_director_name 2>&1)
    rvalue=$?
    if [ ${rvalue} != 0 ]
    then
        echo_log "ERROR" "Could not get to Bosh Director: ${director_name}"
        return 1
    fi
    director_uuid=$(bosh_uuid)
    echo_log "INFO" "Deploying deployment ${deployment} via Bosh Director: ${director_name}  uuid=${director_uuid}"
    # Terraform output
    run_terraform_output "${deployment}"
    rvalue=$?
    [ ${rvalue} != 0 ] && return ${rvalue}
    # Check if cloud-config and runtime-config need to be updated
    #bosh_update_runtime_or_cloud_config "runtime" "${deployment}" "${force}"
    #rvalue=$?
    #[ ${rvalue} != 0 ] && return ${rvalue}
    #bosh_update_runtime_or_cloud_config "cloud" "${deployment}" "${force}"
    #rvalue=$?
    #[ ${rvalue} != 0 ] && return ${rvalue}
    bosh_deploy_manifest "${deployment}" "${manifest}" "${force}" ${@}
    rvalue=$?
    return ${rvalue}
}


bosh_manage_director() {
    local action="${1}"
    local deployment="${2}"
    local manifest="${3}"
    shift 3
    local args="${@}"

    local cmd
    local output
    local rvalue=0
    local base=""
    local state="${deployment}/${DEPLOYMENT_STATE}"
    local secrets="${deployment}/${DEPLOYMENT_CREDS}"
    local operations="${deployment}/${DEPLOYMENT_OPERATIONS}"
    local varsdir="${deployment}/${DEPLOYMENT_VARS}"
    local varfiles="${deployment}/${DEPLOYMENT_VARS_FILE}"
    local default_runtimec="${deployment}/${DEPLOYMENT_DEFAULT_RUNTIMEC}"
    local default_cloudc="${deployment}/${DEPLOYMENT_DEFAULT_CLOUDC}"
    local varsenv=$(basename "${deployment}")

    if [ ! -d "${deployment}" ]
    then
        echo_log "ERROR" "Could not find deployment folder ${deployment}!"
        return 1
    fi
    # If there is a operations folder, the base should be there, otherwise take
    # the first yml manifest (lexical order) as base in the deployment folder, and skip the operations folder.
    # Useful for deployments with no operations.
    base=""
    if [ ! -d "${operations}" ]
    then
        base=$(find -L "${deployment}" -maxdepth 1 -type f \( -name "*.yml" -o -name "*.yaml" \) -a ! -name "${DEPLOYMENT_CREDS}"  | sort | head -n 1)
    fi
    bosh_interpolate "${manifest}" "${base}" "${operations}" "${varsdir}" "${varfiles}"
    rvalue=$?
    if [ ${rvalue} != 0 ]
    then
        echo_log "ERROR" "Cannot generate manifest for ${deployment}"
        return 1
    fi
    varsenv=$(echo ${varsenv^^} | tr '-' '_')
    args="--vars-env=${varsenv} ${args}"
    [ -r "${secrets}" ] || secrets=""
    [ -n "${DEPLOYMENT_NAME_VAR}" ] && args="--var=${DEPLOYMENT_NAME_VAR}=${deployment} ${args}"

    cmd="${BOSH_CLI} ${action} --state=${state} --vars-store=${secrets} ${manifest}"
    echo_log "INFO" "Running ${action} on '${manifest}' as Bosh Director ..."
    echo_log "RUN" "${cmd} ${args}"
    exec 3>&1                     # Save the place that stdout (1) points to.
    {
        output=$(${cmd} ${args} 2>&1 1>&3)
        rvalue=$?
    } 2> >(tee -a ${PROGRAM_LOG} >&2)
    exec 3>&-                    # Close FD #3
    if [ ${rvalue} == 0 ]
    then
        echo_log "OK" "Bosh deployed"
    else
        echo_log "ERROR" ${output}
    fi
    # Manage DEFAULT runtime and cloud configs
    if [ ${rvalue} == 0 ] && [ "${action}" == "create-env" ]
    then
        if [ -r "${default_runtimec}" ]
        then
            bosh_update_runtime_or_cloud_config "runtime" "${deployment}" "${force}" "${default_runtimec}"
            rvalue=$?
        fi
        if  [ -r "${default_cloudc}" ] &&  [ ${rvalue} == 0 ]
        then
            bosh_update_runtime_or_cloud_config "cloud" "${deployment}" "${force}" "${default_cloudc}"
            rvalue=$?
        fi
    fi
    return ${rvalue}
}


bosh_deploy_manifest() {
    local deployment="${1}"
    local manifest="${2}"
    local force="${3}"
    shift 3
    local args="${@}"

    local cmd
    local output
    local rvalue
    local base=""
    local secrets="${deployment}/${DEPLOYMENT_CREDS}"
    local operations="${deployment}/${DEPLOYMENT_OPERATIONS}"
    local varsdir="${deployment}/${DEPLOYMENT_VARS}"
    local varfiles="${deployment}/${DEPLOYMENT_VARS_FILE}"
    local varsenv=$(basename "${deployment}")

    if [ ! -d "${deployment}" ]
    then
        echo_log "ERROR" "Could not find deployment folder ${deployment}!"
        return 1
    fi
    # If there is a operations folder, the base should be there, otherwise take
    # the first yml manifest (lexical order) as base in the deployment folder, and skip the operations folder.
    # Useful for deployments with no operations.
    base=""
    if [ ! -d "${operations}" ]
    then
        base=$(find -L "${deployment}" -maxdepth 1 -type f \( -name "*.yml" -o -name "*.yaml" \) -a ! -name "${DEPLOYMENT_CREDS}"  | sort | head -n 1)
    fi
    bosh_interpolate "${manifest}" "${base}" "${operations}" "${varsdir}" "${varfiles}"
    rvalue=$?
    if [ ${rvalue} != 0 ]
    then
        echo_log "ERROR" "Cannot generate manifest for ${deployment}"
        return 1
    fi
    varsenv=$(echo ${varsenv^^} | tr '-' '_')
    args="--vars-env=${varsenv} ${args}"
    [ -r "${secrets}" ] || secrets=""
    [ -n "${DEPLOYMENT_NAME_VAR}" ] && args="--var=${DEPLOYMENT_NAME_VAR}=${deployment} ${args}"

    if [ -n "${force}" ] && [ "${force}" == "1" ]
    then
        cmd="${BOSH_CLI} ${BOSH_EXTRA_OPS} -n -d ${deployment} deploy --fix ${manifest}"
    else
        cmd="${BOSH_CLI} ${BOSH_EXTRA_OPS} -d ${deployment} deploy --fix --no-redact ${manifest}"
    fi
    [ -n "${secrets}" ] && cmd="${cmd} --vars-store ${secrets}"
    echo_log "INFO" "Deploying '${manifest}' as deployment ${deployment} ..."
    echo_log "RUN" "${cmd} ${args}"
    exec 3>&1                     # Save the place that stdout (1) points to.
    {
        output=$(${cmd} ${args} 2>&1 1>&3)
        rvalue=$?
    } 2> >(tee -a ${PROGRAM_LOG} >&2)
    exec 3>&-                    # Close FD #3
    if [ ${rvalue} == 0 ]
    then
        echo_log "OK" "Deployment updated"
    else
        echo_log "ERROR" ${output}
    fi
    return ${rvalue}
}


bosh_interpolate_manifest() {
    local deployment="${1}"
    local manifest="${2}"
    shift 2
    local args="${@}"

    local rvalue
    local base=""
    local operations="${deployment}/${DEPLOYMENT_OPERATIONS}"
    local varsdir="${deployment}/${DEPLOYMENT_VARS}"
    local varfiles="${deployment}/${DEPLOYMENT_VARS_FILE}"

    if [ ! -d "${deployment}" ]
    then
        echo_log "ERROR" "Could not find deployment folder ${deployment}!"
        return 1
    fi
    # If there is a operations folder, the base should be there, otherwise take
    # the first yml manifest (lexical order) as base in the deployment folder, and skip the operations folder.
    # Useful for deployments with no operations.
    base=""
    if [ ! -d "${operations}" ]
    then
        base=$(find -L "${deployment}" -maxdepth 1 -type f \( -name "*.yml" -o -name "*.yaml" \) -a ! -name "${DEPLOYMENT_CREDS}"  | sort | head -n 1)
    fi
    bosh_interpolate "${manifest}" "${base}" "${operations}" "${varsdir}" "${varfiles}"
    rvalue=$?
    if [ ${rvalue} == 0 ]
    then
        echo_log "OK" "Deployment manifest generated"
    else
        echo_log "ERROR" "Cannot generate manifest for ${deployment}"
    fi
    return ${rvalue}
}


bosh_upload_stemcell() {
    local version="${1}"
    local os=${2:-"ubuntu-xenial"}
    local sha="${3}"

    local rvalue
    local stemcell
    local cpi
    local director_name
    local cmd

    director_name=$(bosh_director_name 2>&1)
    rvalue=$?
    if [ ${rvalue} != 0 ]
    then
        echo_log "ERROR" "Could not get to Bosh Director: ${director_name}"
        return ${rvalue}
    fi
    cpi=$(bosh_cpi_platform)
    echo_log "INFO" "Uploading ${os} version ${version} for ${cpi} to Bosh Director ..."
    case "${cpi}" in
    gcp|google)
        stemcell="https://s3.amazonaws.com/bosh-core-stemcells/${version}/bosh-stemcell-${version}-google-kvm-${os}-go_agent.tgz"
        ;;
    vsphere)
        stemcell="https://s3.amazonaws.com/bosh-core-stemcells/${version}/bosh-stemcell-${version}-vsphere-esxi-${os}-go_agent.tgz"
        ;;
    openstack)
        stemcell="https://s3.amazonaws.com/bosh-core-stemcells/${version}/bosh-stemcell-${version}-openstack-kvm-${os}-go_agent.tgz"
        ;;
    aws)
        stemcell="https://s3.amazonaws.com/bosh-core-stemcells/${version}/bosh-stemcell-${version}-aws-xen-hvm-${os}-go_agent.tgz"
        ;;
    esac
    cmd="${BOSH_CLI} upload-stemcell --version=${version}"
    [ -n "${sha}" ] && cmd="${cmd} --sha1=${sha}" || cmd="${cmd} --fix"
    {
        echo_log "RUN" "${cmd} ${stemcell}"
        infor=$(${cmd} "${stemcell}" 2>&1)
        rvalue=$?
    }
    if [ ${rvalue} == 0 ]
    then
        echo "${infor}"
        echo
        echo_log "OK" "Stemcell ${stemcell} uploaded"
    else
        echo_log "ERROR" "${infor}"
    fi
    return ${rvalue}
}


bosh_upload_release() {
    local release="${1}"
    local sha="${2}"

    local infor
    local director_name
    local cmd

    director_name=$(bosh_director_name 2>&1)
    rvalue=$?
    if [ ${rvalue} != 0 ]
    then
        echo_log "ERROR" "Could not get to Bosh Director: ${director_name}"
        return ${rvalue}
    fi
    echo_log "INFO" "Uploading ${release} to Bosh Director ${director_name} ..."
    cmd="${BOSH_CLI} upload-release"
    [ -n "${sha}" ] && cmd="${cmd} --sha1=${sha}" || cmd="${cmd} --fix"
    {
        echo_log "RUN" "${cmd} ${release}"
        infor=$(${cmd} "${release}" 2>&1)
        rvalue=$?
    }
    if [ ${rvalue} == 0 ]
    then
        echo "${infor}"
        echo
        echo_log "OK" "Release ${release} uploaded to Bosh Director"
    else
        echo_log "ERROR" "${infor}"
    fi
    return ${rvalue}
}


credhub_manage() {
    local path="${1}"
    local action="${2}"

    local deployment="${path}"
    local secrets="${path}/${DEPLOYMENT_CREDS}"
    local director_name
    local base

    director_name=$(bosh_director_name 2>&1)
    rvalue=$?
    if [ ${rvalue} != 0 ]
    then
        echo_log "ERROR" "Could not get to Bosh Director: ${director_name}"
        return 1
    fi
    echo_log "INFO" "Managing Credhub for Bosh Director: ${director_name}"
    base="/${director_name}/"
    case ${action} in
      "export")
        rm -f "${secrets}"
        credhub_export "${secrets}" "${deployment}" "${base}"
        rvalue=$?
        ;;
      "import")
        credhub_import "${secrets}" "${deployment}" "${base}"
        rvalue=$?
        ;;
      "list")
        credhub_list "${deployment}" "${base}"
        rvalue=$?
        ;;
      *)
        echo_log "ERROR" "Credhub action not supported!"
        rvalue=1
      ;;
    esac
    return ${rvalue}
}


credhub_list() {
    local deployment="${1}"
    local base="${2}"

    local fullp="${base}${deployment}/"
    local output
    local rvalue

    echo_log "Listing of credentials for ${fullp}: "
    echo_log "RUN" "${CREDHUB_CLI} find -p '${fullp}'"
    exec 3>&1                     # Save the place that stdout (1) points to.
    {
        output=$(${CREDHUB_CLI} find -p "${fullp}" 2>&1 1>&3)
        rvalue=$?
    } 2> >(tee -a ${PROGRAM_LOG} >&2)
    exec 3>&-                    # Close FD #3
    if [ ${rvalue} == 0 ]
    then
        echo "${output}"
        echo_log "OK" "Credentials"
    else
        echo_log "ERROR" "${output}"
    fi
    return ${rvalue}
}


credhub_export() {
    local output="${1}"
    local deployment="${2}"
    local base="${3}"

    local fullp="${base}${deployment}/"
    local pass
    local credentials
    local credential
    local reason
    local rvalue
    local kind

    echo_log "Exporting all variables for ${fullp} ..."
    echo_log "RUN" "${CREDHUB_CLI} find -p '${fullp}'"
    {
        credentials=$(${CREDHUB_CLI} find -p "${fullp}" 2>&1)
        rvalue=$?
    }
    if [ ${rvalue} == 0 ]
    then
        echo "${credentials}"
        credentials=$(echo "${credentials}" | awk '/name: /{ print $3 }')
        echo
    else
        echo_log "ERROR" "Could not list credentials in Credhub!: ${credentials}"
        return 1
    fi
    for credential in ${credentials}
    do
        echo_log "RUN" "${CREDHUB_CLI} get -n ${credential}"
        {
          reason="$(${CREDHUB_CLI} get -n ${credential} 2>&1)"
          rvalue=$?
        }
        if [ ${rvalue} != 0 ]
        then
            echo_log "ERROR" "Could not get ${credential} from Credhub: ${reason}"
            return 1
        else
            kind=$(echo "${reason}" | awk '/type: /{ $1=""; print }' | xargs)
            if [ "${kind}" == "value" ]
            then
                echo "${reason}" | sed -e 's/value:.*/value: <redacted>/g'
                echo
                pass=$(echo "${reason}" | awk '/value: /{ $1=""; print }' | xargs)
                pass="${pass%\"}"
                pass="${pass#\"}"
                echo "$(basename ${credential}): '${pass}'" >> "${output}"
            else
                echo "Skipping '${credential}', type ${kind} not supported"
            fi
        fi
    done
    echo_log "OK" "Credentials exported to ${output}"
    return 0
}


credhub_import() {
    local input="${1}"
    local deployment="${2}"
    local base="${3}"

    local fullp="${base}${deployment}/"
    local key
    local value
    local kind="value"
    local reason

    echo_log "Importing variables from ${input} ..."
    while read -r line && [[ -n "${line}" ]]
    do
        [[ "${line}" =~ ^#.*$ ]] && continue
        key=$(echo ${line} | xargs | cut -d':' -f 1)
        value=$(${BOSH_CLI} int "${input}" --path "/${key}")
        key="${fullp}${key}"
        {
          echo_log "RUN" "${CREDHUB_CLI} set --type ${kind} --name '${key}' --value '<redacted>'"
          reason=$(${CREDHUB_CLI} set --type ${kind} --name "${key}" --value "${value}" 2>&1)
          rvalue=$?
        }
        if [ ${rvalue} == 0 ]
        then
            echo "${reason}"
            echo
        else
            echo_log "ERROR" "Could not upload credential to Credhub!: ${reason}"
        fi
    done < "${input}"
    echo_log "OK" "Variables imported in Credhub path ${fullp}"
    return 0
}


# Trap signals and delete temp files

bosh_finish() {
    local rvalue=$?
    local files=("${@}")

    for f in "${files[@]}"
    do
        echo_log "Deleting temp file ${f}"
        rm -f "${f}"
    done
    echo_log "EXIT" "rc=${rvalue}"
    exit ${rvalue}
}


################################################################################

# Program
if [ "$0" == "${BASH_SOURCE[0]}" ]
then
    DELETE_MANIFEST=1
    MANIFEST="$(mktemp)"
    ACTION=""
    RVALUE=0
    STDOUT=0
    FORCE=0
    echo_log "Running '$0 $*' logging to '$(basename ${PROGRAM_LOG})'"
    # Parse main options
    while getopts ":hp:m:" opt
    do
        case ${opt} in
            h)
                usage
                exit 0
                ;;
            m)
                if [ "${OPTARG}" != "-" ]
                then
                    MANIFEST="${OPTARG}"
                    DELETE_MANIFEST=0
                else
                    STDOUT=1
                fi
                ;;
            :)
                die "Option -${OPTARG} requires an argument"
                ;;
        esac
    done
    shift $((OPTIND -1))
    SUBCOMMAND=$1
    shift  # Remove 'subcommand' from the argument list
    DEPLOYMENT_FOLDER=$(basename $1)
    shift  # Remove folder
    if [ -z "${DEPLOYMENT_FOLDER}" ]
    then
        usage
        die "Please tell me which folder you want to deploy!"
    fi
    bosh_system_check "${DEPLOYMENT_FOLDER}"
    if [ $? != 0 ]
    then
        usage
        die "Please fix your system to continue"
    fi
    if [ ${DELETE_MANIFEST} == 1 ]
    then
        trap "bosh_finish ${MANIFEST}" SIGINT SIGTERM SIGKILL
    else
        trap "bosh_finish" SIGINT SIGTERM SIGKILL
    fi
    OPTIND=0
    case "${SUBCOMMAND}" in
        # Parse options to each sub command
        help)
            usage
            exit 0
            ;;
        list-secrets|credhub-list-secrets)
            credhub_manage "${DEPLOYMENT_FOLDER}" "list"
            RVALUE=$?
            ;;
        export-secrets|credhub-export-secrets)
            credhub_manage "${DEPLOYMENT_FOLDER}" "export"
            RVALUE=$?
            ;;
        import-secrets|credhub-import-secrets)
            credhub_manage "${DEPLOYMENT_FOLDER}" "import"
            RVALUE=$?
            ;;
        deploy|bosh-deploy|create-env)
            # Process ask option
            while getopts ":f" optsub
            do
                case ${optsub} in
                    f)
                        FORCE=1
                        shift
                        ;;
                esac
            done
            #shift $((OPTIND -1))
            bosh_deployment_manage "${DEPLOYMENT_FOLDER}" "${SUBCOMMAND}" "${MANIFEST}" "${FORCE}" $@
            RVALUE=$?
            ;;
        interpolate|int|bosh-int|bosh-interpolate)
            bosh_deployment_manage "${DEPLOYMENT_FOLDER}" "int" "${MANIFEST}" $@
            RVALUE=$?
            [ ${STDOUT} == 1 ] && cat "${MANIFEST}"
            ;;
        bosh-cloud-config|cloud-config|bosh-runtime-config|runtime-config)
            bosh_deployment_manage "${DEPLOYMENT_FOLDER}" "${SUBCOMMAND}" "${MANIFEST}"
            RVALUE=$?
            [ ${STDOUT} == 1 ] && cat "${MANIFEST}"
            ;;
        destroy|bosh-destroy|delete|bosh-delete|delete-env)
            # Process force option
            while getopts ":f" optsub
            do
                case ${optsub} in
                    f)
                        FORCE=1
                        shift
                        ;;
                esac
            done
            #shift $((OPTIND -1))
            if [ ${FORCE} == 1 ]
            then
                bosh_deployment_manage "${DEPLOYMENT_FOLDER}" "${SUBCOMMAND}" "${MANIFEST}" "${FORCE}" $@
                RVALUE=$?
            else
                echo_log "Destroy an deployment requires a bit more force"
            fi
            ;;
        *)
            usage
            die "Invalid or no subcommand: ${SUBCOMMAND}"
            ;;
    esac
    [ ${DELETE_MANIFEST} == 1 ] && rm -f ${MANIFEST}
    if [ ${RVALUE} == 0 ]
    then
       echo_log "EXIT" "OK ${RVALUE}"
    else
       echo_log "EXIT" "ERROR, return code ${RVALUE}"
    fi
    exit ${RVALUE}
else
    bosh_system_check "${ENVIRONMENT_PATH}"
fi



