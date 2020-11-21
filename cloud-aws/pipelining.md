# CI/CD with AWS CodePipeline

- [CI/CD with AWS CodePipeline](#cicd-with-aws-codepipeline)
  - [Prerequisites](#prerequisites)
  - [Good to Know](#good-to-know)
  - [Create a Workspace - Cloud9](#create-a-workspace---cloud9)
    - [Install Kubernetes tools](#install-kubernetes-tools)
    - [Update IAM Settings for the Workspace](#update-iam-settings-for-the-workspace)
    - [Create an IAM Role for the Workspace](#create-an-iam-role-for-the-workspace)
    - [Attach the IAM Role to the Workspace](#attach-the-iam-role-to-the-workspace)
    - [Validate the IAM role](#validate-the-iam-role)
  - [Create a Workspace - Multi Cloud Shell](#create-a-workspace---multi-cloud-shell)
  - [Create an Elastic Kubernetes Services Cluster](#create-an-elastic-kubernetes-services-cluster)
    - [Create an SSH key for Worker Access](#create-an-ssh-key-for-worker-access)
    - [Create an AWS KMS Custom Managed Key (CMK) for Secrets Encryption](#create-an-aws-kms-custom-managed-key-cmk-for-secrets-encryption)
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
    - [Enable persistence for the environment variables when using Multi Cloud Shell](#enable-persistence-for-the-environment-variables-when-using-multi-cloud-shell)
    - [Clean-Up your Environment](#clean-up-your-environment)
    - [Delete an EKS Cluster](#delete-an-eks-cluster)
    - [hash -r](#hash--r)

## Prerequisites

- A GitHub account, where you can create a repository. If you don't have one, you can create one for free.
- An AWS account
- A CloudOne Application Security Account

## Good to Know

It is **BAD** practice to store your AWS Access Key and Secret Access Key anywhere within an EC2 instance. You really should never ever do that!

The **GOOD** way is to have an IAM role and attach it to the EC2 instance. IAM roles can come with a policy authorizing exactly what the EC2 instance should be able to do. EC2 instances can then use these profiles automatically without any additional configurations.

*This is the best practice on AWS.*

Basic steps:

- IAM --> Create Role
  - First, you need to choose the service that will use this role. In the case of an EC2 instance, this is obviously EC2
  - Search for a fitting policy (e.g. AmazonS3ReadOnlyAccess)
  - Name the role meaningful (e.g. EC2-S3ReadOnlyAccess)
  - Use the default description or set your own (e.g. Allows EC2 to make calls to S3)
- Attach the above created role to your EC2 instance

An EC2 instance can only have one IAM role attached, but an IAM role can be attached to multiple instances, of course. The role enables the instance to make API calls within the given permissions on your behalf.

If you want to create a policy manually, you can ease you life by the [AWS Policy Generator](https://awspolicygen.s3.amazonaws.com/policygen.html) here. Another online tool on this topic is the [IAM Policy Simulator](https://policysim.aws.amazon.com).

**To run through the lab, you can choose to do it within a Cloud9 environment on AWS or using (the kind of experimental) `Multi Cloud Shell`. So either continue with the next chapter or jump to [Create a Workspace - Multi Cloud Shell](#create-a-workspace---multi-cloud-shell)**

## Create a Workspace - Cloud9

- Select Create Cloud9 environment
- Name it somehow like `ekscluster` (at least have the word ekscluster within the name)
- Choose “t3.small” for instance type and
- Amazon Linux 2 as the platform.
- For the rest take all default values and click Create environment
- When it comes up, customize the environment by closing the welcome tab and lower work area, and opening a new terminal tab in the main work area.

### Install Kubernetes tools

We start with kubectl and awscli

```sh
sudo curl --silent --location -o /usr/local/bin/kubectl https://amazon-eks.s3.us-west-2.amazonaws.com/1.17.9/2020-08-04/bin/linux/amd64/kubectl
sudo chmod +x /usr/local/bin/kubectl
```

Update awscli

```sh
sudo pip install --upgrade awscli && hash -r
```

Install jq, envsubst (from GNU gettext utilities) and bash-completion

```sh
sudo yum -y install jq gettext bash-completion
```

Verify the binaries are in the path and executable

```sh
for command in kubectl jq envsubst aws
  do
    which $command &>/dev/null && echo "$command in path" || echo "$command NOT FOUND"
  done
```

Enable kubectl bash_completion

```sh
kubectl completion bash >>  ~/.bash_completion
. /etc/profile.d/bash_completion.sh
. ~/.bash_completion
```

Now, we need to download the eksctl binary:

```sh
curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp

sudo mv -v /tmp/eksctl /usr/local/bin
```

Confirm the eksctl command works:

```sh
eksctl version
```

Enable eksctl bash-completion

```sh
eksctl completion bash >> ~/.bash_completion
. /etc/profile.d/bash_completion.sh
. ~/.bash_completion
```

Finally, we need to install Helm:

```sh
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3
chmod +x get_helm.sh
./get_helm.sh
```

And confirm that helm works:

```sh
helm version
```

### Update IAM Settings for the Workspace

- Click the gear icon (in top right corner), or click to open a new tab and choose “Open Preferences”
- Select AWS SETTINGS
- Turn off AWS managed temporary credentials
- Close the Preferences tab

To create an IAM role which we want to attach to our cloud9 instance, we need temporary administrative privileges in our current shell. To get these, we need to configure our aws cli with our aws credentials and the current region. Directly after assigning the created role to the instance, we're removing the credentials from the environment, of course.

```sh
aws configure
```

```sh
AWS Access Key ID [****************....]: <KEY>
AWS Secret Access Key [****************....]: <SECRET>
Default region name [eu-central-1]:
Default output format [None]: json
```

```sh
export ACCOUNT_ID=$(aws sts get-caller-identity --output text --query Account)
export AWS_REGION=$(curl -s 169.254.169.254/latest/dynamic/instance-identity/document | jq -r '.region')
```

Check if AWS_REGION is set to desired region. The above curl to 169.254.269.254 points to an AWS internal url allowing an EC2 instance to query some information about itself without requiring a role for this. Feel free to play with it

```sh
test -n "$AWS_REGION" && echo AWS_REGION is "$AWS_REGION" || echo AWS_REGION is not set
```

Let’s save these into bash_profile

```sh
echo "export ACCOUNT_ID=${ACCOUNT_ID}" | tee -a ~/.bash_profile
echo "export AWS_REGION=${AWS_REGION}" | tee -a ~/.bash_profile
aws configure set default.region ${AWS_REGION}
aws configure get default.region
```

### Create an IAM Role for the Workspace

Next, we define some names:

```sh
export ROLE_NAME=ekscluster-admin
export INSTANCE_PROFILE_NAME=${ROLE_NAME}
```

Execute the following including the variable assignment:

```sh
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

### Attach the IAM Role to the Workspace

Which the following commands, we grant our Cloud9 instance the priviliges to manage an EKS cluster.

```sh
# Query the instance ID of our Cloud9 environment
INSTANCE_ID=$(aws ec2 describe-instances --filters 'Name=tag:Name,Values=*ekscluster*' --query 'Reservations[*].Instances[*].{Instance:InstanceId}' | jq -r '.[0][0].Instance')

# Attach the IAM role to an existing EC2 instance
aws ec2 associate-iam-instance-profile --instance-id ${INSTANCE_ID} --iam-instance-profile Name=${INSTANCE_PROFILE_NAME}
```

If you run in an error here like `An error occurred (IncorrectInstanceState) when calling the AssociateIamInstanceProfile operation: The instance 'i-03ccd0e9c911d8d2a' is not in the 'running' or 'stopped' states.` you either have another ec2 instance with a name containing ekscluster or you're running into a conflict because you are working in a shared account.

To solve this problem, check the instance ID of your active Cloud9 instance in EC2 and assign it manually to the variable INSTANCE_ID. Then attach the role to the instance.

```sh
# Query the instance ID of our Cloud9 environment
INSTANCE_ID=<THE INSTANCE ID OF YOUR CLOUD9>

# Attach the IAM role to an existing EC2 instance
aws ec2 associate-iam-instance-profile --instance-id ${INSTANCE_ID} --iam-instance-profile Name=${INSTANCE_PROFILE_NAME}
```

### Validate the IAM role

To ensure temporary credentials aren’t already in place we will also remove any existing credentials file:

```sh
rm -vf ${HOME}/.aws/credentials
```

Use the GetCallerIdentity CLI command to validate that the Cloud9 IDE is using the correct IAM role.

```sh
aws sts get-caller-identity --query Arn | grep ekscluster-admin -q && echo "IAM role valid" || echo "IAM role NOT valid"
```

Note: A single `aws sts get-caller-identity --query Arn` should return something similar to this:

```sh
{
    "Account": "123456789012",
    "UserId": "AROA1SAMPLEAWSIAMROLE:i-01234567890abcdef",
    "Arn": "arn:aws:sts::123456789012:assumed-role/ekscluster-admin/i-01234567890abcdef"
}
```

**Now, your workspace on Cloud9 should be functional. To continue [Create an Elastic Kubernetes Services Cluster](#create-an-elastic-kubernetes-services-cluster)**

## Create a Workspace - Multi Cloud Shell

We should configure our aws cli with our aws credentials and current region as default.

```sh
aws configure
```

```sh
AWS Access Key ID [****************....]: <KEY>
AWS Secret Access Key [****************....]: <SECRET>
Default region name [eu-central-1]: 
Default output format [None]: json
```

```sh
export ACCOUNT_ID=$(aws sts get-caller-identity --output text --query Account)
export AWS_REGION=$(cat ~/.aws/config | sed -n 's/^region\s=\s\(.*\)/\1/p')
```

## Create an Elastic Kubernetes Services Cluster

### Create an SSH key for Worker Access

Please run this command to generate SSH Key in Cloud9. This key will be used on the worker node instances to allow ssh access if necessary.

```sh
ssh-keygen -q -f ~/.ssh/id_rsa -P ""
```

Upload the public key to your EC2 region:

```sh
aws ec2 import-key-pair --key-name "ekscluster" --public-key-material file://~/.ssh/id_rsa.pub
```

### Create an AWS KMS Custom Managed Key (CMK) for Secrets Encryption

Create a CMK for the EKS cluster to use when encrypting your Kubernetes secrets:

```sh
KEY_ALIAS_NAME="alias/ekscluster"
aws kms create-alias --alias-name ${KEY_ALIAS_NAME} --target-key-id $(aws kms create-key --query KeyMetadata.Arn --output text)
```

Let’s retrieve the ARN of the CMK to input into the create cluster command.

```sh
export MASTER_ARN=$(aws kms describe-key --key-id ${KEY_ALIAS_NAME} --query KeyMetadata.Arn --output text)
```

We set the MASTER_ARN environment variable to make it easier to refer to the KMS key later.

Now, let’s save the MASTER_ARN environment variable into the bash_profile

```sh
echo "export MASTER_ARN=${MASTER_ARN}" | tee -a ~/.bash_profile
```

### Launch an EKS cluster

Create an eksctl deployment file (ekscluster.yaml) use in creating your cluster using the following syntax:

```sh
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

```sh
eksctl create cluster -f ekscluster.yaml
```

Confirm your nodes:

```sh
kubectl get nodes # if we see our 3 nodes, we know we have authenticated correctly
```

```sh
ip-192-168-30-233.eu-central-1.compute.internal   Ready    <none>   3m39s   v1.17.9-eks-4c6976
ip-192-168-56-29.eu-central-1.compute.internal    Ready    <none>   3m46s   v1.17.9-eks-4c6976
ip-192-168-66-142.eu-central-1.compute.internal   Ready    <none>   3m45s   v1.17.9-eks-4c6976
```

## Deploy Smart Check

Define some variables

```sh
export DSSC_NAMESPACE='smartcheck'
export DSSC_USERNAME='administrator'
export DSSC_PASSWORD='trendmicro'
export DSSC_REGUSER='administrator'
export DSSC_REGPASSWORD='trendmicro'
```

Set the activation code for Smart Check

```sh
export DSSC_AC=<SMART CHECK ACTIVATION CODE>
```

Finally, run

```sh
rm -f pwchanged
export DNS_NAME="*.${AWS_REGION}.elb.amazonaws.com" && \
  curl -sSL https://gist.githubusercontent.com/mawinkler/68391667fdfe98d9294417f3a24d337b/raw | bash
export DSSC_HOST=$(kubectl get svc -n ${DSSC_NAMESPACE} proxy -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
```

## CI/CD with CodePipeline

### Create IAM Role for EKS

In an AWS CodePipeline, we are going to use AWS CodeBuild to deploy a Kubernetes service. This requires an AWS Identity and Access Management (IAM) role capable of interacting with the EKS cluster.

In this step, we are going to create an IAM role and add an inline policy that we will use in the CodeBuild stage to interact with the EKS cluster via kubectl.

Create the role:

```sh
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

```sh
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

```sh
export GITHUB_USERNAME="[YOUR GITHUB USERNAME]"
export APP_NAME=c1-app-sec-uploader
git clone https://github.com/${GITHUB_USERNAME}/${APP_NAME}.git
cd ${APP_NAME}
git init
git remote add aws https://git-codecommit.${AWS_REGION}.amazonaws.com/v1/repos/${APP_NAME}
```

Set the username and email address for your Git commits. Replace [EMAIL_ADDRESS] with your Git email address. Replace [USERNAME] with your name.

```sh
git config --global user.email "[EMAIL_ADDRESS]"
git config --global user.name "Jane Doe"
```

### CodePipeline Setup

Each EKS deployment/service should have its own CodePipeline and be located in an isolated source repository.

Now we are going to create the AWS CodePipeline using AWS CloudFormation.

Still in our source directory, download and review the stack definition. Just look, do not change anything now.

```sh
curl -sSL https://gist.githubusercontent.com/mawinkler/8f208b2fc73209bc99013f60dcc81679/raw --output ${APP_NAME}-pipeline.cfn.yml
```

You will realize a couple of chapters. First are the `Parameters` for the pipeline, which you can either leave with the defaults or customize.

The more interesting part is the `Resources` chapter, which defines all used resources for our pipeline. In our case this includes ECR, S3, CodeBuild, CodePipeline, CodeCommit, ServiceRoles, Smart Check.

Ok, now let's populate the paramenters, but set your Application Security credentials first:

```sh
export TREND_AP_KEY=<YOUR CLOUD ONE APPLICATION SECURITY KEY>
export TREND_AP_SECRET=<YOUR CLOUD ONE APPLICATION SECURITY SECRET>
```

Do the parameter expansion.

```sh
export DSSC_HOST=$(kubectl get svc -n ${DSSC_NAMESPACE} proxy -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
export CLUSTER_NAME=$(eksctl get cluster -o json | jq -r '.[].metadata.name')
export CODEBUILD_ROLE_NAME=ekscluster-codebuild
export IMAGE_NAME=${APP_NAME}
export IMAGE_TAG=latest

eval "cat <<EOF
$(<${APP_NAME}-pipeline.cfn.yml)
EOF
" 2> /dev/null > ${APP_NAME}-pipeline.cfn.yml
```

Validate the stack

```sh
aws cloudformation validate-template --template-body file://${APP_NAME}-pipeline.cfn.yml
```

If you get a nice JSON, create the stack

```sh
aws cloudformation deploy --stack-name ${APP_NAME}-pipeline --template-file ${APP_NAME}-pipeline.cfn.yml --capabilities CAPABILITY_IAM
```

### Create the Buildspec

Download and review the buildspec.yml, this is the effective definition of the pipeline.

```sh
curl -sSL https://gist.githubusercontent.com/mawinkler/f7d271ea2b821cfd29b53d6c950cac8a/raw --output buildspec.yml
```

Review the build specification and identify what's happening in the different phases.

Can you identify the environment in which the different phases are executed?

### Create Kubernetes Deployment and Service Definition

Download and review the app-eks.yml, this is the deployment manifest for kubernetes.

```sh
curl -sSL https://gist.githubusercontent.com/mawinkler/f553ada2dd083558befd484eeb7c8845/raw --output app-eks.yml
```

Review the deployment manifest. What are going to apply to our cluster?

Then, do the parameter expansion.

```sh
eval "cat <<EOF
$(<app-eks.yml)
EOF
" 2> /dev/null > app-eks.yml
```

Enable the credential helper for git to modify `~/.gitconfig`.

```sh
git config --global credential.helper '!aws codecommit credential-helper $@'
git config --global credential.UseHttpPath true
```

And finally add all the files and folders recursively to the CodeCommit Repository.

```sh
git add .
git commit -m "Initial commit"
git push aws master
```

The last command should trigger the pipeline. Open this link in your browser to see the action happening: <https://console.aws.amazon.com/codesuite/codepipeline/home>

Whenever you change something in the CodeCommit repo, the pipeline will rerun.

If the pipeline did sucessfully finish, you can retrieve the URL for our music uploader with the following command:

```sh
kubectl get svc -n default ${APP_NAME} -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

Done. So, let's upload some music files :-)

## Appendix

### Enable persistence for the environment variables when using Multi Cloud Shell

To make the defined environment variables persistent run

```sh
~/saveenv-aws.sh
```

before you shut down the container.

Restore with

```sh
. ~/.aws-lab.sh
```

### Clean-Up your Environment

Execute the following to remove the lab resources

```sh
kubectl delete svc ${APP_NAME}
helm -n ${DSSC_NAMESPACE} delete deepsecurity-smartcheck

eksctl delete cluster --name `eksctl get cluster -o json | jq -r '.[].name'`

aws ec2 delete-key-pair --key-name "ekscluster"
aws kms delete-alias --alias-name ${KEY_ALIAS_NAME}

export CODEBUILD_ROLE_NAME=ekscluster-codebuild
aws iam delete-role-policy --role-name ${CODEBUILD_ROLE_NAME} --policy-name eks-describe
aws iam delete-role --role-name ${CODEBUILD_ROLE_NAME}

aws ecr delete-repository --repository-name ${APP_NAME} --force

aws cloudformation delete-stack --stack-name ${APP_NAME}-pipeline
```

### Delete an EKS Cluster

List all services running in your cluster.

```sh
kubectl get svc --all-namespaces
```

Delete any services that have an associated EXTERNAL-IP value. These services are fronted by an Elastic Load Balancing load balancer, and you must delete them in Kubernetes to allow the load balancer and associated resources to be properly released.

```sh
kubectl delete svc service-name
```

Now

Delete the cluster and its associated worker nodes.

```sh
eksctl delete cluster --name `eksctl get cluster -o json | jq -r '.[].name'`
```

### hash -r

hash [-lr] [-p filename] [-dt] [name]
              Each  time  hash  is  invoked,  the  full pathname of the command name is determined by searching the directories in $PATH and remembered.  Any previously-remembered pathname is discarded.  If the -p
              option is supplied, no path search is performed, and filename is used as the full file name of the command.  The -r option causes the shell to forget all remembered locations.  The -d  option  causes
              the shell to forget the remembered location of each name.  If the -t option is supplied, the full pathname to which each name corresponds is printed.  If multiple name arguments are supplied with -t,
              the name is printed before the hashed full pathname.  The -l option causes output to be displayed in a format that may be reused as input.  If no arguments are given,  or  if  only  -l  is  supplied,
              information about remembered commands is printed.  The return status is true unless a name is not found or an invalid option is supplied.