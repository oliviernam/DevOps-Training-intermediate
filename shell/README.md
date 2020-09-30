# Multi Cloud Shell
This repository provides a container image providing a multi cloud shell for AWS, Google and Azure. The core components of that image are:

* Ansible running with Python3
* `gcloud` cli for Google
* `aws` cli for AWS
* `az` cli for Azure
* plus all additional cli to manage kubernetes clusters

Persistence is provided by a mapped working directory on your docker host. That means, you can easily destroy and rebuild the image whenever needed. If you want to move your setup, simply tar / zip your local repo directory including the workdir.

## Prerequisites
Docker & Docker-Compose

Tested with
* Linux,
* Mac OS X with *Docker for Desktop* and
* AWS Cloud9
