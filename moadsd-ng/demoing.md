# Demoing CloudOne with MOADSD-NG

- [Demoing CloudOne with MOADSD-NG](#demoing-cloudone-with-moadsd-ng)
  - [Requirements](#requirements)
  - [The Setup](#the-setup)
    - [Example Configuration](#example-configuration)
  - [Understand MOADSD-NG](#understand-moadsd-ng)
    - [Entrypoints](#entrypoints)
    - [Call and Include Flow](#call-and-include-flow)
    - [Directory Structure](#directory-structure)
    - [Firewall & IP Methodology](#firewall--ip-methodology)
    - [Usernames and Credentials](#usernames-and-credentials)
  - [Explore MOADSD-NG](#explore-moadsd-ng)
    - [Directory `ssh_aws`](#directory-ssh_aws)
    - [Connect to the master](#connect-to-the-master)
  - [Lab](#lab)
    - [Configure Jenkins](#configure-jenkins)
      - [Language](#language)
      - [Jenkins API Token](#jenkins-api-token)
      - [Integrate Jenkins with GitHub](#integrate-jenkins-with-github)
      - [Update Credentials in Jenkins](#update-credentials-in-jenkins)
      - [Automatic Builds - Let Jenkins configure your Web Hooks](#automatic-builds---let-jenkins-configure-your-web-hooks)
      - [Accessing Blue Ocean](#accessing-blue-ocean)
      - [Integrate Pipelines](#integrate-pipelines)
    - [Get Troopers up and running](#get-troopers-up-and-running)
    - [Identify unwanted PHP-code](#identify-unwanted-php-code)
    - [Demoing](#demoing)

The MOADSD-NG project does provide a simple way to setup a hybrid cloud security demo, playground and learning environment within the clouds or alternatively on a local ESXi (no vCenter required). Core technologies used (besides of Trend Micro solutions) are the cloud native virtualization functionalities, a full-blown Kubernetes cluster with cluster storage and release management tools (Jenkins / GitLab). Ansible, the de facto most used orchestration tool, is used for the whole life-cycle of your MOADSD-NG environment.

In this lab, we will discuss how to setup MOADSD-NG and go over some basics of how to use the environment. Our goal is to get a Jenkins driven pipeline up and running, including the deployment of an application on Kubernetes.

## Requirements

To follow this lab, you will need (or already got):

- An own Amazon AWS account with admin privileges. If you are sharing your AWS account with other participants of the training please raise your hand!!!
- An own GitHub Account
- A license key for Deep Security Smart Check

Later on, you can easily setup MOADSD-NG within Google GCP as well, but within this training we’re focusing on AWS.

## The Setup

Follow the guide on the [wiki](https://github.com/mawinkler/moadsd-ng/wiki/MOADSD-NG-SERVER)

### Example Configuration

Here's the minimal lab configuration. Later on, feel free to modify it as you like, include more modules or functionality. For the lab, we only need a Kubernetes cluster with Smart Check and Jenkins deployed. Grafana is not required for the lab, but if time is left I'm going to demo it a little.

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
site_deploy_kubernetes: yes
site_deploy_smartcheck: yes
site_deploy_jenkins: yes
site_deploy_prometheus: yes
site_deploy_grafana: yes

# #####################################################################
# Google Cloud Settings
# #####################################################################

# #####################################################################
# AWS Cloud Settings
# #####################################################################
# Uncomment the following if you're using EU-WEST-1
#ami_ubuntu: ami-035966e8adab4aaad

# #####################################################################
# Site Secrets
# #####################################################################
# Deep Security Smart Check
smartcheck_license: AP-XXXX-XXXXX-XXXXX-XXXXX-XXXXX-XXXXX
smartcheck_password: TrendM1cr0
smartcheck_registry_password: TrendM1cr0

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
```

## Understand MOADSD-NG

### Entrypoints

MOADDS-NG provides three main entry-point Ansible playbooks:

- `site.yml` - creates the network, firewalls and instances in the clouds (plus some additional required things). If site.yml is run for ESXi, only ansible access to the already installed virtual machines is taken out.
- `deploy.yml` - deploys the software components chosen in the by site.yml created cloud environment
- `terminate.yml` and `terminate_site.yml` - terminates MOADSD-NG created by site.yml

To control MOADSD-NG, please use the `menu.sh` script.

### Call and Include Flow

Taking the site.yml as an example, the playbooks have an include-flow depending on the environmental settings. Let’s assume you want to setup a plain Deep Security environment on GCP, the following flow would be taken out:

```sh
<-- play.yml		play.yml is included in the upper playbook
--> role/name.yml 	current play calls a role
==> module		    module call
```

```sh
site.yml
  <-- site_vars.yml
    <-- vars/site_secrets.yml
    <-- vars/environment_gcp_secrets.yml
    <-- vars/environment_gcp_vars.yml
  <-- start_gcp.yml
    --> role/environment-gcp operation=create_network
      ==> gcp_compute_network
    --> role/environment-gcp operation=create_linux_instance (PostgreSQL)
      ==> gcp_compute_firewall
      ==> gcp_compute_disk
      ==> gcp_compute_address
      ==> gcp_compute_instance
    --> role/environment-gcp operation=create_linux_instance (Deep Security)
      …

deploy.yml
  hosts: tag_role_dsm_db
    <-- site_vars.yml
      <-- vars/site_secrets.yml
      <-- vars/environment_gcp_secrets.yml
      <-- vars/environment_gcp_vars.yml
    --> role/postgresql operation=create_instance
      ==> apt
      …
    --> role/postgresql operation=create_database
  hosts: tag_role_dsm
    <-- site_vars.yml
      …
    --> role/deepsecurity operation=create_instance
```

### Directory Structure

The MOADDS-NG directory structure is shown below (simplified), which follows the Ansible best practices:

```sh
├── configuration.yml
├── deploy.yml
├── files/
├── group_vars/
├── hosts
├── host_vars/
├── library/
├── menu.sh
├── README.md
├── roles/
│   ├── <role>/
│   │   ├── defaults/
│   │   │   └── <defaults>
│   │   ├── handlers/
│   │   │   └── <handlers>
│   │   ├── library/
│   │   │   └── <role modules>
│   │   └── tasks/
│   │   │   └── <role tasks>
│   │   └── templates/
│   │       └── <role tasks>
├── site_XXX/
├── site_vars.yml
├── site.yml
├── start_XXX.yml
├── stop_XXX.yml
├── terminate.yml
└── vars/
    ├── <environment_XXX_secrets.yml>
    ├── <environment_XXX_vars.yml>
    └── site_secrets.yml
```

*Note: XXX stands for aws, esx, gcp, (azure)*

*Note: The directory site_XXX/ will get created and populated with URLs and credentials during the deploy phase providing the necessary information on how to access and authenticate to a service.*

*Note: It is possible to have multiple environments at the same time, whereby only on per cloud / esx is allowed.*

### Firewall & IP Methodology

The firewall methodology is currently kept simple:

- There is no distinction in between TCP and UDP, both protocols are opened when required
- All ports are closed by default
- The Jumphost listens on ssh, http and https
- For the rest, access from 0.0.0.0/0 is restricted to service ports like 4119 to the specific instance if specified
- Access from the internal network is restricted unless explicitly allowed (e.g. port 5432 on the PostgreSQL)
- The following hosts will get a public IP assigned when running in the cloud
  - Jumphost
  - Deep Security Manager
  - Windows Endpoints
  - (Openshift)
- The following hosts will only get a private IP assigned when running in the cloud
  - Kubernetes Master
  - Kubernetes Workers
  - Linux Endpoints
  - PostgreSQL
- All Linux hosts are accessible by ssh with key based authentication (Ansible key) either directly or by proxying through the Jumphost.
- All Windows hosts are accessible by rdp.

*Note: Openshift will be moved to the private subnet.*

### Usernames and Credentials

- All instances do get an ansible user created which is used by Ansible
- All Ubuntu based instances do use the user ubuntu for the workload
- Remote ssh authentication to the private instances is to done (if required) through the jumphost. 
(`ssh -o ProxyCommand="ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -W %h:%p <jumphost public ip>" <target ip>`)

## Explore MOADSD-NG

If everything went well during site creation and the deployment you should now have a fully-fledged bare metal Kubernetes cluster :-).
Let’s explore it a little, but of course you are free to replay labs from the Kubernetes lab as well.

### Directory `ssh_aws`

Review the contents of the directory `ssh_aws` within your project directory after the deployment of MOADSD-NG.

### Connect to the master

SSH to the kubernetes master.

```sh
./ssh_master
```

Afterwards you have admin privileges on the cluster.

Some basic queries to try out:

```sh
kubectl get nodes

kubectl get deployments --all-namespaces

watch 'kubectl get pods --all-namespaces -o wide'

watch 'kubectl get pods -n smartcheck -o wide && echo && kubectl get services -n smartcheck -o wide'

kubectl get pods --all-namespaces -o wide --show-labels && \
  echo && kubectl get services --all-namespaces -o wide && \
  echo && kubectl get nodes

kubectl -n jenkins get pod --no-headers -o custom-columns=":metadata.name" | grep Jenkins

kubectl get pods --all-namespaces -o jsonpath="{..image}" | tr -s '[[:space:]]' '\n' | sort -u
```

Figure out what they are doing.

## Lab

When Jenkins Pipeline was first created, Groovy was selected as the foundation. Jenkins has long shipped with an embedded Groovy engine to provide advanced scripting capabilities for admins and users alike. Additionally, the implementors of Jenkins Pipeline found Groovy to be a solid foundation upon which to build what is now referred to as the "Scripted Pipeline" DSL.

As it is a fully featured programming environment, Scripted Pipeline offers a tremendous amount of flexibility and extensibility to Jenkins users. The Groovy learning-curve isn’t typically desirable for all members of a given team, so Declarative Pipeline was created to offer a simpler and more opinionated syntax for authoring Jenkins Pipeline.

The two are both fundamentally the same Pipeline sub-system underneath. They are both durable implementations of "Pipeline as code." They are both able to use steps built into Pipeline or provided by plugins. Both are able to utilize Shared Libraries

Where they differ however is in syntax and flexibility. Declarative limits what is available to the user with a more strict and pre-defined structure, making it an ideal choice for simpler continuous delivery pipelines. Scripted provides very few limits, insofar that the only limits on structure and syntax tend to be defined by Groovy itself, rather than any Pipeline-specific systems, making it an ideal choice for power-users and those with more complex requirements. As the name implies, Declarative Pipeline encourages a declarative programming model. Whereas Scripted Pipelines follow a more imperative programming model.

### Configure Jenkins

*Initial Warning*

With the initial login to Jenkins you likely get a proxy configuration error shown when accessing Manage Jenkins. Dismiss it.

#### Language

To ease the communication within the training you should set the language of Jenkins to English (if it is not already)
To set the locale go to

`Manage Jenkins → Configure System → Locale`

```text
Default Language: en
Ignore browser preference and force language to all users: check
```

[Save] in the bottom

#### Jenkins API Token

As soon as Jenkins is up and running, you can populate the credentials for Smart Check, Docker Hub, Cluster Registry and Kubernetes by using Ansible. To enable Ansible using the API you first need to create an API-token for the admin user:

Top right corner:

`admin → Configure → Add new Token`

```text
Name: admin
```

Copy the token into the configuration as `jenkins_token: <YOUR API TOKEN>`

```shell
./menu.sh
```

Choose option `aws`, then `configuration`

#### Integrate Jenkins with GitHub

Now, login to your GitHub account and afterwards go to my demo project troopers by clicking on the link below and fork it to your GitHub account.

<https://github.com/mawinkler/troopers.git>

Now you have a new repo in your account which you can freely modify.

To allow Jenkins work with your GitHub you need to create a personal access token for Jenkins.

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

File the token into your configuration.yml as `jenkins_github_access_token: <YOUR GITHUB ACCESS TOKEN>` by running the `menu.sh` and choosing `aws` and `configure`.

#### Update Credentials in Jenkins

Now, you can create the credentials either by running

```shell
./menu.sh
```

Choose option 2-aws and 4-jenkins_create_credentials

#### Automatic Builds - Let Jenkins configure your Web Hooks

Jenkins is able to manage GitHub WebHooks. To enable this you need to define the Personal Access Token from GitHub as a secret within Jenkins. This is done automatically by MOADSD-NG.

Additionally, as of now, go to `Manage Jenkins -> Configure System` and down to `GitHub Servers`. Hit `Add GitHub Server`.

```text
Name - doesn't matter
API URL - https://api.github.com
Credentials - choose github-access-token
Manage Hooks - checked
```

Hit `Test Connection` to make sure everything is kosher.

#### Accessing Blue Ocean

Jenkins itself does not look extremely beautiful, or? To enhance it a little we’re using Blue Ocean. Since our Jenkins environment has Blue Ocean installed, after logging in to the Jenkins classic UI, you can access the Blue Ocean UI by clicking Open Blue Ocean on the left.
Alternatively, you can access Blue Ocean directly by appending /blue to the end of your Jenkins server’s URL - e.g. <https://jenkins-server-url/blue>.

If your Jenkins instance:

- already has existing Pipeline projects or other items present, then the Blue Ocean Dashboard is displayed.
- is new or has no Pipeline projects or other items configured, then Blue Ocean displays a Welcome to Jenkins box with a Create a new Pipeline button you can use to begin creating a new Pipeline project.

So now, login to Jenkins, go to Blue Ocean and create a pipeline for our troopers. You will need the personal access token created within your GitHub account for that.

If everything works out, the pipeline should start to build after a few moments.

#### Integrate Pipelines

Next to the Troopers app there are some other apps you can seamlessly integrate with MOADSD-NG on my GitHub:

- [MoneyX](https://github.com/mawinkler/c1-app-sec-moneyx)
- [Uploader](https://github.com/mawinkler/c1-app-sec-uploader)
- [Django](https://github.com/mawinkler/c1-app-sec-djangonv)
- [Tomcat](https://github.com/mawinkler/c1-app-sec-tomcat)

They're all integrated with Smart Check and Application Security.

Feel free to build new things (and share them with me :-) ).

### Get Troopers up and running

You are pretty shocked since you thought that mawinkler’s repo should be clean and that he had done everything as best as possible – but failed with a highly critical vulnerability. Identify the cause. So what is the root cause for the vulnerability?

If you found the cause for the critical vulnerability mitigate it by changing some code and deploy the application.

To do this, do a git clone of your fork, do the fix, commit and push the changes.

If everything does work out, you should be able to access the troopers app on

`http://demoapp-<Jumphost-IP-with-DASHES>.nip.io`

### Identify unwanted PHP-code

There is one infected file within the troopers app. Identify it with the following Yara rule within Smart Check.

The implemented nice one looks like this:

```c
rule php_in_image
{
    meta:
        description = "Finds image files w/ PHP code in images"
        severity = "critical"

    strings:
        $gif = /^GIF8[79]a/
        $jfif = { ff d8 ff e? 00 10 4a 46 49 46 }
        $png = { 89 50 4e 47 0d 0a 1a 0a }

        $php_tag = "<?php"

    condition:
        (($gif at 0) or
        ($jfif at 0) or
        ($png at 0)) and

        $php_tag
}
```

Minimal variant would be:

```c
rule php_in_image
{
    strings:
        $php_tag = "<?php"

    condition:
        $php_tag
}
```

### Demoing

Lot's of possibilities here:

- Smart Check pipeline integration including the reporting tool
- Smart Check Findings, API, etc.
- Application Security with different flavours with pipeline integration
- Exploring the cluster and see the deployments
- Troubleshooting with Smart Check
- ...
