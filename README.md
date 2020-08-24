# ee-snpaas-cli

Engineering Enablement SNPaaS client.

This repository uses GitHub Actions to build the docker images. To release a new
version and push to DockerHub, please use an annotated tag: `git tag -a v3.13 -m "new release"`
and the github actions will do the rest: create a new release and push to DockerHub.


## Install
```
wget https://raw.githubusercontent.com/springernature/ee-snpaas-cli/master/snpaas -O snpaas && chmod a+x snpaas
```

## Don't want to install ...

SNPaaS Command line program is based on Docker. This command is just a shell
wrapper for docker execute something like (plus a lot of variables):

```
docker run --rm -v /home/$USER:/home/$USER -v $(pwd):/data -it platformengineering/snpaas-tools "${@}"
```

There is a python version of this program, but it has some issues, so it is
developed in the branch `python-cli` of this repo (the documentation is there).

Potentially it should run on Windows by installing Docker client command line
and delegating the execution to a box with docker daemon running (by defining
the proper environment variables), for example: the bastion host.

# Docker development

The `docker` folder have all the sources to create the Docker container.
Creating and publishing the container is done with the script `publish-dockers-dockerhub.sh`
which takes all folders (they must have a `Dockerfile`) and creates a Docker image
with the name of each folder. Once the image is created is automatically pushed
to dockerhub.com  using *platformengineering* account. You have to be loged in
with `docker login` in other to publish the Image.

* **Images are public available. DO NOT INCLUDE SECRETS THERE**
* **Images are public available. DO NOT INCLUDE SECRETS THERE**
* **Images are public available. DO NOT INCLUDE SECRETS THERE**
* **Images are public available. DO NOT INCLUDE SECRETS THERE**
* **Images are public available. DO NOT INCLUDE SECRETS THERE**
* **Images are public available. DO NOT INCLUDE SECRETS THERE**
* **Images are public available. DO NOT INCLUDE SECRETS THERE**
* **Images are public available. DO NOT INCLUDE SECRETS THERE**
* **Images are public available. DO NOT INCLUDE SECRETS THERE**
* **Images are public available. DO NOT INCLUDE SECRETS THERE**
* **Images are public available. DO NOT INCLUDE SECRETS THERE**
* **Images are public available. DO NOT INCLUDE SECRETS THERE**
* **Images are public available. DO NOT INCLUDE SECRETS THERE**

If you include them, your next task will be rotate all secrets everywhere!, without rest!
Anyway, **if you include secrets, you are doing something wrong. Docker images are not created to store secrets!**


## How this thing works?

1. `Dockerfile` includes all software (with specific versions).
2. Docker reads the `ENTRYPOINT ["/bin/bash", "/run.sh"]`, which will be always executed.
3. Docker will make available the current folder to the running container inside `/data`, all programs and scripts will be executed there.
4. The `run.sh` script reads the `.envrc` files and presents the usage (help) if needed.
5. Depending on the first argument, it will execute a command like `bosh`, `credhub` ... or it will run `manage-deployment.sh` script


The script `manage-deployment.sh` parses all the folder structure and runs the commands to manage a deployment. It is very verbose and always shows what it is doing, with colors, you can replicate everything copying the blue commands.


# Usage

Download the bash script and make it executable:

```
$ wget https://raw.githubusercontent.com/springernature/ee-snpaas-cli/master/snpaas -O snpaas && chmod a+x snpaas
```

Make sure to put it into a location included in your `$PATH`.
Once it is installed, type `snpaas`

```
$ snpaas 
# latest: Pulling from platformengineering/snpaas-tools
# Digest: sha256:98e43521714bbb536bb8d8b95f9bd7515cab8d9d61838ba2b723386465b99187
# Status: Image is up to date for platformengineering/snpaas-tools:latest
# docker.io/platformengineering/snpaas-tools:latest
#
# Running snpaas cli version 2.0
# Workdir root: /data
# Loading repository .envrc
# > Targeting Bosh director 10.80.202.6 as admin user
# Using environment '10.80.202.6' as client 'admin'
# 
# Name      test-bosh-env  
# UUID      a25d8a26-ec15-40fb-a6da-8e43b269bd11  
# Version   270.1.1 (00000000)  
# CPI       google_cpi  
# Features  compiled_package_cache: disabled  
#           config_server: enabled  
#           local_dns: enabled  
#           power_dns: disabled  
#           snapshots: disabled  
# User      admin  
# 
# Succeeded
# > Targeting Credhub 10.80.202.6:8844 as credhub-admin user
# Setting the target url: https://10.80.202.6:8844
# Login Successful
# > Defining gcloud config for project sn-paas-test region europe-west4 on zone europe-west4-a ...
# Updated property [compute/zone].
# Updated property [compute/region].
# Updated property [core/project].
#
# DONE LOADING .envrc

# No '.envrc' file found in current folder!

# Docker image: platformengineering/snpaas-tools

This docker image packages the tools SNPaaS team uses to manage the deployments.
It includes binary clients for cf, bosh, credhub ...
For more information go to: https://github.com/springernature/ee-snpaas-cli


# Usage

You can execute them directly. In the current folder you can define a '.envrc' file
with all environment variables you want to be setup in the running container.
If you do not have a '.envrc' file but you have the following environment variables
in your environment, then Bosh-cli, Credhub-cli and CF-cli will automatically log-in: 

    "BOSH_CLIENT"
    "BOSH_CLIENT_SECRET"
    "BOSH_ENVIRONMENT"
    "BOSH_CA_CERT"
    "CREDHUB_SERVER"
    "CREDHUB_CLIENT"
    "CREDHUB_SECRET"
    "CREDHUB_CA_CERT"
    "GCP_PROJECT"
    "GCP_ZONE"
    "GCP_REGION"
    "CF_USER"
    "CF_PASSWORD"
    "CF_API"
    "CF_ORG"
    "CF_SPACE"

Then you are ready to manage to manage deployments, with this subcommands and options:

    [main-options] <subcommand> [subcommand-options] <folder-deployment-name> [other-specific-subcommand-args]

Main-options:

    -h --help  Shows this help
    --noenv    Do not load .envrc files

Subcommand-Options:

    -m      Specify a manifest file, instead of generating a random one
    -p      Deployments path. Default is $DEPLOYMENTS_PATH

Subcommands:

    help            Shows this usage help

  Bosh/deployment subcommands

    interpolate [bosh-int-parameters]
                    Create the manifest for an environment
    create-env      Deploy a Bosh Director
    delete-env      Destroy a Bosh Director
    deploy [-f] [bosh-deploy-paramereters] 
                    Update or upgrade deployment after applying cloud/runtime configs
    destroy [-f] [bosh-destroy-parameters]
                    Delete deployment (does not delete cloud/runtime configs)
    cloud-config    Apply cloud-config operations files prefixed with deployment name
    runtime-config  Apply runtime-config operations files prefixed with deployment name
    import-secrets  Set secrets in Credhub from <deployment-folder>/$DEPLOYMENT_CREDS file
    list-secrets    List secrets from Credhub for <deployment-folder>
    export-secrets  Download secrets from Credhub to <deployment-folder>/$DEPLOYMENT_CREDS
    agent-certificates
                    Scan Bosh vms of a deployment (if provided as argument, otherwise it
                    will scan all vms) looking for Bosh Agent certificates, warning those
                    vms with certificates about to expire. Helps finding VMs which need to
                    be recreated when rotating Bosh Agent certificates.

  CloudFoundry subcommands (Please define CF_ environment variables!)

    cf-top                  top like command for Cloudfoundry
    cf-disk                 Full disk usage report
    cf-mem                  Memory usage report
    cf-users                List users and roles
    cf-usage                Show usage
    cf-docker               List docker images
    cf-app-stats <app>      Graphical application stats
    cf-mysql <service>      Connect with a mysql database to perform commands
    cf-route-lookup <route> CF route lookup

  You can type any other (interactive) commands

    bosh
    cf
    terraform
    bash
    ...


# Folder structure:

    <deployment-folder>
    ├── <boshrelease1-git-submodule-folder>
    ├── <boshrelease2-git-submodule-folder>
    ├── ...
    ├── [state.json]
    ├── [cloud-config.yml]
    ├── [runtime-config.yml]
    ├── var-files.yml
    ├── prepare.sh
    ├── finish.sh
    ├── operations
    │   ├── 00-base-manifest.yml -> ../<boshrelease1-git-submodule-folder>/manifest/base.yml
    │   ├── 10-operation.yml -> ../<boshrelease1-git-submodule-folder>/manifest/operations/operation.yml
    │   ├── 20-operation2.yml -> ../<boshrelease1-git-submodule-folder>/manifest/operations/operation2.yml
    │   ├── 99-springer-nature-operation-custom.yml
    ├── secrets.yml
    ├── runtime-config
    │   ├── local-runtime-config-file-for-deployment.yml
    ├── cloud-config
    │   ├── local-cloud-config-file-for-deployment.yml
    └── variables
        ├── variables-custom1.yml
        ├── variables-custom1.yml
        └── variables-provided.yml -> ../<boshrelease1-git-submodule-folder>/manifest/vars.yml

* 'state.json' maintains the CURRENT STATE of the Director. It needs to be commited and pushed
  everytime Bosh director is updated/created.
* 'cloud-config.yml' is the DEFAULT cloud-config AUTOMATICALLY applied after Director is updated (always)
* 'runtime-config.yml' is the DEFAULT runtime-config AUTOMATICALLY applied after Director is updated (always)
* 'var-files.yml' is a simple yaml key-value store to define 'var-file' arguments to Bosh client.
   Each line of this file will become an argument of '--var-file' parameters, eg:
   'director_gcs_credentials_json: ../gcp-creds/bosh-user/sn-paas-74d6f8c8e43e.json'
   will become an command line argument 
   '--var-file director_gcs_credentials_json=../gcp-creds/bosh-user/sn-paas-74d6f8c8e43e.json'.
   Files are relative paths to the folder where snpaas-cli is being executed (do not use absolute paths here!).
* 'prepare.sh' script executed BEFORE ALL actions. If exits with error, the entire process stops.
  It receives as first argument the ACTION executed in snpaas-cli.
* 'finish.sh' script executed AFTER ALL actions (last one before snpaas-cli exits).
  It receives as first argument the ACTION executed in snpaas-cli and the second argument
  is the EXIT code of the snpaas action executed (normally, 0 if no error, gt 1 otherwise).
* 'operations' folder is a set of links to other files (normally in the git submodules)
  or files defining Bosh client operations files. Snpaas-cli generates a list of files alphabetically
  sorted by name. Order in operations files is important so, files are named with a
  numerical prefix.
* 'secrets.yml' holds all secrets (users, passwords and certificates) created by bosh-cli
  create-env action (formerly called creds.yml). It is an important file, if it gets lost, all
  credentials will be regenerated and everything will need to get redeployed!.
* 'cloud-config' folder defines NON-DEFAULT (named) cloud configs for Bosh. Those
  are not applied automatically. They need to be applied with
  'snpaas cloud-config <folder-director-name>' (or manually). The name of each cloud-config
  will be '<deployment-or-director_name>-<name_of_the_file_without_extension>'.
* 'runtime-config' folder defines NON-DEFAULT (named) runtime configs for Bosh. Those
  are not applied automatically. They need to be applied with
  'snpaas runtime-config <folder-director-name>' (or manually). The name of each runtime-config
  will be '<deployment-or-director_name>-<name_of_the_file_without_extension>'.
* 'variables' folder holds a set of files with variables being used in the runtime/cloud
  configs or manifests/operations files. There is no order in those files and potentially
  they can be generated by Terraform of in the Prepare script.

Snpaas-cli will try to find variables in the environment, with the prefix of the
folder, e.g. if the deployment folder is "cf-test" and you have defined an variable 
"((stemcell))" in an operations file, you can define a variable like
"export CF_TEST_stemcell=ubuntu-xenial" and it will be used.

Secrets processed by this program are type 'value' and they will be imported/exported
from Credhub from/to a 'secrets.yml' file. When interpolate or deploy, the program
will check if there is a secrets file, if so, it will be used as store for generated
secrets automatically. If you want to force the script to generate and store
secrets there, just create an empty file: "touch secrets.yml" otherwise Bosh will
use Credhub. So make sure you do not have a 'secrets.yml' if you want to store all
credentials in Credhub. To sum up:

* Use a 'secrets.yml' file to export/import credentials from Credhub, then delete
  it to avoid confusion between Credhub and 'secrets.yml'.
* If there is no Credhub, create an empty 'secrets.yml' file. All credentials will
  be generated and stored there.
* Do not use 'secrets.yml' in any other situation.

You can add a couple of scripts "prepare.sh" and "finish.sh" which will be executed
automatically before and after the action (destroy, deploy or interpolate). Both
will receive the action as first argument, and the "finish.sh" script will also get
the exit code from the action (the finish script is always executed, even if the 
action fails).

The operations file is not required if you have a simple manifest which does not need
operations files. In this situation, just copy the manifest to the deployment folder
and make sure there is no operations folder there. The first yaml file (in lexical
order) will be taken as manifest and deployed, so make sure you call the manifest
file properly (secrets.yml is always ignored, so do not worry about it).

When deploying a Bosh Director, a state file 'state.json' will be created and
the DEFAULT cloud-config and runtime-config (name=default!) will be applied AUTOMATICALLY
if the deployment was successfully done.

# Usage examples

Given a typical deployment folder called 'app-logging' with this structure:

    app-logging
    ├── prepare.sh
    ├── runtime-config
    │   ├── dns.yml
    │   └── mtail.yml
    ├── cloud-config
    │   └── vm_types.yml
    ├── operations
    │   ├── 00-base.yml -> ../cf-logging-boshrelease/manifest/logstash.yml
    │   ├── 20-cf-apps-es.yml -> ../cf-logging-boshrelease/manifest/operations/pipelines/cf-apps-es-throttling.yml
    │   ├── 25-add-statsd-conf.yml -> ../cf-logging-boshrelease/manifest/operations/add-statsd-conf.yml
    │   ├── 30-add-throttle-param.yml -> ../cf-logging-boshrelease/manifest/operations/add-throttle-param.yml
    │   ├── 50-add-es-cloud-id.yml -> ../cf-logging-boshrelease/manifest/operations/add-es-cloud-id.yml
    │   ├── 50-add-es-xpack.yml -> ../cf-logging-boshrelease/manifest/operations/add-es-xpack.yml
    │   ├── 80-add-logstash-exporter.yml -> ../cf-logging-boshrelease/manifest/operations/add-logstash-exporter.yml
    │   ├── 90-add-release-version.yml -> ../cf-logging-boshrelease/manifest/operations/add-release-version.yml
    │   ├── 99-deployment-settings.yml
    │   └── 99-iaas.yml -> ../cf-logging-boshrelease/manifest/operations/add-iaas-parameters.yml
    ├── secrets.yml
    └── variables
        ├── iaas.yml
        ├── throttle-param.yml
        └── vars-release-version.yml -> ../cf-logging-boshrelease/manifest/vars-release-version.yml

In the above structure 'cf-logging-boshrelease' is a git submodule. The idea is reuse
resources from there (normally operations files).

* To deploy or update the deployment called 'app-logging', execute: 'deploy app-logging'.
  If you do not want to answer 'y/n' question when bosh runs, just use '-f' option:
  'deploy app-logging -f'
* To list secrets of the deployment from Credhub: 'list-secrets app-logging'
* Exporting the secrets of the deployment from Credhub to file 'app-logging/secrets.yml'
  is done with: 'export-secrets app-logging'. Only credentials type value are supported.
* Import the secrets of the deployment to Credhub from a file 'app-logging/secrets.yml':
  'import-secrets app-logging'. All credentials will be imported as type value.
* In order to apply the name of the folder to the deployment, you need to provide
  an operations file with this operation.

      - type: replace
        path: /name
        value: ((deployment_name))

  The variable 'deployment_name' is provided by the program and taken from the
  folder name

* It is possible to define variables in the runtime/cloud configs or
  manifests/operations files and the program will try to find those variables in
  the environment, with the prefix of the folder, e.g. if the deployment folder 
  is "cf-test" and you have defined an variable "((stemcell))" in an operations
  file, you can define a variable like "export CF_TEST_stemcell=ubuntu-xenial"
  and it will be used.


# Why?

* Avoid writting documentation about each deployment. Each folder has a specific
  structure, the script only goes through the folder structure and generates
  and applies the operations to the base manifest.
* Make it easy to manage bosh deployments. If the deployment folder is properly
  done, replicating it for testing purposes is as easy as clonning the folder
  and deploy again.
* Easily manage Credhub secrets in a deployment. One can import, export and
  list secrets from files to Credhub (Only secrets type value, the other ones 
  are managed via the 'variables' section in a manifest!).
* Show you the commands it runs each time, with colorized output in order to
  stand out if something went wrong.
* Loose coupled. The sript is a wrapper for Bosh and Credhub clients. If you do
  not like the script, you do not have to use it. The folder structure is 
  self-documented, so you only need to build the bosh and credhub parameters
  from these files.


The script always show what is executing (blue commands), if something fails,
just copy the blue commands and execute them step by step.


# Programs and versions installed

Additionally you can directly execute all the following programs installed, just
by typing then as argument, e.g:

	snpaas credhub find -p '/director-name/'

  BBR:  1.7.2
  CERTSTRAP:  1.1.1
  YQ:  3.3.2
  CF6_PLUGINS:  /opt
  CF_CLI:  6.45.0
  VARSTOCREDHUB:  0.1.0
  CF_RTR:  2.22.0
  HALFPIPE:  3.34.0
  FLY:  6.3.0
  HOME:  /home/snpaas
  VERSION:  3.12
  GCLOUD_SDK:  298.0.0
  USER:  snpaas
  SPIFF:  1.0.8
  BOSH_CLI:  6.3.0
  CREDHUB:  2.7.0
  DATADIR:  /data
  TERRAFORM:  0.12.23
  JQ:  1.5
  SPRUCE:  1.18.0
  VAULT:  1.4.2

```

# Author

Springer Nature Engineering Enablement (EE), Jose Riguera Lopez (jose.riguera@springer.com)


