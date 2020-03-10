FROM debian:10.2-slim

# docker build . -t snpaas-tools
# docker run -it -v $(pwd)/data snpaas-tools help
# Do not worry: ARB, LABEL and ENV do not produce new layers!


# Version of this image
# ARG VERSION=1.2
ARG VERSION=2.6

# Versions, please prefix them with SNPAAS_ and suffix with _VERSION
# (see run.sh script)
ARG SNPAAS_BOSH_CLI_VERSION=5.2.1
ARG SNPAAS_TERRAFORM_VERSION=0.11.8
ARG SNPAAS_CF_CLI_VERSION=6.40.0
ARG SNPAAS_SPRUCE_VERSION=1.18.0
ARG SNPAAS_JQ_VERSION=1.5
ARG SNPAAS_CREDHUB_VERSION=2.7.0
ARG SNPAAS_FLY_VERSION=3.14.1
ARG SNPAAS_BBR_VERSION=1.2.2
ARG SNPAAS_CERTSTRAP_VERSION=1.1.1
ARG SNPAAS_SPIFF_VERSION=1.0.8
ARG SNPAAS_GCLOUD_SDK_VERSION=267.0.0
ARG SNPAAS_VARSTOCREDHUB_VERSION=0.1.0

ARG USER=snpaas
ARG HOME=/home/snpaas
ARG UID=1000
ARG GUID=1000
ARG TIMEZONE=Europe/Amsterdam
ARG DATADIR=/data
ARG OPTDIR=/opt

LABEL org.label-schema.docker.schema-version="1.0"
LABEL org.label-schema.vendor="Springer Nature EE"
LABEL org.label-schema.description="SNPaaS tools image based on alpine"
LABEL org.label-schema.name="snpaas-tools"
LABEL org.label-schema.version="${VERSION}"
LABEL org.label-schema.usage="./README.md"
LABEL org.label-schema.url="https://hub.docker.com/p/platform-engineering/snpaas-tools"
LABEL org.label-schema.vcs-url="https://github.com/springernature/ee-snpaas-cli"
LABEL maintainer="EE <engineering-enablement@springernature.com>"
LABEL architecture="amd64"

ENV LANG=en_US.utf8
ENV LC_ALL=C.UTF-8
ENV HOME="${HOME}"
ENV SNPAAS_VERSION="${VERSION}"
ENV SNPAAS_USER="${USER}"
ENV SNPAAS_HOME="${HOME}"
ENV SNPAAS_DATADIR="${DATADIR}"
ENV SNPAAS_CF6_PLUGINS="${OPTDIR}"

ENV SNPAAS_GCLOUD_SDK_VERSION=$SNPAAS_GCLOUD_SDK_VERSION
ENV SNPAAS_BOSH_CLI_VERSION=$SNPAAS_BOSH_CLI_VERSION
ENV SNPAAS_TERRAFORM_VERSION=$SNPAAS_TERRAFORM_VERSION
ENV SNPAAS_CF_CLI_VERSION=$SNPAAS_CF_CLI_VERSION
ENV SNPAAS_SPRUCE_VERSION=$SNPAAS_SPRUCE_VERSION
ENV SNPAAS_JQ_VERSION=$SNPAAS_JQ_VERSION
ENV SNPAAS_CREDHUB_VERSION=$SNPAAS_CREDHUB_VERSION
ENV SNPAAS_FLY_VERSION=$SNPAAS_FLY_VERSION
ENV SNPAAS_BBR_VERSION=$SNPAAS_BBR_VERSION
ENV SNPAAS_CERTSTRAP_VERSION=$SNPAAS_CERTSTRAP_VERSION
ENV SNPAAS_SPIFF_VERSION=$SNPAAS_SPIFF_VERSION
ENV SNPAAS_VARSTOCREDHUB_VERSION=$SNPAAS_VARSTOCREDHUB_VERSION

RUN set -xe                                                                 && \
    groupadd --gid "${GUID}" "${USER}"                                      && \
    useradd --no-log-init --create-home  --home-dir "${HOME}" \
            --gid "${GUID}" \
            --shell /bin/bash \
            --uid "${UID}" "${USER}"                                        && \
    apt-get update                                                          && \
    # Installing packages. Some of these are required because of 
    # dependencies with the binaries
    apt-get install --no-install-recommends -qq -y \
        tzdata \
        bash \
        curl \
        zip \
        unzip \
        xmlsec1 \
        libxml2 \
        libxslt1.1 \
        libreadline7 \
        openssl \
        ca-certificates \
        openssh-client \
        rsync \
        iperf3 \
        net-tools \
        nmap \
        mariadb-client \
        fping \
        python3 \
        python3-crcmod \
        python3-yaml \
        yamllint \
        git \
        dnsutils \
        wget \
        gnupg \
        pwgen \
                                                                            && \
    # Timezone
    cp "/usr/share/zoneinfo/${TIMEZONE}" /etc/localtime                     && \
    echo "${TIMEZONE}" > /etc/timezone                                      && \
    ln -s /lib /lib64                                                       && \
    # clean up
    rm -rf /tmp/* /var/tmp/* /var/lib/apt/lists/* /var/cache/distfiles/* ~/.cache

RUN set -xe                                                                 && \
    mkdir -p /opt                                                           && \
    wget "https://cli.run.pivotal.io/stable?release=linux64-binary&version=${SNPAAS_CF_CLI_VERSION}" -nv -O - | tar -zx -C /usr/local/bin                                                                                      && \
    wget "https://github.com/geofffranks/spruce/releases/download/v${SNPAAS_SPRUCE_VERSION}/spruce-linux-amd64" -nv -O /usr/local/bin/spruce                                                                                   && \
    wget "https://github.com/stedolan/jq/releases/download/jq-${SNPAAS_JQ_VERSION}/jq-linux64" -nv -O /usr/local/bin/jq                                                                                                        && \
    wget "https://s3.amazonaws.com/bosh-cli-artifacts/bosh-cli-${SNPAAS_BOSH_CLI_VERSION}-linux-amd64" -nv -O /usr/local/bin/bosh                                                                                              && \
    wget "https://github.com/cloudfoundry-incubator/credhub-cli/releases/download/${SNPAAS_CREDHUB_VERSION}/credhub-linux-${SNPAAS_CREDHUB_VERSION}.tgz" -nv -O - | tar -xz -C /usr/local/bin                                         && \
    wget "https://github.com/concourse/concourse/releases/download/v${SNPAAS_FLY_VERSION}/fly_linux_amd64" -nv -O /usr/local/bin/fly                                                                                           && \
    wget "https://github.com/square/certstrap/releases/download/v${SNPAAS_CERTSTRAP_VERSION}/certstrap-v${SNPAAS_CERTSTRAP_VERSION}-linux-amd64" -nv -O /usr/local/bin/certstrap                                                      && \
    wget "https://github.com/cloudfoundry-incubator/bosh-backup-and-restore/releases/download/v${SNPAAS_BBR_VERSION}/bbr-${SNPAAS_BBR_VERSION}.tar" -nv -O - | tar -x -C /tmp releases/bbr && mv /tmp/releases/bbr /usr/local/bin/bbr && \
    wget "https://releases.hashicorp.com/terraform/${SNPAAS_TERRAFORM_VERSION}/terraform_${SNPAAS_TERRAFORM_VERSION}_linux_amd64.zip" -nv -O /tmp/terraform.zip && unzip -q /tmp/terraform.zip -d /usr/local/bin                      && \
    wget "https://github.com/cloudfoundry-incubator/spiff/releases/download/v${SNPAAS_SPIFF_VERSION}/spiff_linux_amd64.zip" -nv -O /tmp/spiff.zip && unzip -q /tmp/spiff.zip -d /usr/local/bin                                  && \
    wget "https://github.com/SpringerPE/vars-to-credhub/releases/download/v${SNPAAS_VARSTOCREDHUB_VERSION}/vars-to-credhub-linux-amd64" -nv -O /usr/local/bin/vars-to-credhub                                                      && \
    wget "https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-sdk-${SNPAAS_GCLOUD_SDK_VERSION}-linux-x86_64.tar.gz" -nv -O - | tar -zx -C /opt

ENV PATH $PATH:/usr/local/bin:/opt/google-cloud-sdk/bin
ENV CF_PLUGIN_HOME $SNPAAS_CF6_PLUGINS/cfv6

RUN set -xe                                                                 && \
    chmod a+x /usr/local/bin/*                                              && \
    ln -s /usr/local/bin/run.sh /run.sh                                     && \
    rm -rf /tmp/* /var/tmp/*                                                && \
    mkdir -p ${HOME}/.ssh                                                   && \
    chmod 700 ${HOME}/.ssh                                                  && \
    # Setting up gcloud defaults
    gcloud config set core/disable_usage_reporting true                     && \
    gcloud config set component_manager/disable_update_check true           && \
    gcloud config set metrics/environment github_docker_image               && \
    # Installing cf plugins
    cf install-plugin -f -r CF-Community "top"                              && \
    cf install-plugin -f -r CF-Community "cf-rolling-restart"               && \
    cf install-plugin -f -r CF-Community "log-stream"                       && \
    cf install-plugin -f -r CF-Community "report-memory-usage"              && \
    cf install-plugin -f -r CF-Community "report-disk-usage"                && \
    cf install-plugin -f -r CF-Community "app-autoscaler-plugin"            && \
    cf install-plugin -f -r CF-Community "log-cache"                        && \
    cf install-plugin -f -r CF-Community "drains"                           && \
    cf install-plugin -f -r CF-Community "report-users"                     && \
    cf install-plugin -f -r CF-Community "mysql-plugin"                     && \
    cf install-plugin -f -r CF-Community "deploy"                           && \
    cf install-plugin -f -r CF-Community "route-lookup"                     && \
    cf install-plugin -f -r CF-Community "Usage Report"                     && \
    cf install-plugin -f -r CF-Community "cf-download"                      && \
    cf install-plugin -f -r CF-Community "docker-usage"                     && \
    cf install-plugin -f -r CF-Community "Buildpack Management"             && \
    cf install-plugin -f -r CF-Community "Statistics"                       && \
    chown -R ${USER}:${USER} ${HOME} $SNPAAS_CF6_PLUGINS

COPY Readme.md /
COPY resources/*.sh /usr/local/bin/
VOLUME "${DATADIR}" "${HOME}"

# Main command
ENTRYPOINT ["/bin/bash", "/run.sh"]
# Define default command
CMD ["help"]

