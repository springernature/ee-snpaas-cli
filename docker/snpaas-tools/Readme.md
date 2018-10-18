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
├── <boshrelease-git-submodule-folder>
├── base.yml -> <boshrelease-git-submodule-folder>/manifest/logstash.yml
├── operations
│   ├── 10-operation.yml -> ../<boshrelease-git-submodule-folder>/manifest/operations/operation.yml
│   ├── 20-operation2.yml -> ../<boshrelease-git-submodule-folder>/manifest/operations/operation2.yml
│   ├── 99-springer-nature-operation-custom.yml
├── secrets.yml
├── cloud-config
├── runtime-config
└── variables
    ├── variables-custom1.yml
    ├── variables-custom1.yml
    └── variables-provided.yml -> ../<boshrelease-git-submodule-folder>/manifest/vars.yml


Credhub secrets have to be type 'value' and they will be imported/exported inside a
'secrets.yml' file, which, in case it exits, the script will read.


# Usage examples

Given a deployment folder called 'app-logging' with this structure:

app-logging
├── logstash.yml -> cf-logging-boshrelease/manifest/logstash.yml
├── operations
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

