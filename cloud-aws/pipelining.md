# CI/CD with AWS CodePipeline

- [CI/CD with AWS CodePipeline](#cicd-with-aws-codepipeline)
  - [Create a Workspace](#create-a-workspace)
    - [Install Kubernetes tools](#install-kubernetes-tools)
    - [Create an IAM Role for the Workspace](#create-an-iam-role-for-the-workspace)
    - [Attach the IAM Role to the Workspace](#attach-the-iam-role-to-the-workspace)
    - [Update IAM Settings for the Workspace](#update-iam-settings-for-the-workspace)
    - [Create an SSH key](#create-an-ssh-key)
    - [Create an AWS KMS Custom Managed Key (CMK)](#create-an-aws-kms-custom-managed-key-cmk)
  - [EKS](#eks)
    - [Install EKS tools and Helm](#install-eks-tools-and-helm)
    - [Launch an EKS cluster](#launch-an-eks-cluster)
  - [Deploy CloudOne Image Security](#deploy-cloudone-image-security)
  - [CI/CD with CodePipeline](#cicd-with-codepipeline)
    - [Create IAM Role for EKS](#create-iam-role-for-eks)
    - [Modify AWS-Auth ConfigMap](#modify-aws-auth-configmap)
    - [Fork Sample Repository](#fork-sample-repository)
    - [Create the Buildspec](#create-the-buildspec)
    - [Create Kubernetes Deployment and Service Definition](#create-kubernetes-deployment-and-service-definition)
    - [GitHub Access Token](#github-access-token)
    - [CodePipeline Setup](#codepipeline-setup)
  - [CodePipeline CloudFormation *ci-cd-codepipeline.cfn.yml:*](#codepipeline-cloudformation-ci-cd-codepipelinecfnyml)
  - [*BuildSpec.yml*](#buildspecyml)

## Create a Workspace

- Select Create Cloud9 environment
- Name it somehow like `ekscluster` (at least have the word ekscluster within the name)
- Choose “t3.small” for instance type, take all default values and click Create environment
- When it comes up, customize the environment by closing the welcome tab and lower work area, and opening a new terminal tab in the main work area.

### Install Kubernetes tools

```shell
sudo curl --silent --location -o /usr/local/bin/kubectl https://amazon-eks.s3.us-west-2.amazonaws.com/1.15.10/2020-02-22/bin/linux/amd64/kubectl
sudo chmod +x /usr/local/bin/kubectl
```

Update awscli

```shell
sudo pip install --upgrade awscli && hash -r
```

Install jq, envsubst (from GNU gettext utilities) and bash-completion

```shell
sudo yum -y install jq gettext bash-completion
```

Verify the binaries are in the path and executable

```shell
for command in kubectl jq envsubst aws
  do
    which $command &>/dev/null && echo "$command in path" || echo "$command NOT FOUND"
  done
```

Enable kubectl bash_completion

```shell
kubectl completion bash >>  ~/.bash_completion
. /etc/profile.d/bash_completion.sh
. ~/.bash_completion
```

### Create an IAM Role for the Workspace

- Follow this deep link to create an IAM role with Administrator access.
<https://console.aws.amazon.com/iam/home#/roles$new?step=review&commonUseCase=EC2%2BEC2&selectedUseCase=EC2&policies=arn:aws:iam::aws:policy%2FAdministratorAccess>

- Confirm that AWS service and EC2 are selected, then click Next to view permissions.
- Confirm that AdministratorAccess is checked, then click Next: Tags to assign tags.
- Take the defaults, and click Next: Review to review.
- Enter ekscluster-admin for the Name, and click Create role.

### Attach the IAM Role to the Workspace

- Follow this deep link to find your Cloud9 EC2 instance
<https://console.aws.amazon.com/ec2/v2/home?#Instances:tag:Name=aws-cloud9-.*ekscluster.*;sort=desc:launchTime>

- Select the instance, then choose Actions / Instance Settings / Attach/Replace IAM Rolec9instancerole
- Choose ekscluster-admin from the IAM Role drop down, and select Apply

### Update IAM Settings for the Workspace

- Return to your workspace and click the gear icon (in top right corner), or click to open a new tab and choose “Open Preferences”
- Select AWS SETTINGS
- Turn off AWS managed temporary credentials
- Close the Preferences tab

To ensure temporary credentials aren’t already in place we will also remove any existing credentials file:

```shell
rm -vf ${HOME}/.aws/credentials
```

We should configure our aws cli with our current region as default.

```shell
export ACCOUNT_ID=$(aws sts get-caller-identity --output text --query Account)
export AWS_REGION=$(curl -s 169.254.169.254/latest/dynamic/instance-identity/document | jq -r '.region')
```

Check if AWS_REGION is set to desired region

```shell
test -n "$AWS_REGION" && echo AWS_REGION is "$AWS_REGION" || echo AWS_REGION is not set
```

Let’s save these into bash_profile

```shell
echo "export ACCOUNT_ID=${ACCOUNT_ID}" | tee -a ~/.bash_profile
echo "export AWS_REGION=${AWS_REGION}" | tee -a ~/.bash_profile
aws configure set default.region ${AWS_REGION}
aws configure get default.region
```

Validate the IAM role
Use the GetCallerIdentity CLI command to validate that the Cloud9 IDE is using the correct IAM role.

```shell
aws sts get-caller-identity --query Arn | grep ekscluster-admin -q && echo "IAM role valid" || echo "IAM role NOT valid"
```

### Create an SSH key

Please run this command to generate SSH Key in Cloud9. This key will be used on the worker node instances to allow ssh access if necessary.

```shell
ssh-keygen -q -f ~/.ssh/id_rsa -P ""
```

Press enter 3 times to take the default choices

Upload the public key to your EC2 region:

```shell
aws ec2 import-key-pair --key-name "ekscluster" --public-key-material file://~/.ssh/id_rsa.pub
```

If you got an error similar to An error occurred (InvalidKey.Format) when calling the ImportKeyPair operation: Key is not in valid OpenSSH public key format then you can try this command instead:

```shell
aws ec2 import-key-pair --key-name "ekscluster" --public-key-material fileb://~/.ssh/id_rsa.pub
```

### Create an AWS KMS Custom Managed Key (CMK)

Create a CMK for the EKS cluster to use when encrypting your Kubernetes secrets:

```shell
aws kms create-alias --alias-name alias/ekscluster --target-key-id $(aws kms create-key --query KeyMetadata.Arn --output text)
```

Let’s retrieve the ARN of the CMK to input into the create cluster command.

```shell
export MASTER_ARN=$(aws kms describe-key --key-id alias/ekscluster --query KeyMetadata.Arn --output text)
```

We set the MASTER_ARN environment variable to make it easier to refer to the KMS key later.

Now, let’s save the MASTER_ARN environment variable into the bash_profile

```shell
echo "export MASTER_ARN=${MASTER_ARN}" | tee -a ~/.bash_profile
```

## EKS

### Install EKS tools and Helm

For this module, we need to download the eksctl binary:

```shell
curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp

sudo mv -v /tmp/eksctl /usr/local/bin
```

Confirm the eksctl command works:

```shell
eksctl version
```

Enable eksctl bash-completion

```shell
eksctl completion bash >> ~/.bash_completion
. /etc/profile.d/bash_completion.sh
. ~/.bash_completion
```

Finally, we need to install Helm:

```shell
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3
chmod +x get_helm.sh
./get_helm.sh
```

And confirm that helm works:

```shell
helm version
```

### Launch an EKS cluster

Run

```shell
aws sts get-caller-identity
```

and validate that your Arn contains ekscluster-admin and an Instance Id.

```shell
{
    "Account": "123456789012",
    "UserId": "AROA1SAMPLEAWSIAMROLE:i-01234567890abcdef",
    "Arn": "arn:aws:sts::123456789012:assumed-role/ekscluster-admin/i-01234567890abcdef"
}
```

Create an eksctl deployment file (ekscluster.yaml) use in creating your cluster using the following syntax:

```shell
cat << EOF > ekscluster.yaml
---
apiVersion: eksctl.io/v1alpha5
kind: ClusterConfig

metadata:
  name: ekscluster-eksctl
  region: ${AWS_REGION}

managedNodeGroups:
- name: nodegroup
  desiredCapacity: 3
  iam:
    withAddonPolicies:
      albIngress: true

secretsEncryption:
  keyARN: ${MASTER_ARN}
EOF
```

Next, use the file you created as the input for the eksctl cluster creation.

```shell
eksctl create cluster -f ekscluster.yaml
```

Confirm your nodes:

```shell
kubectl get nodes # if we see our 3 nodes, we know we have authenticated correctly
```

## Deploy CloudOne Image Security

Create CloudOne Image Security namespace

```shell
export DSSC_NAMESPACE=smartcheck
kubectl create namespace ${DSSC_NAMESPACE}
```

Create certificate request for load balancer certificate:

```shell
cat <<EOF>./req.conf
[req]
  distinguished_name=req
[san]
  subjectAltName=DNS:*.${AWS_REGION}.elb.amazonaws.com
EOF

openssl req -x509 -newkey rsa:4096 -sha256 -days 3650 -nodes -keyout k8s.key -out k8s.crt -subj "/CN=*.${AWS_REGION}.elb.amazonaws.com" -extensions san -config req.conf
kubectl create secret tls k8s-certificate --cert=k8s.crt --key=k8s.key --dry-run=true -n ${DSSC_NAMESPACE} -o yaml | kubectl apply -f -
```

Create overrides for Image Security:

```shell
export DSSC_AC=<activation code>
export DSSC_USERNAME=admin
export DSSC_TEMPPW=TrendMicro
export DSSC_REGUSER=reguser
export DSSC_REGPASSWORD=TrendMicro
cat <<EOF >./overrides.yml
##
## Default value: (none)
activationCode: '${DSSC_AC}'
auth:
  ## secretSeed is used as part of the password generation process for
  ## all auto-generated internal passwords, ensuring that each installation of
  ## Deep Security Smart Check has different passwords.
  ##
  ## Default value: {must be provided by the installer}
  secretSeed: 'just_anything-really_anything'
  ## userName is the name of the default administrator user that the system creates on startup.
  ## If a user with this name already exists, no action will be taken.
  ##
  ## Default value: administrator
  ## userName: administrator
  userName: '${DSSC_USERNAME}'
  ## password is the password assigned to the default administrator that the system creates on startup.
  ## If a user with the name 'auth.userName' already exists, no action will be taken.
  ##
  ## Default value: a generated password derived from the secretSeed and system details
  ## password: # autogenerated
  password: '${DSSC_TEMPPW}'
registry:
  ## Enable the built-in registry for pre-registry scanning.
  ##
  ## Default value: false
  enabled: true
    ## Authentication for the built-in registry
  auth:
    ## User name for authentication to the registry
    ##
    ## Default value: empty string
    username: '${DSSC_REGUSER}'
    ## Password for authentication to the registry
    ##
    ## Default value: empty string
    password: '${DSSC_REGPASSWORD}'
    ## The amount of space to request for the registry data volume
    ##
    ## Default value: 5Gi
  dataVolume:
    sizeLimit: 10Gi
certificate:
  secret:
    name: k8s-certificate
    certificate: tls.crt
    privateKey: tls.key
EOF
```

Install Image Security

```shell
helm install -n ${DSSC_NAMESPACE} --values overrides.yml deepsecurity-smartcheck https://github.com/deep-security/smartcheck-helm/archive/master.tar.gz > /dev/null
```

Wait for Image Security to be up and do the initial password change:

```shell
DSSC_HOST=''
while [[ "$DSSC_HOST" == '' ]];do
  export DSSC_HOST=`kubectl get svc -n ${DSSC_NAMESPACE} proxy -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'`
  sleep 10
done
DSSC_BEARERTOKEN=''
while [[ "$DSSC_BEARERTOKEN" == '' ]];do
  sleep 10
  DSSC_USERID=`curl -s -k -X POST https://${DSSC_HOST}/api/sessions -H "Content-Type: application/json"  -H "Api-Version: 2018-05-01" -H "cache-control: no-cache" -d "{\"user\":{\"userid\":\"${DSSC_USERNAME}\",\"password\":\"${DSSC_TEMPPW}\"}}" | jq '.user.id' | tr -d '"'  2>/dev/null`
  DSSC_BEARERTOKEN=`curl -s -k -X POST https://${DSSC_HOST}/api/sessions -H "Content-Type: application/json"  -H "Api-Version: 2018-05-01" -H "cache-control: no-cache" -d "{\"user\":{\"userid\":\"${DSSC_USERNAME}\",\"password\":\"${DSSC_TEMPPW}\"}}" | jq '.token' | tr -d '"'  2>/dev/null`
  printf '%s' "."
done
printf '%s \n' " "
DUMMY=`curl -s -k -X POST https://${DSSC_HOST}/api/users/${DSSC_USERID}/password -H "Content-Type: application/json"  -H "Api-Version: 2018-05-01" -H "cache-control: no-cache" -H "authorization: Bearer ${DSSC_BEARERTOKEN}" -d "{  \"oldPassword\": \"${DSSC_TEMPPW}\", \"newPassword\": \"${DSSC_PASSWORD}\"  }"`
printf '%s \n' "export DSSC_HOST=${DSSC_HOST}" > cloudOneCredentials.txt
printf '%s \n' "export DSSC_USERNAME=${DSSC_USERNAME}" >> cloudOneCredentials.txt
printf '%s \n' "export DSSC_PASSWORD=${DSSC_PASSWORD}" >> cloudOneCredentials.txt

printf '%s \n' "--------------"
printf '%s \n' "     URL     : https://${DSSC_HOST}"
printf '%s \n' "     User    : ${DSSC_USERNAME}"
printf '%s \n' "     Password: ${DSSC_PASSWORD}"
printf '%s \n' "--------------"
```

## CI/CD with CodePipeline

### Create IAM Role for EKS

In an AWS CodePipeline, we are going to use AWS CodeBuild to deploy a sample Kubernetes service. This requires an AWS Identity and Access Management (IAM) role capable of interacting with the EKS cluster.

In this step, we are going to create an IAM role and add an inline policy that we will use in the CodeBuild stage to interact with the EKS cluster via kubectl.

Create the role:

```shell
TRUST="{ \"Version\": \"2012-10-17\", \"Statement\": [ { \"Effect\": \"Allow\", \"Principal\": { \"AWS\": \"arn:aws:iam::${ACCOUNT_ID}:root\" }, \"Action\": \"sts:AssumeRole\" } ] }"
echo '{ "Version": "2012-10-17", "Statement": [ { "Effect": "Allow", "Action": "eks:Describe*", "Resource": "*" } ] }' > /tmp/iam-role-policy
aws iam create-role --role-name EksClusterCodeBuildKubectlRole --assume-role-policy-document "$TRUST" --output text --query 'Role.Arn'
aws iam put-role-policy --role-name EksClusterCodeBuildKubectlRole --policy-name eks-describe --policy-document file:///tmp/iam-role-policy
```

### Modify AWS-Auth ConfigMap

Now that we have the IAM role created, we are going to add the role to the aws-auth ConfigMap for the EKS cluster.

Once the ConfigMap includes this new role, kubectl in the CodeBuild stage of the pipeline will be able to interact with the EKS cluster via the IAM role.

```shell
ROLE="    - rolearn: arn:aws:iam::$ACCOUNT_ID:role/EksClusterCodeBuildKubectlRole\n      username: build\n      groups:\n        - system:masters"
kubectl get -n kube-system configmap/aws-auth -o yaml | awk "/mapRoles: \|/{print;print \"$ROLE\";next}1" > /tmp/aws-auth-patch.yml
kubectl patch configmap/aws-auth -n kube-system --patch "$(cat /tmp/aws-auth-patch.yml)"
```

### Fork Sample Repository

We are now going to fork the sample Kubernetes service so that we will be able modify the repository and trigger builds.

Login to GitHub and fork the Troopers app:

<https://github.com/mawinkler/troopers>

### Create the Buildspec

```yaml
---
version: 0.2
phases:
  install:
    commands:
      - curl -sS -o aws-iam-authenticator https://amazon-eks.s3-us-west-2.amazonaws.com/1.10.3/2018-07-26/bin/linux/amd64/aws-iam-authenticator
      - curl -sS -o kubectl https://amazon-eks.s3-us-west-2.amazonaws.com/1.14.6/2019-08-22/bin/linux/amd64/kubectl
      - chmod +x ./kubectl ./aws-iam-authenticator
      - export PATH=$PWD/:$PATH
      - apt-get update && apt-get -y install jq python3-pip python3-dev && pip3 install --upgrade awscli
      #
      # If using not publicly trusted certificates:
      #
      # - export PRE_SCAN_REPOSITORY_CLEAN=$(echo $PRE_SCAN_REPOSITORY | sed -e 's|^[^/]*//||' -e 's/[/:].*$//')
      # - openssl s_client -showcerts -connect $PRE_SCAN_REPOSITORY_CLEAN:443 < /dev/null | sed -ne '/-BEGIN CERTIFICATE-/,/-END CERTIFICATE-/p' > smcert.crt
      # - cp smcert.crt /usr/local/share/ca-certificates/$PRE_SCAN_REPOSITORY.crt
      # - update-ca-certificates
  pre_build:
      commands:
        # - TAG="$REPOSITORY_NAME.$REPOSITORY_BRANCH.$ENVIRONMENT_NAME.$(date +%Y-%m-%d.%H.%M.%S).$(echo $CODEBUILD_RESOLVED_SOURCE_VERSION | head -c 8)"
        - TAG="latest"
        - sed -i 's@CONTAINER_IMAGE@'"$REPOSITORY_URI:$TAG"'@' app-eks.yml
        - $(aws ecr get-login --no-include-email)
        - export KUBECONFIG=$HOME/.kube/config
  build:
    commands:
      - docker build --tag $REPOSITORY_URI:$TAG .

  post_build:
    commands:
      # Smart Check Pre-Registry-Scan
      - >-
        docker run -v /var/run/docker.sock:/var/run/docker.sock
        deepsecurity/smartcheck-scan-action
        --image-name "$REPOSITORY_URI:$TAG"
        --findings-threshold "{\"malware\":0,\"vulnerabilities\":{\"defcon1\":0,\"critical\":0,\"high\":1},\"contents\":{\"defcon1\":0,\"critical\":1,\"high\":1},\"checklists\":{\"defcon1\":0,\"critical\":0,\"high\":0}}"
        --preregistry-host="$PRE_SCAN_REPOSITORY"
        --smartcheck-host="$SMARTCHECK_HOST"
        --smartcheck-user="$SMARTCHECK_USER"
        --smartcheck-password="$SMARTCHECK_PWD"
        --insecure-skip-tls-verify
        --preregistry-scan
        --preregistry-user "$PRE_SCAN_USER"
        --preregistry-password "$PRE_SCAN_PWD"

      # Push to ECR
      - docker push $REPOSITORY_URI:$TAG

      # Deploy to EKS
      - CREDENTIALS=$(aws sts assume-role --role-arn $EKS_KUBECTL_ROLE_ARN --role-session-name codebuild-kubectl --duration-seconds 900)
      - export AWS_ACCESS_KEY_ID="$(echo ${CREDENTIALS} | jq -r '.Credentials.AccessKeyId')"
      - export AWS_SECRET_ACCESS_KEY="$(echo ${CREDENTIALS} | jq -r '.Credentials.SecretAccessKey')"
      - export AWS_SESSION_TOKEN="$(echo ${CREDENTIALS} | jq -r '.Credentials.SessionToken')"
      - export AWS_EXPIRATION=$(echo ${CREDENTIALS} | jq -r '.Credentials.Expiration')
      - aws eks update-kubeconfig --name $EKS_CLUSTER_NAME
      - kubectl apply -f app-eks.yml
      - printf '[{"name":"troopers","imageUri":"%s"}]' $REPOSITORY_URI:$TAG > build.json
artifacts:
  files: build.json
```

### Create Kubernetes Deployment and Service Definition

```yaml
apiVersion: v1
kind: Service
metadata:
  annotations:
    service.alpha.kubernetes.io/tolerate-unready-endpoints: "true"
  name: troopers
  labels:
    app: troopers
spec:
  type: LoadBalancer
  ports:
  - port: 5000
    name: troopers
    targetPort: 5000
  selector:
    app: troopers
---
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app: troopers
  name: troopers
spec:
  replicas: 1
  selector:
    matchLabels:
      app: troopers
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 1
  template:
    metadata:
      labels:
        app: troopers
    spec:
      containers:
      - name: troopers
        image: CONTAINER_IMAGE
        imagePullPolicy: Always
        ports:
        - containerPort: 5000
```

### GitHub Access Token

In order for CodePipeline to receive callbacks from GitHub, we need to generate a personal access token.

Once created, an access token can be stored in a secure enclave and reused, so this step is only required during the first run or when you need to generate new keys.

Open up the New personal access page in GitHub.

Enter a value for Token description, check the repo permission scope and scroll down and click the Generate token button

### CodePipeline Setup

Each EKS deployment/service should have its own CodePipeline and be located in an isolated source repository.

Now we are going to create the AWS CodePipeline using AWS CloudFormation.

Click the Launch button to create the CloudFormation stack in the AWS Management Console.

<https://console.aws.amazon.com/cloudformation/home?#/stacks/create/review?stackName=troopers-codepipeline&templateURL=https://moadsd-ng.s3.eu-central-1.amazonaws.com/troopers-pipeline.cfn.yml>

After the console is open, enter your GitHub username, personal access token (created in previous step), check the acknowledge box and then click the “Create stack” button located at the bottom of the page.

Wait for the status to change from “CREATE_IN_PROGRESS” to CREATE_COMPLETE before moving on to the next step.

Open CodePipeline in the Management Console. You will see a CodePipeline that starts with troopers-codepipeline. Click this link to view the details.
<https://console.aws.amazon.com/codesuite/codepipeline/pipelines>

To review the status of the deployment, you can run:

```shell
kubectl describe deployment troopers
```

For the status of the service, run the following command:

```shell
kubectl describe service troopers
```

## CodePipeline CloudFormation *ci-cd-codepipeline.cfn.yml:*

```yaml
---
AWSTemplateFormatVersion: 2010-09-09

Description: Troopers Pipeline


Parameters:

  EksClusterName:
    Type: String
    Description: The name of the EKS cluster created
    Default: ekscluster-eksctl
    MinLength: 1
    MaxLength: 100
    ConstraintDescription: You must enter the EKS cluster name

  # TODO: Update this to final repo name
  GitSourceRepo:
    Type: String
    Description: GitHub source repository - must contain a Dockerfile and buildspec.yml in the base
    Default: troopers
    MinLength: 1
    MaxLength: 100
    ConstraintDescription: You must enter a GitHub repository name

  GitBranch:
    Type: String
    Default: master
    Description: GitHub git repository branch - change triggers a new build
    MinLength: 1
    MaxLength: 100
    ConstraintDescription: You must enter a GitHub repository branch name

  GitHubToken:
    Type: String
    NoEcho: true
    Description: GitHub API token - see https://github.com/blog/1509-personal-api-tokens
    MinLength: 3
    MaxLength: 100
    ConstraintDescription: You must enter a GitHub personal access token

  GitHubUser:
    Type: String
    Description: GitHub username or organization
    MinLength: 3
    MaxLength: 100
    ConstraintDescription: You must enter a GitHub username or organization

  CodeBuildDockerImage:
    Type: String
    Default: aws/codebuild/docker:17.09.0
    Description: Default AWS CodeBuild Docker optimized image
    MinLength: 3
    MaxLength: 100
    ConstraintDescription: You must enter a CodeBuild Docker image

  KubectlRoleName:
    Type: String
    Default: EksClusterCodeBuildKubectlRole
    Description: IAM role used by kubectl to interact with EKS cluster
    MinLength: 3
    MaxLength: 100
    ConstraintDescription: You must enter a kubectl IAM role

  SmartcheckHost:
    Type: String
    Default: smartcheck-X-X-X-X.nip.io
    Description: Smartcheck host URL
    MinLength: 1
    MaxLength: 100
    ConstraintDescription: You must enter a Smartcheck host URL

  SmartcheckUser:
    Type: String
    Default: admin
    Description: The user for Smartcheck
    MinLength: 1
    MaxLength: 100

  SmartcheckPwd:
    Type: String
    NoEcho: true
    Description: The password for Smartcheck user
    MinLength: 1
    MaxLength: 100
    ConstraintDescription: You must enter a password for the Smartcheck user

  PreregistryHost:
    Type: String
    Default: smartcheck-registry-X-X-X-X.nip.io
    Description: Smartcheck host URL
    MinLength: 1
    MaxLength: 100
    ConstraintDescription: You must enter a Smartcheck host URL

  PreregistryUser:
    Type: String
    Default: reguser
    Description: The user for Pre-Registry
    MinLength: 1
    MaxLength: 100
    ConstraintDescription: You must enter a user for the Pre-Registry

  PreregistryPwd:
    Type: String
    NoEcho: true
    Description: The password for Pre-Registry user
    MinLength: 1
    MaxLength: 100
    ConstraintDescription: You must enter a password for the Pre-Registry user

Metadata:
  AWS::CloudFormation::Interface:
    ParameterGroups:
      - Label:
          default: GitHub
        Parameters:
          - GitHubUser
          - GitHubToken
          - GitSourceRepo
          - GitBranch
      - Label:
          default: CodeBuild
        Parameters:
          - CodeBuildDockerImage
      - Label:
          default: IAM
        Parameters:
          - KubectlRoleName
      - Label:
          default: EKS
        Parameters:
          - EksClusterName
      - Label:
          default: ImageSecurity
        Parameters:
          - SmartcheckHost
          - SmartcheckUser
          - SmartcheckPwd
          - PreregistryHost
          - PreregistryUser
          - PreregistryPwd
    ParameterLabels:
      GitHubUser:
        default: Username
      GitHubToken:
        default: Access token
      GitSourceRepo:
        default: Repository
      GitBranch:
        default: Branch
      CodeBuildDockerImage:
        default: Docker image
      KubectlRoleName:
        default: kubectl IAM role
      EksClusterName:
        default: EKS cluster name
      SmartcheckHost:
        default: Smartcheck Host URL
      SmartcheckUser:
        default: Smartcheck User
      SmartcheckPwd:
        default: Smartcheck Password
      PreregistryHost:
        default: Pre-registry Host URL
      PreregistryUser:
        default: Pre-registry User
      PreregistryPwd:
        default: Pre-registry Password

Resources:

  EcrDockerRepository:
    Type: AWS::ECR::Repository
    DeletionPolicy: Retain

  CodePipelineArtifactBucket:
    Type: AWS::S3::Bucket
    DeletionPolicy: Retain

  CodePipelineServiceRole:
    Type: AWS::IAM::Role
    Properties:
      Path: /
      AssumeRolePolicyDocument:
        Version: 2012-10-17
        Statement:
          - Effect: Allow
            Principal:
              Service: codepipeline.amazonaws.com
            Action: sts:AssumeRole
      Policies:
        - PolicyName: codepipeline-access
          PolicyDocument:
            Version: 2012-10-17
            Statement:
              - Resource: "*"
                Effect: Allow
                Action:
                  - codebuild:StartBuild
                  - codebuild:BatchGetBuilds
                  - codecommit:GetBranch
                  - codecommit:GetCommit
                  - codecommit:UploadArchive
                  - codecommit:GetUploadArchiveStatus
                  - codecommit:CancelUploadArchive
                  - iam:PassRole
              - Resource: !Sub arn:aws:s3:::${CodePipelineArtifactBucket}/*
                Effect: Allow
                Action:
                  - s3:PutObject
                  - s3:GetObject
                  - s3:GetObjectVersion
                  - s3:GetBucketVersioning
    DependsOn: CodePipelineArtifactBucket

  CodeBuildServiceRole:
    Type: AWS::IAM::Role
    Properties:
      Path: /
      AssumeRolePolicyDocument:
        Version: 2012-10-17
        Statement:
          - Effect: Allow
            Principal:
              Service: codebuild.amazonaws.com
            Action: sts:AssumeRole
      Policies:
        - PolicyName: root
          PolicyDocument:
            Version: 2012-10-17
            Statement:
              - Resource: !Sub arn:aws:iam::${AWS::AccountId}:role/${KubectlRoleName}
                Effect: Allow
                Action:
                  - sts:AssumeRole
              - Resource: '*'
                Effect: Allow
                Action:
                  - eks:Describe*
              - Resource: '*'
                Effect: Allow
                Action:
                  - logs:CreateLogGroup
                  - logs:CreateLogStream
                  - logs:PutLogEvents
              - Resource: '*'
                Effect: Allow
                Action:
                  - ecr:GetAuthorizationToken
              - Resource: '*'
                Effect: Allow
                Action:
                  - ec2:CreateNetworkInterface
                  - ec2:DescribeDhcpOptions
                  - ec2:DescribeNetworkInterfaces
                  - ec2:DeleteNetworkInterface
                  - ec2:DescribeSubnets
                  - ec2:DescribeSecurityGroups
                  - ec2:DescribeVpcs
                  - ec2:CreateNetworkInterfacePermission
              - Resource: !Sub arn:aws:s3:::${CodePipelineArtifactBucket}/*
                Effect: Allow
                Action:
                  - s3:GetObject
                  - s3:PutObject
                  - s3:GetObjectVersion
              - Resource: !Sub arn:aws:ecr:${AWS::Region}:${AWS::AccountId}:repository/${EcrDockerRepository}
                Effect: Allow
                Action:
                  - ecr:GetDownloadUrlForLayer
                  - ecr:BatchGetImage
                  - ecr:BatchCheckLayerAvailability
                  - ecr:PutImage
                  - ecr:InitiateLayerUpload
                  - ecr:UploadLayerPart
                  - ecr:CompleteLayerUpload

  CodeBuildProject:
    Type: AWS::CodeBuild::Project
    Properties:
      Artifacts:
        Type: CODEPIPELINE
      Source:
        Type: CODEPIPELINE
      Environment:
        ComputeType: BUILD_GENERAL1_SMALL
        Type: LINUX_CONTAINER
        Image: !Ref CodeBuildDockerImage
        EnvironmentVariables:
          - Name: REPOSITORY_URI
            Value: !Sub ${AWS::AccountId}.dkr.ecr.${AWS::Region}.amazonaws.com/${EcrDockerRepository}
          - Name: REPOSITORY_NAME
            Value: !Ref GitSourceRepo
          - Name: REPOSITORY_BRANCH
            Value: !Ref GitBranch
          - Name: EKS_CLUSTER_NAME
            Value: !Ref EksClusterName
          - Name: EKS_KUBECTL_ROLE_ARN
            Value: !Sub arn:aws:iam::${AWS::AccountId}:role/${KubectlRoleName}
          - Name: PRE_SCAN_REPOSITORY
            Value: !Ref PreregistryHost
          - Name: PRE_SCAN_USER
            Value: !Ref PreregistryUser
          - Name: PRE_SCAN_PWD
            Value: !Ref PreregistryPwd
          - Name: SMARTCHECK_HOST
            Value: !Ref SmartcheckHost
          - Name: SMARTCHECK_USER
            Value: !Ref SmartcheckUser
          - Name: SMARTCHECK_PWD
            Value: !Ref SmartcheckPwd
      Name: !Ref AWS::StackName
      ServiceRole: !GetAtt CodeBuildServiceRole.Arn

  CodePipelineGitHub:
    Type: AWS::CodePipeline::Pipeline
    Properties:
      RoleArn: !GetAtt CodePipelineServiceRole.Arn
      ArtifactStore:
        Type: S3
        Location: !Ref CodePipelineArtifactBucket
      Stages:
        - Name: Source
          Actions:
            - Name: App
              ActionTypeId:
                Category: Source
                Owner: ThirdParty
                Version: 1
                Provider: GitHub
              Configuration:
                Owner: !Ref GitHubUser
                Repo: !Ref GitSourceRepo
                Branch: !Ref GitBranch
                OAuthToken: !Ref GitHubToken
              OutputArtifacts:
                - Name: App
              RunOrder: 1
        - Name: Build
          Actions:
            - Name: Build
              ActionTypeId:
                Category: Build
                Owner: AWS
                Version: 1
                Provider: CodeBuild
              Configuration:
                ProjectName: !Ref CodeBuildProject
              InputArtifacts:
                - Name: App
              OutputArtifacts:
                - Name: BuildOutput
              RunOrder: 1
    DependsOn: CodeBuildProject
```

## *BuildSpec.yml*

```yaml
---
version: 0.2
phases:
  install:
    commands:
      - curl -sS -o aws-iam-authenticator https://amazon-eks.s3-us-west-2.amazonaws.com/1.10.3/2018-07-26/bin/linux/amd64/aws-iam-authenticator
      - curl -sS -o kubectl https://amazon-eks.s3-us-west-2.amazonaws.com/1.14.6/2019-08-22/bin/linux/amd64/kubectl
      - chmod +x ./kubectl ./aws-iam-authenticator
      - export PATH=$PWD/:$PATH
      - apt-get update && apt-get -y install jq python3-pip python3-dev && pip3 install --upgrade awscli
      #
      # If using not publicly trusted certificates:
      #
      # - export PRE_SCAN_REPOSITORY_CLEAN=$(echo $PRE_SCAN_REPOSITORY | sed -e 's|^[^/]*//||' -e 's/[/:].*$//')
      # - openssl s_client -showcerts -connect $PRE_SCAN_REPOSITORY_CLEAN:443 < /dev/null | sed -ne '/-BEGIN CERTIFICATE-/,/-END CERTIFICATE-/p' > smcert.crt
      # - cp smcert.crt /usr/local/share/ca-certificates/$PRE_SCAN_REPOSITORY.crt
      # - update-ca-certificates
  pre_build:
      commands:
        # - TAG="$REPOSITORY_NAME.$REPOSITORY_BRANCH.$ENVIRONMENT_NAME.$(date +%Y-%m-%d.%H.%M.%S).$(echo $CODEBUILD_RESOLVED_SOURCE_VERSION | head -c 8)"
        - TAG="latest"
        - sed -i 's@CONTAINER_IMAGE@'"$REPOSITORY_URI:$TAG"'@' app-eks.yml
        - $(aws ecr get-login --no-include-email)
        - export KUBECONFIG=$HOME/.kube/config
  build:
    commands:
      - docker build --tag $REPOSITORY_URI:$TAG .

  post_build:
    commands:
      # Smart Check Pre-Registry-Scan
      - >-
        docker run -v /var/run/docker.sock:/var/run/docker.sock
        deepsecurity/smartcheck-scan-action
        --image-name "$REPOSITORY_URI:$TAG"
        --findings-threshold "{\"malware\":0,\"vulnerabilities\":{\"defcon1\":0,\"critical\":0,\"high\":1},\"contents\":{\"defcon1\":0,\"critical\":1,\"high\":1},\"checklists\":{\"defcon1\":0,\"critical\":0,\"high\":0}}"
        --preregistry-host="$PRE_SCAN_REPOSITORY"
        --smartcheck-host="$SMARTCHECK_HOST"
        --smartcheck-user="$SMARTCHECK_USER"
        --smartcheck-password="$SMARTCHECK_PWD"
        --insecure-skip-tls-verify
        --preregistry-scan
        --preregistry-user "$PRE_SCAN_USER"
        --preregistry-password "$PRE_SCAN_PWD"

      # Push to ECR
      - docker push $REPOSITORY_URI:$TAG

      # Deploy to EKS
      - CREDENTIALS=$(aws sts assume-role --role-arn $EKS_KUBECTL_ROLE_ARN --role-session-name codebuild-kubectl --duration-seconds 900)
      - export AWS_ACCESS_KEY_ID="$(echo ${CREDENTIALS} | jq -r '.Credentials.AccessKeyId')"
      - export AWS_SECRET_ACCESS_KEY="$(echo ${CREDENTIALS} | jq -r '.Credentials.SecretAccessKey')"
      - export AWS_SESSION_TOKEN="$(echo ${CREDENTIALS} | jq -r '.Credentials.SessionToken')"
      - export AWS_EXPIRATION=$(echo ${CREDENTIALS} | jq -r '.Credentials.Expiration')
      - aws eks update-kubeconfig --name $EKS_CLUSTER_NAME
      - kubectl apply -f app-eks.yml
      - printf '[{"name":"troopers","imageUri":"%s"}]' $REPOSITORY_URI:$TAG > build.json
artifacts:
  files: build.json
```
