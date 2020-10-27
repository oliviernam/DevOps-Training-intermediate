# Multi Cloud Shell

**BETA VERSION**

This repository provides a container image providing a multi cloud shell for AWS, Google and Azure. The core components of that image are:

* `gcloud` cli for Google
* `aws` cli for AWS
* `az` cli for Azure
* plus all additional tools and command line interfaces to manage kubernetes clusters

Persistence is provided by a mapped working directory on your docker host. That means, you can easily destroy and rebuild the image whenever needed. If you want to move your setup, simply tar / zip your local repo directory including the workdir.

## Prerequisites

Docker & Docker-Compose

Tested with

* Linux,
* Mac OS X with *Docker for Desktop* and
* AWS Cloud9

### Linux

Requirements for Docker & Docker-Compose

```sh
curl -fsSL get.docker.com -o get-docker.sh && sudo sh get-docker.sh
sudo usermod -aG docker `whoami` && sudo service docker start
sudo curl -L https://github.com/docker/compose/releases/download/1.24.0/docker-compose-`uname -s`-`uname -m` -o /usr/local/bin/docker-compose && sudo chmod +x /usr/local/bin/docker-compose
```

### Mac OS X

Requirements Docker for Desktop

<https://download.docker.com/mac/stable/Docker.dmg>

### Cloud9

Cloud9 Configuration:

* Name: \<whatever-you-like\>
* Instance type: >= t3.medium
* Platform: Ubuntu Server 18.04-LTS

From within the Cloud9 shell to a

```sh
sudo apt install -y docker-compose
```

Now clone the devops-training

```sh
git clone https://github.com/mawinkler/devops-training.git
cd devops-training
```

#### Default VPC

Cloud9 requires a VPC with a public subnet available. If you don't have that within the desired region you need to create it before creating the Cloud9 instance.

* Create a VPC
  * Name tag: cloud9-vpc
  * IPv4 CIDR block: 10.0.0.0/16
  * IPv6 CIDR block: No
  * Tenancy: Default
* Create a Subnet
  * Name tag: cloud9-subnet
  * VPC: cloud9-vpc
  * Availability Zone: No preference
  * IPv4 CIDR block: 10.0.1.0/24
* Create an Internet Gateway
  * Name tag: cloud9-igw
* Attach Internet Gateway to VPC
  * VPC: cloud9-vpc
* Modify Route Table --> Routes --> Edit routes --> Add route
  * Destination 0.0.0.0/0
  * Target: cloud9-igw

#### Boto

Comment of 10/10/2020:

There was a change in boto which removed the dependency of docutils. That caused the AWS client available within the Cloud9 instance to not work anymore. Reference <https://github.com/boto/botocore/commit/dd24dd1b2ee8654ae0cf6aebce4a2f50ea7d75f5#diff-cebf7e5767458186d20a75e5390de4de> and <https://github.com/boto/boto3/issues/2596>.

Workaraound for this is to upgrade awscli to >=1.18.140. To do this, execute the following:

```sh
pip3 install awscli boto boto3 --user && \
    echo 'export PATH=~/.local/bin:$PATH' >> ~/.bashrc
```

Alternatively, you can directly upgrade to the latest version of awscli v2:

```sh
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "~/awscliv2.zip"
unzip ~/awscliv2.zip
sudo ~/aws/install
aws --version
```

### Windows

NOT SUPPORTED, FULLSTOP.

## How to use

**Note:** If you are using a Mac and iCloud Drive, you should move the shell folder to a location *not* within the scope if iCloud Drive. This is not mandatory but recommended.

Build and run it:

```shell
cd shell
```

You likely need to increase the disk size of the Cloud9 instance depending on the type you chose above. Execute:

```sh
./resize.sh
```

Now build and start

```sh
./build.sh
./start.sh
```
