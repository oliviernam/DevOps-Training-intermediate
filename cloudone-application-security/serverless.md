# Serverless

- [Serverless](#serverless)
  - [Create a Workspace](#create-a-workspace)
  - [Install Node](#install-node)
  - [Update IAM Settings for the Workspace](#update-iam-settings-for-the-workspace)
  - [Install Serverless](#install-serverless)
    - [Install](#install)
    - [Create serverless AWS user](#create-serverless-aws-user)
    - [Create a Role for Lambda, S3, RDS](#create-a-role-for-lambda-s3-rds)
    - [Configure Serverless](#configure-serverless)
  - [Demoing Application Security with the Serverless InSekureStore](#demoing-application-security-with-the-serverless-insekurestore)
    - [Get the sources](#get-the-sources)
    - [Lambda Layers for Application Security](#lambda-layers-for-application-security)
    - [Modify the `variables.yml`](#modify-the-variablesyml)
    - [Deploy](#deploy)
    - [Upload Some Files](#upload-some-files)
    - [Access the Serverless Application](#access-the-serverless-application)
    - [Remove the InSekureStore](#remove-the-insekurestore)
  - [Cloud1 Application Security Configuration](#cloud1-application-security-configuration)
    - [Protection Policy](#protection-policy)
    - [SQL Injection Policy Configuration](#sql-injection-policy-configuration)
    - [Illegal File Access Policy Configuration](#illegal-file-access-policy-configuration)
    - [Remote Command Execution Policy Configuration](#remote-command-execution-policy-configuration)

Here, we're going to deploy a fully Lambda driven web application on AWS. Of course, we'll protect it by CloudOne Application Security.

## Create a Workspace

- Select Create Cloud9 environment
- Name it hoever you like, e.g. `serverless`
- Choose “t3.medium” for instance type and
- Ubuntu Server as the platform.
- For the rest take all default values and click Create environment
- When it comes up, customize the environment by closing the welcome tab and lower work area, and opening a new terminal tab in the main work area.

The virtual disk provisioned for Cloud9 is to small for our lab, therefore we need to increase the storage size before proceeding.

```shell
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

```shell
curl -sL https://deb.nodesource.com/setup_14.x | sudo -E bash -
sudo apt-get install -y nodejs
```

If you get the error `E: Cloud not get lock /var/lib/dpkg frontend lock...` you need to wait 2 to 3 minutes for the background task to complete. Simply retry the `apt-get install`. Then check the node version with

```shell
nodejs --version
```

```text
v14.07.0
```

## Update IAM Settings for the Workspace

- Click the gear icon (in top right corner), or click to open a new tab and choose “Open Preferences”
- Select AWS SETTINGS
- Turn off AWS managed temporary credentials
- Close the Preferences tab

Install AWS CLI.

```shell
sudo apt install -y awscli
```

## Install Serverless

### Install

```shell
sudo npm install -g serverless
serverless --version
```

```text
Framework Core: 1.78.1
Plugin: 3.7.0
SDK: 2.3.1
Components: 2.34.1
```

### Create serverless AWS user

Services in AWS, such as AWS Lambda, require that you provide credentials when you access them to ensure that you have permission to access the resources owned by that service. To accomplish this AWS recommends that you use AWS Identity and Access Management (IAM).

1. Login to your AWS account and go to the Identity & Access Management (IAM) page.
2. Follow this deep link to create the serverless AWS user: <https://console.aws.amazon.com/iam/home?region=eu-central-1#/users$new?step=review&accessKey&userNames=serverless-admin&groups=Administrators>
3. Confirm that `AWS service and EC2 are selected` and Group `Administrators` are listed, then click `Create user` to view permissions.
4. View and copy the API Key & Secret to a temporary place. You'll need it in the next step.

### Create a Role for Lambda, S3, RDS

1. Create a role by following this deep link: <https://console.aws.amazon.com/iam/home?region=eu-central-1#/roles$new?step=review&commonUseCase=Lambda%2BLambda&selectedUseCase=Lambda&policies=arn:aws:iam::aws:policy%2FAmazonS3FullAccess&policies=arn:aws:iam::aws:policy%2FAWSLambdaFullAccess&policies=arn:aws:iam::aws:policy%2FAmazonEC2FullAccess&policies=arn:aws:iam::aws:policy%2FAmazonRDSFullAccess>
2. Without chaning anything, press `Next: Permissions`, `Next: Tags`, `Next: Review`.
3. Set the Role name to `trend-demo-lambda-s3-role`, Press `Create` and note the ARN.

### Configure Serverless

Configure your Cloud9 AWS with the access keys of the just created serverless aws user

```shell
aws configure
```

## Demoing Application Security with the Serverless InSekureStore

### Get the sources

Do a git clone:

```shell
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

### Lambda Layers for Application Security

We do require a python3_6 layer

### Modify the `variables.yml`

Open the `variables.yml` in the Cloud9 editor and set your Application Security key and secret, region and role.

```yaml
# Cloud One Application Security Configs
TREND_AP_KEY: <your-ap-key-here>
TREND_AP_SECRET: <your-secret-key-here>
TREND_AP_READY_TIMEOUT: 30

# Lambda Function Configs
REGION: <your-region-here>
S3_BUCKET: insecures3-${file(s3bucketid.js):bucketId}
LAYER: arn:aws:lambda:${self:custom.variables.REGION}:800880067056:layer:CloudOne-ApplicationSecurity-runtime-python3_6:4
ROLE: <your-just-created-role-arn-here>
```

### Deploy

Install the python requirements for serverless.

```shell
serverless plugin install --name serverless-python-requirements
```

Configure serverless AWS provider credentials

```shell
serverless config credentials --provider aws --key <API KEY OF SERVERLESS USER CREATED ABOVE> --secret '<API SECRET KEY OF SERVERLESS USER CREATED ABOVE>' -o
```

And deploy

```shell
sls -v deploy --stage dev --aws-profile default
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

Before accessing the app, you need to initialize the database

```shell
sls invoke -f db -l --aws-profile default
```

### Upload Some Files

Within the AWS Console, go to S3 and find the bucket named `insecures3-SOMETHING` with `Public` access and upload some files there, e.g. the `kubernetes.png` and `kubernetes.txt` from the repo.

### Access the Serverless Application

You get the URL from the output above, ServiceEndpoint.

Default Credentials

```text
User: admin
Pass: admin
```

The first authentication can likely fail, since the database cluster might not be ready or in running state. This will happen always when you're going to use the app later on, since for cost saving reasons, the cluster suspends automatically after 90 minutes. Additionally, our Application Security layers need to be loaded. So if you're going to use this application for customer demos, play with it a little before the demo.

### Remove the InSekureStore

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
