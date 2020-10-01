FROM ubuntu:18.04

ARG VERSION=0.1
ARG user=mcs
ARG group=mcs
ARG uid
ARG gid

# root context
RUN ln -snf /usr/share/zoneinfo/${TZ} /etc/localtime && echo ${TZ} > /etc/timezone

RUN addgroup -gid ${gid} ${group} || true
RUN useradd -m -s /bin/bash -d /home/${user} -u ${uid} -g ${gid} ${user}

LABEL Description="This is the Multi Cloud Shell"

ARG WORKDIR=/home/${user}

COPY add-apt-repository /usr/bin

RUN apt update && \
    apt install -y sudo vim nano jq figlet wget curl ssh python3 software-properties-common git locales-all libffi6 libffi-dev libssl-dev && \
    add-apt-repository universe && \
    apt update && \
    apt install -y python3-pip

RUN echo "${user} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/custom-users && \
    echo "StrictHostKeyChecking no" >> /etc/ssh/ssh_config && \
    figlet "Multi Cloud Shell" > /etc/motd

# user context
USER ${user}
WORKDIR /home/${user}

COPY saveenv-az.sh .
COPY saveenv-aws.sh .
COPY saveenv-gcp.sh .

# Google
RUN pip3 install requests google-auth --user && \
    export CLOUD_SDK_REPO="cloud-sdk-$(lsb_release -c -s)" && \
    echo "deb http://packages.cloud.google.com/apt $CLOUD_SDK_REPO main" | sudo tee -a /etc/apt/sources.list.d/google-cloud-sdk.list && \
    curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add - && \
    sudo apt-get update && \
    sudo apt-get install -y google-cloud-sdk

# AWS
RUN pip3 install awscli boto boto3 --user && \
    echo 'export PATH=~/.local/bin:$PATH' >> ~/.bashrc

# Azure
RUN sudo apt-get install -y ca-certificates curl apt-transport-https lsb-release gnupg && \
    curl -sL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor | \
    sudo tee /etc/apt/trusted.gpg.d/microsoft.gpg > /dev/null && \
    export AZ_REPO=$(lsb_release -cs) && \
    echo "deb [arch=amd64] https://packages.microsoft.com/repos/azure-cli/ $AZ_REPO main" | \
    sudo tee /etc/apt/sources.list.d/azure-cli.list && \
    sudo apt-get update && \
    sudo apt-get install -y azure-cli

# Kubectl
RUN sudo apt install -y kubectl

# Helm
RUN curl https://baltocdn.com/helm/signing.asc | sudo apt-key add - && \
    sudo apt-get install apt-transport-https --yes && \
    echo "deb https://baltocdn.com/helm/stable/debian/ all main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list && \
    sudo apt-get update && \
    sudo apt-get install helm

RUN tar cpzf /tmp/home.tgz /home/${user} && \
    echo "cat /etc/motd" >> .bashrc

WORKDIR /home/${user}

ENTRYPOINT ["/bin/bash"]
