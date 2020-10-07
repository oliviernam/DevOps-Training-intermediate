# Demoing CloudOne with MOADSD-NG

- [Demoing CloudOne with MOADSD-NG](#demoing-cloudone-with-moadsd-ng)
  - [The Setup](#the-setup)
    - [Example Configuration](#example-configuration)
  - [Configure Jenkins](#configure-jenkins)
    - [Language](#language)
    - [Credentials](#credentials)
    - [GitHub Integration](#github-integration)
    - [Automatic Builds - Let Jenkins configure your Web Hooks](#automatic-builds---let-jenkins-configure-your-web-hooks)
    - [Accessing Blue Ocean](#accessing-blue-ocean)
    - [Integrate Pipelines](#integrate-pipelines)
  - [Demoing](#demoing)

The MOADSD-NG project does provide a simple way to setup a hybrid cloud security demo, playground and learning environment within the clouds or alternatively on a local ESXi (no vCenter required). Core technologies used (besides of Trend Micro solutions) are the cloud native virtualization functionalities, a full-blown Kubernetes cluster with cluster storage and release management tools (Jenkins / GitLab). Ansible, the de facto most used orchestration tool, is used for the whole life-cycle of your MOADSD-NG environment.

In this lab, we will discuss how to setup MOADSD-NG and go over some basics of how to use the environment. We will get in touch with lots of technologies we learned about in the previous parts of the training. That includes:

- JSON / YAML
- API
- Ansible
- Python
- Kubernetes
- Docker

Our goal is to get a Jenkins driven pipeline up and running, including in the deployment of an application on Kubernetes. Effectively, we’re going to put the things together :-)

## The Setup

Follow the guide on the [wiki](https://github.com/mawinkler/moadsd-ng/wiki/MOADSD-NG-SERVER)

### Example Configuration

```yaml
# #####################################################################
# This is a sample configuration of MOADSD-NG. Using it and adding the
# MANDATORY information will create a three node Kubernetes cluster
# with Smart Check, Workload Security, Jenkins, Prometheus, Grafana
# and OPA deployed and pre-configured.
#
# See roles/configurator/defaults/main.yml for all the default values
#
# https://github.com/mawinkler/moadsd-ng/blob/master/roles/configurator/defaults/main.yml
#
# The following configuration does work on AWS and GCP
# #####################################################################

# #####################################################################
# Site Deploy Components
# #####################################################################
site_deploy_deepsecurity: yes
site_deploy_endpoints: yes
site_deploy_kubernetes: yes
site_deploy_smartcheck: yes
site_deploy_jenkins: yes
site_deploy_linkerd: yes
site_deploy_prometheus: yes
site_deploy_grafana: yes
site_deploy_opa: yes

# #####################################################################
# Google Cloud Settings
# #####################################################################

# #####################################################################
# AWS Cloud Settings - AMIs here for eu-west-1
# #####################################################################
# Ubuntu Server 18.04 LTS (HVM), SSD Volume Type
ami_ubuntu: ami-035966e8adab4aaad
# Red Hat Enterprise Linux 8 (HVM), SSD Volume Type
ami_redhat: ami-04facb3ed127a2eb6
# Microsoft Windows Server 2012 R2 Base
ami_windows: ami-0d7624414846e2cf6

# #####################################################################
# Linux Jumphost Settings
# #####################################################################
jumphost_tld: sslip.io

# #####################################################################
# Kubernetes Settings
# #####################################################################
kubernetes_container_runtime: docker
kubernetes_worker_count: 3
cluster_networking: flannel_flannel

# #####################################################################
# Site Secrets
# #####################################################################
# Deep Security
deepsecurity_license: AP-XXXX-XXXXX-XXXXX-XXXXX-XXXXX-XXXXX
deepsecurity_administrator_password: TrendM1cr0
deepsecurity_database_password: TrendM1cr0

# Deep Security as a Service
deepsecurity_tenant_id: E0B772FA-XXXX-XXXX-XXXX-XXXXXXXXXXXX
deepsecurity_token: A6BE4827-XXXX-XXXX-XXXX-XXXXXXXXXXXX

# Deep Security Smart Check
smartcheck_license: AP-XXXX-XXXXX-XXXXX-XXXXX-XXXXX-XXXXX
smartcheck_password: TrendM1cr0
smartcheck_registry_password: TrendM1cr0
smartcheck_database_password: TrendM1cr0

# Cloud One Application Security
application_security_key: 040beea0-xxxx-xxxx-xxxx-xxxxxxxxxxxx
application_security_secret: 5d8b9064-xxxx-xxxx-xxxx-xxxxxxxxxxxx

# Jenkins
jenkins_password: TrendM1cr0
jenkins_token: 11ca9eee4294f022e907686a8c53a42887
jenkins_github_access_token: ad9cxxxx4b5dexxxx47addaxxxx7999xxxxde430

# Cluster Registry
cluster_registry_password: TrendM1cr0

# Grafana
grafana_password: TrendM1cr0

# Ansible
admin_email: mawinkler@spammail.com

# Github
github_username: mawinkler
github_password: xxxxxxxxxxxxxxxx

# Trusted Certificates
trusted_certificates: False
```

## Configure Jenkins

*Initial Warning*

With the initial login to Jenkins you likely get a proxy configuration error shown when accessing Manage Jenkins. Dismiss it.

### Language

To ease the communication within the training you should set the language of Jenkins to English (if it is not already)
To set the locale go to

`Manage Jenkins → Configure System → Locale`

```text
Default Language: en
Ignore browser preference and force language to all users: check
```

[Save] in the bottom

### Credentials

As soon as Jenkins is up and running, you can populate the credentials for Smart Check, Docker Hub, Cluster Registry and Kubernetes by using Ansible. To enable Ansible using the API you first need to create an API-token for the admin user:

Top right corner:

`admin → Configure → Add new Token`

```text
Name: admin
```

Copy the token to your jenkins_token: within configuration.yml

```shell
./menu.sh
```

Choose option 2-aws, then 12-configuration

Now, you can create the credentials either by running

```shell
./menu.sh
```

Choose option 2-aws and 4-jenkins_create_credentials

### GitHub Integration

First, login to your GitHub account and afterwards go to my demo project troopers by clicking on the link below and fork it to your GitHub account.

<https://github.com/mawinkler/troopers.git>

Now you have a new repo in your account which you can freely modify.

To allow Jenkins work with your GitHub we need to create a personal access token for Jenkins.

Add a personal access token

`GitHub → Your profile → Settings → Developer settings → Personal access tokens`

Key | Value | Subvalue
-- | -- | --
Note | jenkins | 
Select scopes | repo - check | repo:status - check
| | | repo_deployment - check
| | | public_repo - check
| | | repo:invite - check
| | admin:repo_hook - uncheck | write:repo_hook - check
| | | read:repo_hook - check
| | user - uncheck | read:user - check
| | | user:email - check
| | | user:follow - uncheck

File the token into your configuration.yml as `jenkins_github_access_token: <YOUR TOKEN>` by running the `menu.sh`and choosing `aws` and `configure`.

### Automatic Builds - Let Jenkins configure your Web Hooks

Jenkins is able to manage GitHub WebHooks. To enable this you need to define the Personal Access Token from GitHub as a secret within Jenkins. This is done automatically by MOADSD-NG.

Additionally, as of now, go to `Manage Jenkins -> Configure System` and down to `GitHub Servers`. Hit `Add GitHub Server`.

```text
Name - doesn't matter
API URL - https://api.github.com
Credentials - choose github-access-token
Manage Hooks - checked
```

Hit `Test Connection` to make sure everything is kosher.

### Accessing Blue Ocean

Jenkins itself does not look extremely beautiful, or? To enhance it a little we’re using Blue Ocean. Since our Jenkins environment has Blue Ocean installed, after logging in to the Jenkins classic UI, you can access the Blue Ocean UI by clicking Open Blue Ocean on the left.
Alternatively, you can access Blue Ocean directly by appending /blue to the end of your Jenkins server’s URL - e.g. <https://jenkins-server-url/blue>.

If your Jenkins instance:

- already has existing Pipeline projects or other items present, then the Blue Ocean Dashboard is displayed.
- is new or has no Pipeline projects or other items configured, then Blue Ocean displays a Welcome to Jenkins box with a Create a new Pipeline button you can use to begin creating a new Pipeline project.

So now, login to Jenkins, go to Blue Ocean and create a pipeline for our troopers. You will need the personal access token created within your GitHub account for that.

If everything works out, the pipeline should start to build after a few moments.

### Integrate Pipelines

Next to the Troopers app there are some other apps you can seamlessly integrate with MOADSD-NG on my GitHub:

- [MoneyX](https://github.com/mawinkler/c1-app-sec-moneyx)
- [Uploader](https://github.com/mawinkler/c1-app-sec-uploader)
- [Django](https://github.com/mawinkler/c1-app-sec-djangonv)
- [Tomcat](https://github.com/mawinkler/c1-app-sec-tomcat)

They're all integrated with Smart Check and Application Security.

Feel free to build new things (and share them with me :-) ).

## Demoing

Lot's of possibilities here:

- Smart Check pipeline integration including the reporting tool
- Smart Check Findings, API, etc.
- Application Security with different flavours with pipeline integration
- Exploring the cluster and see the deployments
- Troubleshooting with Smart Check
- ...
