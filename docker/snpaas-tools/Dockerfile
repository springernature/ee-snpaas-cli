FROM alpine:3.8
# docker build . -t snpaas-tools
# docker run -it -v $(pwd)/data snpaas-tools help

# Version of this image (arg comes from git commit)
ARG VERSION=1

# Versions, please prefix them with SNPAAS_ and suffix with _VERSION
# (see run.sh script)
ARG SNPAAS_BOSH_CLI_VERSION=5.2.1
ARG SNPAAS_TERRAFORM_VERSION=0.11.8
ARG SNPAAS_CF_CLI_VERSION=6.40.0
ARG SNPAAS_SPRUCE_VERSION=1.18.0
ARG SNPAAS_JQ_VERSION=1.5
ARG SNPAAS_CREDHUB_VERSION=1.7.7
ARG SNPAAS_FLY_VERSION=3.14.1
ARG SNPAAS_BBR_VERSION=1.2.2
ARG SNPAAS_CERTSTRAP_VERSION=1.1.1
ARG SNPAAS_SPIFF_VERSION=1.0.8
ARG SNPAAS_GCLOUD_SDK_VERSION=220.0.0

ARG UID=1000
ARG GUID=1000
ARG TIMEZONE=Europe/Amsterdam
ARG DATADIR=/data

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

RUN set -xe                                                                 && \
    apk -U upgrade                                                          && \
    # Installing Alpine packages. Some of these are required because of dependencies with the binaries
    apk add --no-cache \
        tzdata \
        bash \
        curl \
        zip \
        unzip \
        xmlsec \
        yaml \
        libc6-compat \
        tzdata \
        libxml2 \
        libxslt \
        readline \
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
        py-crcmod \
        git \
        wget \
        gnupg \
                                                                            && \
    # Timezone
    cp "/usr/share/zoneinfo/${TIMEZONE}" /etc/localtime                     && \
    echo "${TIMEZONE}" > /etc/timezone                                      && \
    ln -s /lib /lib64                                                       && \
    # clean up
    rm -rf /tmp/* /var/tmp/* /var/cache/apk/* /var/cache/distfiles/* ~/.cache

RUN set -xe                                                                 && \
    wget "https://cli.run.pivotal.io/stable?release=linux64-binary&version=${SNPAAS_CF_CLI_VERSION}" -nv -O - | tar -zx -C /usr/local/bin                                                                                      && \
    wget "https://github.com/geofffranks/spruce/releases/download/v${SNPAAS_SPRUCE_VERSION}/spruce-linux-amd64" -nv -O /usr/local/bin/spruce                                                                                   && \
    wget "https://github.com/stedolan/jq/releases/download/jq-${SNPAAS_JQ_VERSION}/jq-linux64" -nv -O /usr/local/bin/jq                                                                                                        && \
    wget "https://s3.amazonaws.com/bosh-cli-artifacts/bosh-cli-${SNPAAS_BOSH_CLI_VERSION}-linux-amd64" -nv -O /usr/local/bin/bosh                                                                                              && \
    wget "https://github.com/cloudfoundry-incubator/credhub-cli/releases/download/${SNPAAS_CREDHUB_VERSION}/credhub-linux-${SNPAAS_CREDHUB_VERSION}.tgz" -nv -O - | tar -xz -C /usr/local/bin                                         && \
    wget "https://github.com/concourse/concourse/releases/download/v${SNPAAS_FLY_VERSION}/fly_linux_amd64" -nv -O /usr/local/bin/fly                                                                                           && \
    wget "https://github.com/square/certstrap/releases/download/v${SNPAAS_CERTSTRAP_VERSION}/certstrap-v${SNPAAS_CERTSTRAP_VERSION}-linux-amd64" -nv -O /usr/local/bin/certstrap                                                      && \
    wget "https://github.com/cloudfoundry-incubator/bosh-backup-and-restore/releases/download/v${SNPAAS_BBR_VERSION}/bbr-${SNPAAS_BBR_VERSION}.tar" -nv -O - | tar -x -C /tmp releases/bbr && mv /tmp/releases/bbr /usr/local/bin/bbr && \
    wget "https://releases.hashicorp.com/terraform/${SNPAAS_TERRAFORM_VERSION}/terraform_${SNPAAS_TERRAFORM_VERSION}_linux_amd64.zip" -nv -O /tmp/terraform.zip && unzip -q /tmp/terraform.zip -d /usr/local/bin                      && \
    wget "https://github.com/cloudfoundry-incubator/spiff/releases/download/v${SNPAAS_SPIFF_VERSION}/spiff_linux_amd64.zip" -nv -O /tmp/spiff.zip && unzip -q /tmp/spiff.zip -d /usr/local/bin


ENV PATH $PATH:/usr/local/bin:/opt/google-cloud-sdk/bin

RUN set -xe                                                                 && \
    mkdir -p /opt                                                           && \
    wget https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-sdk-${SNPAAS_GCLOUD_SDK_VERSION}-linux-x86_64.tar.gz -nv -O - | tar -zx -C /opt                                                              &&\
    gcloud config set core/disable_usage_reporting true                     && \
    gcloud config set component_manager/disable_update_check true           && \
    gcloud config set metrics/environment github_docker_image

COPY Readme.md /
COPY resources/*.sh /usr/local/bin/
RUN set -xe                                                                 && \
    chmod a+x /usr/local/bin/*                                              && \
    ln -s /usr/local/bin/run.sh /run.sh                                     && \
    rm -rf /tmp/* /var/tmp/*                                                && \
    mkdir -p ${DATADIR}

VOLUME "${DATADIR}"
WORKDIR "${DATADIR}"
ENTRYPOINT ["/bin/bash", "/run.sh"]

# Define default command
CMD ["help"]

