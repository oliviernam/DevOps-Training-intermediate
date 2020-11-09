# Serverless

- [Serverless](#serverless)
  - [Serverless Framework vs. Cloud Formation](#serverless-framework-vs-cloud-formation)
  - [Create a Workspace](#create-a-workspace)
  - [Install Node](#install-node)
  - [Update IAM Settings for the Workspace](#update-iam-settings-for-the-workspace)
  - [Install Serverless](#install-serverless)
    - [Install](#install)
    - [Create serverless AWS user](#create-serverless-aws-user)
    - [Create a Role for Lambda, S3, RDS](#create-a-role-for-lambda-s3-rds)
  - [Deploy the Serverless InSekureStore](#deploy-the-serverless-insekurestore)
    - [Get the sources](#get-the-sources)
    - [Configure](#configure)
    - [Deploy](#deploy)
    - [Upload Some Files](#upload-some-files)
    - [Access the Serverless Application](#access-the-serverless-application)
    - [Remove the InSekureStore](#remove-the-insekurestore)
  - [Cloud One Application Security Configuration](#cloud-one-application-security-configuration)
    - [Protection Policy](#protection-policy)
    - [SQL Injection Policy Configuration](#sql-injection-policy-configuration)
    - [Illegal File Access Policy Configuration](#illegal-file-access-policy-configuration)
    - [Remote Command Execution Policy Configuration](#remote-command-execution-policy-configuration)
  - [InSekureStore - Attacks](#insekurestore---attacks)
    - [SQL Injection](#sql-injection)
    - [Directory Traversal](#directory-traversal)
    - [Remote Command Execution](#remote-command-execution)

Here, we're going to deploy a fully Lambda driven web application on AWS. Of course, we'll protect it by CloudOne Application Security.

## Serverless Framework vs. Cloud Formation

Within this lab, we're going to use serverless which is a framework to manage serverless deployments. More information on the framework including examples are [here](https://www.serverless.com/) and [here](https://www.serverless.com/framework/docs/).

To understand why there is something like serverless, let's compare it to the well known CloudFormation, which is an AWS tool for deploying infrastructure. You describe your desired infrastructure in YAML or JSON, then submit your CloudFormation template for deployment. It enables "infrastructure as code".

The Serverless Framework provides a configuration domain-specific language (DSL) which is designed for serverless applications. It also enables infrastructure as code while removing a lot of the boilerplate required for deploying serverless applications, including permissions, event subscriptions, logging, etc.

When deploying to AWS, the Serverless Framework is using CloudFormation under the hood. This means you can use the Serverless Framework's easy syntax to describe most of your Serverless Application while still having the ability to supplement with standard CloudFormation if needed.

The Serverless Framework is provider-agnostic, so you can use it to deploy serverless applications to AWS, Microsoft Azure, Google Cloud Platform, or many other providers. This reduces lock-in and enables a multi-cloud strategy while giving you a consistent experience across clouds.

Finally, the Serverless Framework assists with additional aspects of the serverless application lifecycle, including building your function package, invoking your functions for testing, and reviewing your application logs.

All clear? :-)

For later:

- [Examples](https://www.serverless.com/examples/)
- [Tutorial](https://www.serverless.com/blog/category/guides-and-tutorials/)

## Create a Workspace

Since we now know what we're going to do, let's start over:

- Select Create Cloud9 environment
- Name it hoever you like, e.g. `serverless`
- Choose “t3.medium” for instance type and
- Ubuntu Server as the platform.
- For the rest take all default values and click Create environment
- When it comes up, customize the environment by closing the welcome tab and lower work area, and opening a new terminal tab in the main work area.

The virtual disk provisioned for Cloud9 is to small for our lab, therefore we need to increase the storage size before proceeding.

```sh
SIZE=${1:-20}
INSTANCEID=$(curl http://169.254.169.254/latest/meta-data//instance-id)
VOLUMEID=$(aws ec2 describe-instances \
  --instance-id $INSTANCEID \
  --query "Reservations[0].Instances[0].BlockDeviceMappings[0].Ebs.VolumeId" \
  --output text)

aws ec2 modify-volume --volume-id $VOLUMEID --size $SIZE

while [ \
  "$(aws ec2 describe-volumes-modifications \
    --volume-id $VOLUMEID \
    --filters Name=modification-state,Values="optimizing","completed" \
    --query "length(VolumesModifications)"\
    --output text)" != "1" ]; do
echo -n .
sleep 1
done

sudo growpart /dev/nvme0n1 1
sudo resize2fs /dev/nvme0n1p1
```

## Install Node

```sh
curl -sL https://deb.nodesource.com/setup_14.x | sudo -E bash -
sudo apt-get install -y nodejs
```

If you get the error `E: Cloud not get lock /var/lib/dpkg frontend lock...` you need to wait 2 to 3 minutes for the background task to complete. Simply retry the `apt-get install`. Then check the node version with

```sh
nodejs --version
```

```text
v14.14.0
```

## Update IAM Settings for the Workspace

- Click the gear icon (in top right corner), or click to open a new tab and choose “Open Preferences”
- Select AWS SETTINGS
- Turn off AWS managed temporary credentials
- Close the Preferences tab

Install AWS CLI.

```sh
sudo apt install -y awscli
```

## Install Serverless

### Install

```sh
npm install -g serverless
serverless --version
```

```text
Framework Core: 2.8.0
Plugin: 4.1.1
SDK: 2.3.2
Components: 3.2.5
```

### Create serverless AWS user

Services in AWS, such as AWS Lambda, require that you provide credentials when you access them to ensure that you have permission to access the resources owned by that service. To accomplish this AWS recommends that you use AWS Identity and Access Management (IAM).

1. Login to your AWS account and go to the Identity & Access Management (IAM) page.
2. Follow this deep link to create the serverless AWS user: <https://console.aws.amazon.com/iam/home?#/users$new?step=review&accessKey&userNames=serverless-admin&groups=Administrators>
3. Confirm that Group `Administrators` is listed, then click `Create user` to view permissions.
4. View and copy the API Key & Secret to a temporary place. You'll need it in the next step.

### Create a Role for Lambda, S3, RDS

1. Create a role by following this deep link: <https://console.aws.amazon.com/iam/home?#/roles$new?step=review&commonUseCase=Lambda%2BLambda&selectedUseCase=Lambda&policies=arn:aws:iam::aws:policy%2FAmazonS3FullAccess&policies=arn:aws:iam::aws:policy%2FAWSLambdaFullAccess&policies=arn:aws:iam::aws:policy%2FAmazonEC2FullAccess&policies=arn:aws:iam::aws:policy%2FAmazonRDSFullAccess>
2. Without chaning anything, press `Next: Permissions`, `Next: Tags`, `Next: Review`.
3. Set the Role name to `serverless-lambda-s3-role`, Press `Create` and note the ARN.

## Deploy the Serverless InSekureStore

### Get the sources

Do a git clone:

```sh
git clone https://github.com/mawinkler/c1-app-sec-insekurestore.git
cd c1-app-sec-insekurestore
```

There is a `serverless.yml` and a `variables.yml`.
The `variables.yml` is included by the `serverless.yml` via a

```yaml
custom:
  variables: ${file(./variables.yml)}
```

No changes required in `serverless.yml`, a few within `variables.yml`

### Configure

Open the `variables.yml` in the Cloud9 editor and set your Application Security key and secret, region and role.
We're using a python3_6 layer with our custom runtime for this app.

```yaml
# Cloud One Application Security Configs
TREND_AP_KEY: <your-ap-key-here>
TREND_AP_SECRET: <your-secret-key-here>
TREND_AP_READY_TIMEOUT: 30

# Lambda Function Configs
REGION: <your-region-here>
S3_BUCKET: insekures3-${file(s3bucketid.js):bucketId}
LAYER: arn:aws:lambda:${self:custom.variables.REGION}:800880067056:layer:CloudOne-ApplicationSecurity-runtime-python3_6:4
ROLE: <your-just-created-role-arn-here>
```

### Deploy

Install the python requirements for serverless.

```sh
serverless plugin install --name serverless-python-requirements
```

Configure serverless AWS provider credentials

```sh
export AWS_KEY=<API KEY OF SERVERLESS USER CREATED ABOVE>
export AWS_SECRET=<API SECRET KEY OF SERVERLESS USER CREATED ABOVE>

serverless config credentials \
  --provider aws \
  --key ${AWS_KEY} \
  --secret ${AWS_SECRET} \
  -o
```

And deploy

```sh
serverless deploy
```

If everything is successful you will get a link to your lambda driven web application.

```text
...
Service Information
service: insekure-store
stage: dev
region: eu-central-1
stack: insekure-store-dev
resources: 75
api keys:
  None
endpoints:
  GET - https://ocwnfvuhg9.execute-api.eu-central-1.amazonaws.com/dev/
  GET - https://ocwnfvuhg9.execute-api.eu-central-1.amazonaws.com/dev/{file}
  POST - https://ocwnfvuhg9.execute-api.eu-central-1.amazonaws.com/dev/is_valid
  GET - https://ocwnfvuhg9.execute-api.eu-central-1.amazonaws.com/dev/list
  GET - https://ocwnfvuhg9.execute-api.eu-central-1.amazonaws.com/dev/get_file
  GET - https://ocwnfvuhg9.execute-api.eu-central-1.amazonaws.com/dev/read_file
  POST - https://ocwnfvuhg9.execute-api.eu-central-1.amazonaws.com/dev/write_file
  POST - https://ocwnfvuhg9.execute-api.eu-central-1.amazonaws.com/dev/delete_file
  POST - https://ocwnfvuhg9.execute-api.eu-central-1.amazonaws.com/dev/auth
functions:
  index: insekure-store-dev-index
  static: insekure-store-dev-static
  is_valid: insekure-store-dev-is_valid
  list: insekure-store-dev-list
  get_file: insekure-store-dev-get_file
  read_file: insekure-store-dev-read_file
  write_file: insekure-store-dev-write_file
  delete_file: insekure-store-dev-delete_file
  auth: insekure-store-dev-auth
  db: insekure-store-dev-db
layers:
  None
```

Before accessing the app, you need to initialize the database

```sh
serverless invoke -f db -l
```

```text
"DB Migrated Sucessfully"
```

### Upload Some Files

We're going to upload sample files to the stores bucket. This is named `insekures3-`SOMETHING with `Public` access.

```sh
export STORE_BUCKET=$(aws s3 ls | sed -n 's/.*\(insecures3.*\)/\1/p')
for f in kubernetes.* ; do aws s3 cp $f s3://${STORE_BUCKET}/$f ; done
```

### Access the Serverless Application

You get the URL from the output above, ServiceEndpoint.

Default Credentials

```text
User: admin
Pass: admin
```

The first authentication can likely fail, since the database cluster might not be ready or in running state. This will happen always when you're going to use the app later on, since for cost saving reasons, the cluster suspends automatically after 90 minutes. Additionally, our Application Security layers need to be loaded. So if you're going to use this application for customer demos, play with it a little before the demo.

### Remove the InSekureStore

```sh
serverless remove
```

## Cloud One Application Security Configuration

### Protection Policy

Enable all policies in your group configuration. When you start playing with the app, maybe have them in `Report` mode and switch later to `Block`.

### SQL Injection Policy Configuration

Turn on all controls

### Illegal File Access Policy Configuration

Leave everythin turned on

### Remote Command Execution Policy Configuration

Add the following rule on top of the preconfigured one:

```text
file "/tmp/*.*" -b              <-- Allow
.*                              <-- Block
```

## InSekureStore - Attacks

### SQL Injection

At the login screen

```text
E-Mail: 1'or'1'='1
```

```text
Password: 1'or'1'='1
```

*Application Security Protection by `SQL Injection - Always True`*

### Directory Traversal

URL

```text
...dev#/browser?view=../../../etc/passwd
```

### Remote Command Execution

Go to `Mime Type Params` and change to

```text
-b && whoami
```

or

```text
-b && uname -a
```

Within the details of a text file you will see the output of your command.

*Application Security Protection by `Remote Command Execution` or `Malicious Payload`.
