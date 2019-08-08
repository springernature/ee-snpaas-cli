# ee-snpaas-cli

SNPaaS Command line program is based on Docker. This command is just a shell
wrapper for docker to execute:

```
docker run --rm -v $(pwd):/data -it platformengineering/snpaas-tools "${@}"
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
# Digest: sha256:623fc1c30738d0170f5a7ff5cbf1a6561ab183f0426c13ab62d7bc61f52b4b2d
# Status: Image is up to date for platformengineering/snpaas-tools:latest
#
# > Targeting Bosh director 10.80.192.6 as admin user
# Using environment '10.80.192.6' as client 'admin'
# 
# Name      live-bosh-env  
# UUID      4a49742f-95eb-43bd-815c-f9077d6411d7  
# Version   265.2.0 (00000000)  
# CPI       google_cpi  
# Features  compiled_package_cache: disabled  
#           config_server: enabled  
#           dns: disabled  
#           snapshots: disabled  
# User      admin  
# 
# Succeeded
# > Targeting Credhub 10.80.192.6:8844 as credhub-admin user
# Setting the target url: https://10.80.192.6:8844
# Login Successful
# > Defining gcloud config for project sn-paas region europe-west4 on zone europe-west4-a ...
# Updated property [compute/zone].
# Updated property [compute/region].
# Updated property [core/project].
# Done loading MAIN .envrc
# No '.envrc' file found in current folder!
# Running snpaas cli version 1.1


# Docker image: platformengineering/snpaas-tools

This docker image packages the tools SNPaaS team uses to manage the deployments.
It includes binary clients for cf, bosh, credhub ...
For more information go to: https://github.com/springernature/ee-snpaas-cli


# Usage

You can execute them directly. In the current folder you can define a '.envrc' file
with all environment variables you want to be setup in the running container.
If you do not have a '.envrc' file but you have the following environment variables
in your environment, then Bosh-cli and Credhub-cli will automatically log-in: 

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

Then you are ready to manage to manage deployments, with this subcommands and options:

<subcommand> <folder> [options]

Options:
    -m      Specify a manifest file, instead of generating a random one
    -p      Deployments path. Default is $DEPLOYMENTS_PATH
    -h      Shows usage help

Subcommands:
    help            Shows usage help
    interpolate     Create the manifest for an environment
    deploy [-f]     Update or upgrade deployment after applying cloud/runtime configs
    destroy [-f]    Delete deployment (does not delete cloud/runtime configs)
    cloud-config    Apply cloud-config operations files from Director cloud-config
    runtime-config  Apply runtime-config operations files from Director runtime-config
    import-secrets  Set secrets in Credhub from <deployment-folder>/$DEPLOYMENT_CREDS file
    list-secrets    List secrets from Credhub for <deployment-folder>
    export-secrets  Download secrets from Credhub to <deployment-folder>/$DEPLOYMENT_CREDS


# Folder structure:

<deployment-folder>
├── <boshrelease1-git-submodule-folder>
├── <boshrelease2-git-submodule-folder>
├── ...
├── prepare.sh
├── finish.sh
├── operations
│   ├── 00-base-manifest.yml -> ../<boshrelease1-git-submodule-folder>/manifest/base.yml
│   ├── 10-operation.yml -> ../<boshrelease1-git-submodule-folder>/manifest/operations/operation.yml
│   ├── 20-operation2.yml -> ../<boshrelease1-git-submodule-folder>/manifest/operations/operation2.yml
│   ├── 99-springer-nature-operation-custom.yml
├── secrets.yml
├── cloud-config
├── runtime-config
└── variables
    ├── variables-custom1.yml
    ├── variables-custom1.yml
    └── variables-provided.yml -> ../<boshrelease1-git-submodule-folder>/manifest/vars.yml


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


# Usage examples

Given a deployment folder called 'app-logging' with this structure:

app-logging
├── prepare.sh
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


* To deploy or update the deployment called 'app-logging', execute: 'deploy app-logging'.
  If you do not want to answer 'y/n' question when bosh runs, just use '-f' option:
  'deploy app-logging -f'. Execute 'snpaas deploy app-logging' from the parent directory
  containing the 'app-logging' deployment folder, not from within the 'app-logging' 
  deployment folder itself (always execute commands from the directory one level up).
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
by typing then as argument.

  SPIFF:  1.0.8
  CREDHUB:  1.7.7
  GCLOUD_SDK:  220.0.0
  CF_CLI:  6.40.0
  BOSH_CLI:  5.2.1
  CERTSTRAP:  1.1.1
  JQ:  1.5
  BBR:  1.2.2
  SPRUCE:  1.18.0
  TERRAFORM:  0.11.8
  FLY:  3.14.1

```


# Author

Springer Nature Engineering Enablement (EE), Jose Riguera Lopez (jose.riguera@springer.com)


