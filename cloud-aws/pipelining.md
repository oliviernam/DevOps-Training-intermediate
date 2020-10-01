# CI/CD with AWS CodePipeline

- [CI/CD with AWS CodePipeline](#cicd-with-aws-codepipeline)
  - [Prerequisites](#prerequisites)
  - [Create a Workspace](#create-a-workspace)
    - [Install Kubernetes tools](#install-kubernetes-tools)
    - [Update IAM Settings for the Workspace](#update-iam-settings-for-the-workspace)
    - [Create an IAM Role for the Workspace](#create-an-iam-role-for-the-workspace)
      - [UI-Path (for the chapter above)](#ui-path-for-the-chapter-above)
    - [Attach the IAM Role to the Workspace](#attach-the-iam-role-to-the-workspace)
      - [UI-Path (for the chapter above)](#ui-path-for-the-chapter-above-1)
    - [Validate the IAM role](#validate-the-iam-role)
  - [Create an Elastic Kubernetes Services Cluster](#create-an-elastic-kubernetes-services-cluster)
    - [Create an SSH key for Worker Access](#create-an-ssh-key-for-worker-access)
    - [Create an AWS KMS Custom Managed Key (CMK) for Secrets Encryption](#create-an-aws-kms-custom-managed-key-cmk-for-secrets-encryption)
    - [Install EKS tools and Helm (if not using the Multi Cloud Shell)](#install-eks-tools-and-helm-if-not-using-the-multi-cloud-shell)
    - [Launch an EKS cluster](#launch-an-eks-cluster)
  - [Deploy Smart Check](#deploy-smart-check)
  - [CI/CD with CodePipeline](#cicd-with-codepipeline)
    - [Create IAM Role for EKS](#create-iam-role-for-eks)
    - [Modify AWS-Auth ConfigMap](#modify-aws-auth-configmap)
    - [Fork Sample Repository](#fork-sample-repository)
    - [Populate the CodeCommit Repository](#populate-the-codecommit-repository)
    - [CodePipeline Setup](#codepipeline-setup)
    - [Create the Buildspec](#create-the-buildspec)
    - [Create Kubernetes Deployment and Service Definition](#create-kubernetes-deployment-and-service-definition)
  - [Appendix](#appendix)
    - [Delete an EKS Cluster](#delete-an-eks-cluster)
    - [hash -r](#hash--r)

## Prerequisites

- A GitHub account, where you can create a repository. If you don't have one, you can create one for free.
- An AWS account
- A CloudOne Application Security Account

## Create a Workspace

- Select Create Cloud9 environment
- Name it somehow like `ekscluster` (at least have the word ekscluster within the name)
- Choose “t3.small” for instance type and
- Amazon Linux as the platform.
- For the rest take all default values and click Create environment
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

### Update IAM Settings for the Workspace

- Click the gear icon (in top right corner), or click to open a new tab and choose “Open Preferences”
- Select AWS SETTINGS
- Turn off AWS managed temporary credentials
- Close the Preferences tab

We should configure our aws cli with our aws credentials and current region as default.

```shell
aws configure
```

```shell
AWS Access Key ID [****************....]: <KEY>
AWS Secret Access Key [****************....]: <SECRET>
Default region name [eu-central-1]: 
Default output format [None]: json
```

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

### Create an IAM Role for the Workspace

Next, we define some names:

```shell
export ROLE_NAME=ekscluster-admin
export INSTANCE_PROFILE_NAME=${ROLE_NAME}
```

```shell
# Create the policy for EC2 access
EC2_TRUST="{
  \"Version\": \"2012-10-17\",
  \"Statement\": [
    {
      \"Effect\": \"Allow\",
      \"Principal\": {
        \"Service\": \"ec2.amazonaws.com\"
      },
      \"Action\": \"sts:AssumeRole\"
    }
  ]
}"

aws iam create-role --role-name ${ROLE_NAME} --assume-role-policy-document "${EC2_TRUST}" --output text --query 'Role.Arn'
aws iam attach-role-policy --role-name ${ROLE_NAME} --policy-arn "arn:aws:iam::aws:policy/AdministratorAccess"
aws iam create-instance-profile --instance-profile-name ${INSTANCE_PROFILE_NAME}
aws iam add-role-to-instance-profile --role-name ${ROLE_NAME} --instance-profile-name ${INSTANCE_PROFILE_NAME}
```

#### UI-Path (for the chapter above)

- Follow this deep link to create an IAM role with Administrator access.
<https://console.aws.amazon.com/iam/home#/roles$new?step=review&commonUseCase=EC2%2BEC2&selectedUseCase=EC2&policies=arn:aws:iam::aws:policy%2FAdministratorAccess>

- Confirm that AWS service and EC2 are selected, then click Next to view permissions.
- Confirm that AdministratorAccess is checked, then click Next: Tags to assign tags.
- Take the defaults, and click Next: Review to review.
- Enter ekscluster-admin for the Name, and click Create role.

### Attach the IAM Role to the Workspace

Which the following commands, we grant our Cloud9 instance the priviliges to manage an EKS cluster.

```shell
# Query the instance ID of our Cloud9 environment
INSTANCE_ID=$(aws ec2 describe-instances --filters 'Name=tag:Name,Values=*ekscluster*' --query 'Reservations[*].Instances[*].{Instance:InstanceId}' | jq -r '.[0][0].Instance')

# Attach the IAM role to an existing EC2 instance
aws ec2 associate-iam-instance-profile --instance-id ${INSTANCE_ID} --iam-instance-profile Name=${INSTANCE_PROFILE_NAME}
```

If you run in an error here like `An error occurred (IncorrectInstanceState) when calling the AssociateIamInstanceProfile operation: The instance 'i-03ccd0e9c911d8d2a' is not in the 'running' or 'stopped' states.` you either have another ec2 instance with a name containing ekscluster or you're running into a conflict because you are working in a shared account.

To solve this problem, check the instance ID of your active Cloud9 instance in EC2 and assign it manually to the variable INSTANCE_ID. Then attach the role to the instance.

```shell
# Query the instance ID of our Cloud9 environment
INSTANCE_ID=<THE INSTANCE ID OF YOUR CLOUD9>

# Attach the IAM role to an existing EC2 instance
aws ec2 associate-iam-instance-profile --instance-id ${INSTANCE_ID} --iam-instance-profile Name=${INSTANCE_PROFILE_NAME}
```

#### UI-Path (for the chapter above)

- Follow this deep link to find your Cloud9 EC2 instance
<https://console.aws.amazon.com/ec2/v2/home?#Instances:tag:Name=aws-cloud9-.*ekscluster.*;sort=desc:launchTime>

- Select the instance, then choose Actions / Instance Settings / Attach/Replace IAM Rolec9instancerole
- Choose ekscluster-admin from the IAM Role drop down, and select Apply

### Validate the IAM role

To ensure temporary credentials aren’t already in place we will also remove any existing credentials file:

```shell
rm -vf ${HOME}/.aws/credentials
```

Use the GetCallerIdentity CLI command to validate that the Cloud9 IDE is using the correct IAM role.

```shell
aws sts get-caller-identity --query Arn | grep ekscluster-admin -q && echo "IAM role valid" || echo "IAM role NOT valid"
```

Note: A single `aws sts get-caller-identity --query Arn` should return something similar to this:

```shell
{
    "Account": "123456789012",
    "UserId": "AROA1SAMPLEAWSIAMROLE:i-01234567890abcdef",
    "Arn": "arn:aws:sts::123456789012:assumed-role/ekscluster-admin/i-01234567890abcdef"
}
```

## Create an Elastic Kubernetes Services Cluster

### Create an SSH key for Worker Access

Please run this command to generate SSH Key in Cloud9. This key will be used on the worker node instances to allow ssh access if necessary.

```shell
ssh-keygen -q -f ~/.ssh/id_rsa -P ""
```

Upload the public key to your EC2 region:

```shell
aws ec2 import-key-pair --key-name "ekscluster" --public-key-material file://~/.ssh/id_rsa.pub
```

If you got an error similar to An error occurred (InvalidKey.Format) when calling the ImportKeyPair operation: Key is not in valid OpenSSH public key format then you can try this command instead:

```shell
aws ec2 import-key-pair --key-name "ekscluster" --public-key-material fileb://~/.ssh/id_rsa.pub
```

### Create an AWS KMS Custom Managed Key (CMK) for Secrets Encryption

Create a CMK for the EKS cluster to use when encrypting your Kubernetes secrets:

```shell
KEY_ALIAS_NAME="alias/ekscluster"
aws kms create-alias --alias-name ${KEY_ALIAS_NAME} --target-key-id $(aws kms create-key --query KeyMetadata.Arn --output text)
```

Let’s retrieve the ARN of the CMK to input into the create cluster command.

```shell
export MASTER_ARN=$(aws kms describe-key --key-id ${KEY_ALIAS_NAME} --query KeyMetadata.Arn --output text)
```

We set the MASTER_ARN environment variable to make it easier to refer to the KMS key later.

Now, let’s save the MASTER_ARN environment variable into the bash_profile

```shell
echo "export MASTER_ARN=${MASTER_ARN}" | tee -a ~/.bash_profile
```

### Install EKS tools and Helm (if not using the Multi Cloud Shell)

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

Create an eksctl deployment file (ekscluster.yaml) use in creating your cluster using the following syntax:

```shell
export CLUSTER_NAME=ekscluster-eksctl

cat << EOF > ekscluster.yaml
---
apiVersion: eksctl.io/v1alpha5
kind: ClusterConfig

metadata:
  name: ${CLUSTER_NAME}
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

```shell
ip-192-168-30-233.eu-central-1.compute.internal   Ready    <none>   3m39s   v1.17.9-eks-4c6976
ip-192-168-56-29.eu-central-1.compute.internal    Ready    <none>   3m46s   v1.17.9-eks-4c6976
ip-192-168-66-142.eu-central-1.compute.internal   Ready    <none>   3m45s   v1.17.9-eks-4c6976
```

## Deploy Smart Check

Define some variables

```shell
export DSSC_NAMESPACE='smartcheck'
export DSSC_USERNAME='administrator'
export DSSC_PASSWORD='trendmicro'
export DSSC_REGUSER='administrator'
export DSSC_REGPASSWORD='trendmicro'
```

Set the activation code for Smart Check

```shell
export DSSC_AC=<SMART CHECK ACTIVATION CODE>
```

Finally, run

```shell
export DNS_NAME="*.${AWS_REGION}.elb.amazonaws.com" && \
  curl -sSL https://raw.githubusercontent.com/mawinkler/devops-training/master/cloudone-smart-check/deploy-dns.sh | bash
export DSSC_HOST=$(kubectl get svc -n ${DSSC_NAMESPACE} proxy -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
```

or

```shell
export DNS_NAME="*.${AWS_REGION}.elb.amazonaws.com" && \
  curl -sSL https://raw.githubusercontent.com/mawinkler/deploy/master/deploy-dns.sh | bash
export DSSC_HOST=$(kubectl get svc -n ${DSSC_NAMESPACE} proxy -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
```

## CI/CD with CodePipeline

### Create IAM Role for EKS

In an AWS CodePipeline, we are going to use AWS CodeBuild to deploy a Kubernetes service. This requires an AWS Identity and Access Management (IAM) role capable of interacting with the EKS cluster.

In this step, we are going to create an IAM role and add an inline policy that we will use in the CodeBuild stage to interact with the EKS cluster via kubectl.

Create the role:

```shell
export CODEBUILD_ROLE_NAME=ekscluster-codebuild
TRUST="{
  \"Version\": \"2012-10-17\",
  \"Statement\": [ 
    {
      \"Effect\": \"Allow\",
      \"Principal\": { \"AWS\": \"arn:aws:iam::${ACCOUNT_ID}:root\" }, \"Action\": \"sts:AssumeRole\"
    }
  ]
}"

cat <<EOF > /tmp/iam-role-policy.json
{ "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "eks:Describe*", "Resource": "*"
    }
  ]
}
EOF

aws iam create-role --role-name ${CODEBUILD_ROLE_NAME} --assume-role-policy-document "$TRUST" --output text --query 'Role.Arn'
aws iam put-role-policy --role-name ${CODEBUILD_ROLE_NAME} --policy-name eks-describe --policy-document file:///tmp/iam-role-policy.json
```

### Modify AWS-Auth ConfigMap

Now that we have the IAM role created, we are going to add the role to the aws-auth ConfigMap for the EKS cluster.

Once the ConfigMap includes this new role, kubectl in the CodeBuild stage of the pipeline will be able to interact with the EKS cluster via the IAM role.

```shell
ROLE="    - rolearn: arn:aws:iam::${ACCOUNT_ID}:role/${CODEBUILD_ROLE_NAME}\n      username: build\n      groups:\n        - system:masters"
kubectl get -n kube-system configmap/aws-auth -o yaml | awk "/mapRoles: \|/{print;print \"$ROLE\";next}1" > /tmp/aws-auth-patch.yml
kubectl patch configmap/aws-auth -n kube-system --patch "$(cat /tmp/aws-auth-patch.yml)"
```

### Fork Sample Repository

We are now going to fork the sample Kubernetes service so that we will be able modify the repository and trigger builds. If you already forked the repo because of another lab you did before, there's no need to do it again. In that case, simply continue with cloning it to your  shell.

Login to GitHub and fork the Uploaders app:

<https://github.com/mawinkler/c1-app-sec-uploader>

### Populate the CodeCommit Repository

A remote URL is Git's fancy way of saying "the place where your code is stored." That URL could be your repository on GitHub, or another user's fork, or even on a completely different server.

Git associates a remote URL with a name, and your default remote is usually called origin.

Here, we're adding a remote repository in AWS CodeCommit which our pipeline will use.

```shell
export APP_NAME=c1-app-sec-uploader
git clone https://github.com/<YOUR GITHUB HANDLE>/${APP_NAME}.git
cd ${APP_NAME}
git init
git remote add aws https://git-codecommit.${AWS_REGION}.amazonaws.com/v1/repos/${APP_NAME}
```

Set the username and email address for your Git commits. Replace [EMAIL_ADDRESS] with your Git email address. Replace [USERNAME] with your Git username.

```shell
git config --global user.email "[EMAIL_ADDRESS]"
git config --global user.name "[USERNAME]"
```

### CodePipeline Setup

Each EKS deployment/service should have its own CodePipeline and be located in an isolated source repository.

Now we are going to create the AWS CodePipeline using AWS CloudFormation.

Still in our source directory, download and review the stack definition. Just look, do not change anything now.

```shell
curl -sSL https://raw.githubusercontent.com/mawinkler/devops-training/master/cloud-aws/snippets/${APP_NAME}-pipeline.cfn.yml --output ${APP_NAME}-pipeline.cfn.yml

# or

curl -sSL https://raw.githubusercontent.com/mawinkler/deploy/master/${APP_NAME}-pipeline.cfn.yml --output ${APP_NAME}-pipeline.cfn.yml
```

You will realize a couple of chapters. First are the `Parameters` for the pipeline, which you can either leave with the defaults or customize.

The more interesting part is the `Resources` chapter, which defines all used resources for our pipeline. In our case this includes ECR, S3, CodeBuild, CodePipeline, CodeCommit, ServiceRoles, Smart Check.

Ok, now let's populate the paramenters, but set your Application Security credentials first:

```shell
export TREND_AP_KEY=<YOUR CLOUD ONE APPLICATION SECURITY KEY>
export TREND_AP_SECRET=<YOUR CLOUD ONE APPLICATION SECURITY SECRET>
```

Do the parameter expansion.

```shell
export DSSC_HOST=$(kubectl get svc -n ${DSSC_NAMESPACE} proxy -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
export CLUSTER_NAME=$(eksctl get cluster -o json | jq -r '.[].name')
export IMAGE_NAME=${APP_NAME}
export IMAGE_TAG=latest

eval "cat <<EOF
$(<${APP_NAME}-pipeline.cfn.yml)
EOF
" 2> /dev/null > ${APP_NAME}-pipeline.cfn.yml
```

Validate the stack

```shell
aws cloudformation validate-template --template-body file://${APP_NAME}-pipeline.cfn.yml
```

If you get a nice JSON, create the stack

```shell
aws cloudformation deploy --stack-name ${APP_NAME}-pipeline --template-file ${APP_NAME}-pipeline.cfn.yml --capabilities CAPABILITY_IAM
```

### Create the Buildspec

Download and review the buildspec.yml, this is the effective definition of the pipeline.

```shell
curl -sSL https://raw.githubusercontent.com/mawinkler/devops-training/master/cloud-aws/snippets/buildspec.yml --output buildspec.yml

# or

curl -sSL https://raw.githubusercontent.com/mawinkler/deploy/master/buildspec.yml --output buildspec.yml
```

Review the build specification and identify what's happening in the different phases.

Can you identify the environment in which the different phases are executed?

### Create Kubernetes Deployment and Service Definition

Download and review the app-eks.yml, this is the deployment manifest for kubernetes.

```shell
curl -sSL https://raw.githubusercontent.com/mawinkler/devops-training/master/cloud-aws/snippets/app-eks.yml --output app-eks.yml

# or

curl -sSL https://raw.githubusercontent.com/mawinkler/deploy/master/app-eks.yml --output app-eks.yml
```

Review the deployment manifest. What are going to apply to our cluster?

Then, do the parameter expansion.

```shell
eval "cat <<EOF
$(<app-eks.yml)
EOF
" 2> /dev/null > app-eks.yml
```

And finally add all the files and folders recursively to the CodeCommit Repository.

```shell
git add .
git commit -m "Initial commit"
git push aws master
```

The last command should trigger the pipeline. Open this link in your browser to see the action happening: <https://console.aws.amazon.com/codesuite/codepipeline/home>

Whenever you change something in the CodeCommit repo, the pipeline will rerun.

If the pipeline did sucessfully finish, you can retrieve the URL for our music uploader with the following command:

```shell
kubectl get svc -n default ${APP_NAME} -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

Done. So, let's upload some music files :-)

## Appendix

### Delete an EKS Cluster

List all services running in your cluster.

```shell
kubectl get svc --all-namespaces
```

Delete any services that have an associated EXTERNAL-IP value. These services are fronted by an Elastic Load Balancing load balancer, and you must delete them in Kubernetes to allow the load balancer and associated resources to be properly released.

```shell
kubectl delete svc service-name
```

Now

Delete the cluster and its associated worker nodes.

```shell
eksctl delete cluster --name `eksctl get cluster -o json | jq -r '.[].name'`
```

### hash -r

hash [-lr] [-p filename] [-dt] [name]
              Each  time  hash  is  invoked,  the  full pathname of the command name is determined by searching the directories in $PATH and remembered.  Any previously-remembered pathname is discarded.  If the -p
              option is supplied, no path search is performed, and filename is used as the full file name of the command.  The -r option causes the shell to forget all remembered locations.  The -d  option  causes
              the shell to forget the remembered location of each name.  If the -t option is supplied, the full pathname to which each name corresponds is printed.  If multiple name arguments are supplied with -t,
              the name is printed before the hashed full pathname.  The -l option causes output to be displayed in a format that may be reused as input.  If no arguments are given,  or  if  only  -l  is  supplied,
              information about remembered commands is printed.  The return status is true unless a name is not found or an invalid option is supplied.