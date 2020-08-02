# Serverless

- [Serverless](#serverless)
  - [Install Node](#install-node)
  - [Install AWS cli](#install-aws-cli)
  - [Install Serverless](#install-serverless)
    - [Install](#install)
    - [Create serverless AWS user](#create-serverless-aws-user)
    - [Configure Serverless](#configure-serverless)
    - [Create a Role for Lambda, S3, RDS](#create-a-role-for-lambda-s3-rds)
  - [Demoing Application Security with the Serverless InSekureStore](#demoing-application-security-with-the-serverless-insekurestore)
    - [Lambda Layers for Application Security](#lambda-layers-for-application-security)
    - [Modify the `variables.yml`](#modify-the-variablesyml)
    - [Deploy](#deploy)
    - [Remove](#remove)
  - [Cloud1 Application Security Configuration](#cloud1-application-security-configuration)
    - [Protection Policy](#protection-policy)
    - [SQL Injection Policy Configuration](#sql-injection-policy-configuration)
    - [Illegal File Access Policy Configuration](#illegal-file-access-policy-configuration)
    - [Remote Command Execution Policy Configuration](#remote-command-execution-policy-configuration)

Here, we're going to deploy a fully Lambda driven web application on AWS. Of course, we're going to protect it by CloudOne Application Security.

## Install Node

```shell
curl -sL https://deb.nodesource.com/setup_13.x | sudo -E bash -
sudo apt-get install -y nodejs
node --version
```

```text
v13.11.0
```

## Install AWS cli

```shell
sudo apt install -y awscli
aws configure
```

## Install Serverless

### Install

```shell
sudo npm install -g serverless
serverless --version
```

```text
Framework Core: 1.67.0
Plugin: 3.6.0
SDK: 2.3.0
Components: 2.22.3
```

Now, at least install the python requirements for serverless.

```shell
sudo serverless plugin install --name serverless-python-requirements
```

### Create serverless AWS user

Services in AWS, such as AWS Lambda, require that you provide credentials when you access them to ensure that you have permission to access the resources owned by that service. To accomplish this AWS recommends that you use AWS Identity and Access Management (IAM).

1. Login to your AWS account and go to the Identity & Access Management (IAM) page.

2. Click on Users and then Add user. Enter a name in the first field to remind you this User is related to the Serverless Framework, like serverless-admin. Enable Programmatic access by clicking the checkbox. Click Next to go through to the Permissions page. Click on Attach existing policies directly. Search for and select `AdministratorAccess` then click Next: Review. Check to make sure everything looks good and click Create user.

3. View and copy the API Key & Secret to a temporary place. You'll need it in the next step.

### Configure Serverless

```shell
aws configure
```

### Create a Role for Lambda, S3, RDS

Create a role with the following permissions:

```text
AmazonS3FullAccess
AWSLambdaFullAccess
AmazonEC2FullAccess
AmazonRDSFullAccess
```

and name it `trend-demo-lambda-s3-role`
Save the ARN.

## Demoing Application Security with the Serverless InSekureStore

There is a `serverless.yml` and a `variables.yml`.
The `variables.yml` is included by the `serverless.yml` via a

```yaml
custom:
  variables: ${file(./variables.yml)}
```

No changes required in `serverless.yml`, a few within `variables.yml`

### Lambda Layers for Application Security

We do require a python3_6 layer

### Modify the `variables.yml`

```shell
vi variables.yml
```

Set your Application Security key and secret, region and role.

```yaml
# Cloud One Application Security Configs
TREND_AP_KEY: <your-ap-key-here>
TREND_AP_SECRET: <your-secret-key-here>
TREND_AP_READY_TIMEOUT: 30

# Lambda Function Configs
REGION: <your-region-here>
S3_BUCKET: insecures3-${file(s3bucketid.js):bucketId}
LAYER: arn:aws:lambda:${self:custom.variables.REGION}:321717822244:layer:DS-AppProtect-DEV-python3_6:11
ROLE: <your-just-created-role-arn-here>
```

### Deploy

```shell
sls -v deploy --stage dev --aws-profile default
sls invoke -f db -l --aws-profile default
```

If everything is successful you will get a link to your lambda driven web application.

```text
Service Information
service: insekure-store
stage: dev
region: eu-central-1
stack: insekure-store-dev
resources: 76
api keys:
  None
endpoints:
  GET - https://3ovy8p00n9.execute-api.eu-central-1.amazonaws.com/dev/
  GET - https://3ovy8p00n9.execute-api.eu-central-1.amazonaws.com/dev/{file}
  POST - https://3ovy8p00n9.execute-api.eu-central-1.amazonaws.com/dev/is_valid
  GET - https://3ovy8p00n9.execute-api.eu-central-1.amazonaws.com/dev/list
  GET - https://3ovy8p00n9.execute-api.eu-central-1.amazonaws.com/dev/get_file
  GET - https://3ovy8p00n9.execute-api.eu-central-1.amazonaws.com/dev/read_file
  POST - https://3ovy8p00n9.execute-api.eu-central-1.amazonaws.com/dev/write_file
  POST - https://3ovy8p00n9.execute-api.eu-central-1.amazonaws.com/dev/delete_file
  POST - https://3ovy8p00n9.execute-api.eu-central-1.amazonaws.com/dev/auth
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

Stack Outputs
ServiceEndpoint: https://3ovy8p00n9.execute-api.eu-central-1.amazonaws.com/dev
ServerlessDeploymentBucketName: insekure-store-dev-serverlessdeploymentbucket-dopk8qr47fi2

Serverless: Run the "serverless" command to setup monitoring, troubleshooting and testing.
```

Default Credentials

```text
User: admin
Pass: admin
```

### Remove

```shell
sls remove --aws-profile default
```

## Cloud1 Application Security Configuration

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
