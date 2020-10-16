# CI/CD with Azure Pipelines

- [CI/CD with Azure Pipelines](#cicd-with-azure-pipelines)
  - [Prerequisites](#prerequisites)
  - [Connect to Azure](#connect-to-azure)
    - [Azure Cloud Shell](#azure-cloud-shell)
    - [Multi Cloud Shell](#multi-cloud-shell)
    - [Create a Resource Group](#create-a-resource-group)
    - [Create a Container Registry](#create-a-container-registry)
    - [Create a Kubernetes Cluster](#create-a-kubernetes-cluster)
  - [Deploy Smart Check](#deploy-smart-check)
  - [Configure Cloud One Application Security](#configure-cloud-one-application-security)
  - [Build the Azure Pipeline](#build-the-azure-pipeline)
    - [Create a PAT](#create-a-pat)
    - [Create a project](#create-a-project)
    - [Fork Sample Repository](#fork-sample-repository)
    - [Populate the Azure Repository](#populate-the-azure-repository)
    - [Create the pipeline](#create-the-pipeline)
  - [Integrate Smart Check and Application Security into the pipeline](#integrate-smart-check-and-application-security-into-the-pipeline)
    - [Variable definitions for the pipeline](#variable-definitions-for-the-pipeline)
    - [Integrate Application Security in the deployment manifest](#integrate-application-security-in-the-deployment-manifest)
    - [Integrate Smart Check and Application Security into the pipeline definition](#integrate-smart-check-and-application-security-into-the-pipeline-definition)
  - [Learn more](#learn-more)
  - [Additional Resources](#additional-resources)
  - [Appendix](#appendix)
    - [Enable persistence for the environment variables when using Multi Cloud Shell](#enable-persistence-for-the-environment-variables-when-using-multi-cloud-shell)
    - [Example `manifests/deployment.yml`](#example-manifestsdeploymentyml)
    - [Example `manifests/service.yml`](#example-manifestsserviceyml)
    - [Example `azure-pipelines.yml`](#example-azure-pipelinesyml)
    - [Suspend Virtual Machines](#suspend-virtual-machines)
    - [Clean up resources](#clean-up-resources)
  - [Azure Commands](#azure-commands)

## Prerequisites

- A GitHub account, where you can create a repository. If you don't have one, you can create one for free.
- An Azure DevOps organization. If you don't have one, you can create one for free <https://docs.microsoft.com/en-us/azure/devops/pipelines/get-started/pipelines-sign-up?view=azure-devops>. (An Azure DevOps organization is different from your GitHub organization. Give them the same name if you want alignment between them)
- If your team already has one, then make sure you're an administrator of the Azure DevOps project that you want to use
- An Azure account
- A Cloud One Application Security Account

## Connect to Azure

You can either work via the Azure Cloud Shell or by using the Multi Cloud Shell Container.

### Azure Cloud Shell

Sign in to the Azure Portal <https://portal.azure.com/>, and then select the Cloud Shell button in the upper-right corner.

Info: <https://docs.microsoft.com/en-us/azure/cloud-shell/overview>

### Multi Cloud Shell

From within the `shell`-directory of the devops-training run

```sh
./build.sh
./start.sh
```

Now authtenticate to Azure via

```sh
az login
```

and follow the process.

### Create a Resource Group

```sh
export APP_NAME=c1-app-sec-uploader
az group create --name ${APP_NAME} --location westeurope
```

### Create a Container Registry

```sh
export APP_REGISTRY=c1appsecuploaderregistry$(openssl rand -hex 4)
az acr create --resource-group ${APP_NAME} --name ${APP_REGISTRY} --sku Basic
```

### Create a Kubernetes Cluster

```sh
export CLUSTER_NAME=appcluster
az aks create \
    --resource-group ${APP_NAME} \
    --name ${CLUSTER_NAME} \
    --node-count 2 \
    --enable-addons monitoring \
    --generate-ssh-keys
```

To configure kubectl to connect to your Kubernetes cluster, use the az aks get-credentials command. The following example gets credentials for the AKS cluster named appcluster in the ${APP_NAME} resource group:

```sh
az aks get-credentials --resource-group ${APP_NAME} --name ${CLUSTER_NAME}
```

To verify the connection to your cluster, run the kubectl get nodes command to return a list of the cluster nodes:

```sh
kubectl get nodes
```

```text
NAME                       STATUS   ROLES   AGE   VERSION
aks-nodepool1-30577774-vmss000000   Ready    agent   39m   v1.16.10
aks-nodepool1-30577774-vmss000001   Ready    agent   39m   v1.16.10
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
curl -sSL https://gist.githubusercontent.com/mawinkler/7b9cc48a8b2cf96e07e4eadd6e8e9497/raw/aa9361ee163e584874f1ced3f65a9d76c63214b0/deploy-ip.sh | bash
export DSSC_HOST_IP=$(kubectl get svc -n ${DSSC_NAMESPACE} proxy -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
export DSSC_HOST="smartcheck-${DSSC_HOST_IP//./-}.nip.io"
```

## Configure Cloud One Application Security

Define the Application Security Key and Secret.

```sh
export TREND_AP_KEY=<YOUR CLOUD ONE APPLICATION SECURITY KEY>
export TREND_AP_SECRET=<YOUR CLOUD ONE APPLICATION SECURITY SECRET>
```

## Build the Azure Pipeline

If you do not have an Azure DevOps Organization, sign in to Azure Pipelines <https://azure.microsoft.com/services/devops/pipelines>. After you sign in, your browser goes to <https://dev.azure.com/...> and displays your Azure DevOps dashboard.

If you already own an Azure DevOps Organization, go to <https://aex.dev.azure.com/> and select your organization.

### Create a PAT

A personal access token (PAT) is used as an alternate password to authenticate into Azure DevOps.

Now open the `User settings` (top right) and go to `Security` --> `Personal access tokens`.

Press `New Token`. Give the Token a name (e.g. `MyToken`), set Organization to `All accessible organizations` and Expiration to something >= 30 days. Set the Scope to `Full access`.

Copy the token and store it somewhere secure.

```sh
export AZURE_DEVOPS_EXT_PAT=<YOUR_PAT>
```

To store it in the environment.

### Create a project

Likely, you need to activate the `azure-devops` extension. To get a list of available extensions type

```sh
az extension list-available --output table | grep devops
```

We only need the `azure-devops` to be installed by

```sh
az extension add --name azure-devops
```

Now, login to your DevOps organization by the use of the PAT. The variable you're defining in the following should look similar like this:

`https://dev.azure.com/markus-winkler`

```sh
export DEVOPS_ORGANIZATION=<URL OF YOUR DEVOPS ORGANIZATION>
echo ${AZURE_DEVOPS_EXT_PAT} | az devops login --org ${DEVOPS_ORGANIZATION}
az devops project list --org ${DEVOPS_ORGANIZATION}
```

and create a project

```sh
az devops project create \
  --name ${APP_NAME} \
  --description 'Project for the Uploader' \
  --source-control git \
  --visibility private \
  --org ${DEVOPS_ORGANIZATION}
```

Alongside to the project a git repo is automatically created.

### Fork Sample Repository

We are now going to fork the sample Kubernetes service so that we will be able modify the repository and trigger builds. If you already forked the repo because of another lab you did before, there's no need to do it again. In that case, simply continue with cloning it to your  shell.

Login to GitHub and fork the Uploaders app:
<https://github.com/mawinkler/c1-app-sec-uploader>

### Populate the Azure Repository

And now clone it from your git:

```sh
export GITHUB_USERNAME="[YOUR GITHUB USERNAME]"
git clone https://github.com/${GITHUB_USERNAME}/${APP_NAME}.git
cd ${APP_NAME}
```

```sh
git init
git remote add azure https://${AZURE_DEVOPS_EXT_PAT}@${DEVOPS_ORGANIZATION//https:\/\//}/${APP_NAME}/_git/${APP_NAME}
```

Set the username and email address for your Git commits. Replace [EMAIL_ADDRESS] with your Git email address. Replace [USERNAME] with your Git username.

```sh
git config --global user.email "[EMAIL_ADDRESS]"
git config --global user.name "[USERNAME]"
```

And finally add all the files and folders recursively to the Cloud Source Repository.

```sh
git add .
git commit -m "Initial commit"
git push azure master
```

### Create the pipeline

Next step is to create our pipeline to build, scan, push and deploy the app to the AKS cluster. Do this by

```sh
az pipelines create \
  --name ${APP_NAME} \
  --branch master \
  --description 'Pipeline for the Uploader' \
  --org ${DEVOPS_ORGANIZATION} \
  --project ${APP_NAME} \
  --repository-type tfsgit \
  --repository ${DEVOPS_ORGANIZATION}/${APP_NAME}/_git/${APP_NAME}
```

A little longish conversation should start...

`>>>`

This command is in preview. It may be changed/removed in a future release.

Which template do you want to use for this pipeline?

Please enter a choice: `Deploy to Azure Kubernetes Service`

The template requires a few inputs. We will help you fill them out
Using your default Azure subscription `YOUR SUBSCRIPTION NAME` for fetching AKS clusters.
Which kubernetes cluster do you want to target for this pipeline?

Please enter a choice: `appcluster`

Which kubernetes namespace do you want to target?

Please enter a choice: `default`

Which Azure Container Registry do you want to use for this pipeline?

Please enter a choice: `c1appsecuploaderregistryA1B2C3D4`

Enter a value for Image Name [Press Enter for default: cappsecuploaderdev]:

Enter a value for Service Port [Press Enter for default: 80]:

Please enter a value for Enable Review App flow for Pull Requests:

Do you want to view/edit the template yaml before proceeding?

Please enter a choice: `Continue with generated yaml`

Files to be added to your repository (3)

1) manifests/deployment.yml
2) manifests/service.yml
3) azure-pipelines.yml

How do you want to commit the files to the repository?

Please enter a choice: `Commit directly to the master branch.`

Checking in file manifests/deployment.yml in the Azure repo c1-app-sec-uploader
Checking in file manifests/service.yml in the Azure repo c1-app-sec-uploader
Checking in file azure-pipelines.yml in the Azure repo c1-app-sec-uploader
Successfully created a pipeline with Name: c1-app-sec-uploader, Id: 13.

{ ... }

`<<<`

Done, puuh.

## Integrate Smart Check and Application Security into the pipeline

### Variable definitions for the pipeline

Define the following variables required for the scan action within the variables section of your pipeline.

```sh
az pipelines variable create \
  --name dsscHost \
  --pipeline-name ${APP_NAME} \
  --org ${DEVOPS_ORGANIZATION} \
  --project ${APP_NAME} \
  --value ${DSSC_HOST}

az pipelines variable create \
  --name dsscUser \
  --pipeline-name ${APP_NAME} \
  --org ${DEVOPS_ORGANIZATION} \
  --project ${APP_NAME} \
  --value ${DSSC_USERNAME}

az pipelines variable create \
  --name dsscPassword \
  --pipeline-name ${APP_NAME} \
  --org ${DEVOPS_ORGANIZATION} \
  --project ${APP_NAME} \
  --value ${DSSC_PASSWORD} \
  --secret true

az pipelines variable create \
  --name dsscBuildScanUser \
  --pipeline-name ${APP_NAME} \
  --org ${DEVOPS_ORGANIZATION} \
  --project ${APP_NAME} \
  --value ${DSSC_REGUSER}

az pipelines variable create \
  --name dsscBuildScanPassword \
  --pipeline-name ${APP_NAME} \
  --org ${DEVOPS_ORGANIZATION} \
  --project ${APP_NAME} \
  --value ${DSSC_REGPASSWORD} \
  --secret true

az pipelines variable create \
  --name applicationSecurityKey \
  --pipeline-name ${APP_NAME} \
  --org ${DEVOPS_ORGANIZATION} \
  --project ${APP_NAME} \
  --value ${TREND_AP_KEY}

az pipelines variable create \
  --name applicationSecuritySecret \
  --pipeline-name ${APP_NAME} \
  --org ${DEVOPS_ORGANIZATION} \
  --project ${APP_NAME} \
  --value ${TREND_AP_SECRET} \
  --secret true
```

### Integrate Application Security in the deployment manifest

Azure did create three files directly within your source code repo. To get these files to your current working directory, execute the following command:

```sh
git pull azure master
```

The following three files should now be available locally:

```sh
...
Fast-forward
 azure-pipelines.yml      | 79 ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
 manifests/deployment.yml | 19 ++++++++++++++++++
 manifests/service.yml    | 10 ++++++++++
...
```

Open the `manifests/deployment.yml` with your preferred editor and modify the `containers`-part as shown below. Insert the `env`-block after the `image:`-line.

```yaml
...
spec:
  ...
  template:
    ...
    spec:
      containers:
        - name: cappsecuploader
          image: c1appsecuploaderregistryA1B2C3D4.azurecr.io/cappsecuploader
          env:
          - name: TREND_AP_KEY
            value: _TREND_AP_KEY
          - name: TREND_AP_SECRET
            value: _TREND_AP_SECRET
          ports:
          ...
```

### Integrate Smart Check and Application Security into the pipeline definition

Now, modify the pipeline by edditing `azure-pipelines.yml`.

First, within the `Build`stage, split the `buildAndPush`-task in two seperate build and a push tasks, insert the scan task in the middle. It should look like the below code fragment.

```yaml
- stage: Build
  displayName: Build stage
  jobs:  
  - job: Build
    displayName: Build
    pool:
      vmImage: $(vmImageName)
    steps:
    - task: Docker@2
      displayName: Build an image
      inputs:
        command: build
        repository: $(imageRepository)
        dockerfile: $(dockerfilePath)
        containerRegistry: $(dockerRegistryServiceConnection)
        tags: |
          $(tag)

    # Scan the Container Image using Cloud One Container Security
    - script: |
        openssl s_client -showcerts -connect $(dsscHost):443 < /dev/null | \
          sed -ne '/-BEGIN CERTIFICATE-/,/-END CERTIFICATE-/p' > $(dsscHost).crt
        sudo cp $(dsscHost).crt /usr/local/share/ca-certificates/$(dsscHost).crt
        sudo mkdir -p /etc/docker/certs.d/$(dsscHost):5000
        sudo cp $(dsscHost).crt /etc/docker/certs.d/$(dsscHost):5000/ca.crt

        sudo update-ca-certificates

        docker run  -v /var/run/docker.sock:/var/run/docker.sock -v $HOME/.cache/:/root/.cache/ deepsecurity/smartcheck-scan-action \
        --preregistry-scan \
        --preregistry-password=$(dsscBuildScanPassword) \
        --preregistry-user=$(dsscBuildScanUser) \
        --image-name=$(containerRegistry)/$(imageRepository):$(tag) \
        --smartcheck-host=$(dsscHost) \
        --smartcheck-user=$(dsscUser) \
        --smartcheck-password=$(dsscPassword) \
        --insecure-skip-tls-verify \
        --insecure-skip-registry-tls-verify \
        --findings-threshold='{"malware": 200, "vulnerabilities": { "defcon1": 0, "critical": 30, "high": 100 }, "contents": { "defcon1": 0, "critical": 0, "high": 0 }, "checklists": { "defcon1": 0, "critical": 0, "high": 0 }}'
      displayName: "Scan an image"

    - task: Docker@2
      displayName: Push an image
      inputs:
        command: push
        repository: $(imageRepository)
        dockerfile: $(dockerfilePath)
        containerRegistry: $(dockerRegistryServiceConnection)
        tags: |
          $(tag)
```

Second, within the `Deploy` stage, integrate Cloud One Application Security into the pipeline. Do this by pasting the following lines in between the two tasks `Create imagePullSecret` and `Deploy to Kubernetes cluster`

```yaml
          - script: |
              sed -i 's|_TREND_AP_KEY|$(applicationSecurityKey)|' $(Pipeline.Workspace)/manifests/deployment.yml
              sed -i 's|_TREND_AP_SECRET|$(applicationSecuritySecret)|' $(Pipeline.Workspace)/manifests/deployment.yml
            displayName: "Configure Cloud One Application Security"
```

A full example of the manifests and the pipeline are in the appendix.

If you now `commit` and `push` the pipeline should run successfully.

And finally add all the files and folders recursively to the CodeCommit Repository.

```sh
git commit . -m "cloud one integrated"
git push azure master
```

You do find your source code repository within your devops organization and the project.

## Learn more

We invite you to learn more about:

- The services:
  - Azure Kubernetes Service <https://azure.microsoft.com/services/kubernetes-service/>
  - Azure Container Registry <https://azure.microsoft.com/services/container-registry/>
- The template used to create your pipeline: Deploy to existing Kubernetes cluster template <https://github.com/Microsoft/azure-pipelines-yaml/blob/master/templates/deploy-to-existing-kubernetes-cluster.yml>
- Some of the tasks used in your pipeline, and how you can customize them:
  - Docker task <https://docs.microsoft.com/en-us/azure/devops/pipelines/tasks/build/docker?view=azure-devops>
  - Kubernetes manifest task <https://docs.microsoft.com/en-us/azure/devops/pipelines/tasks/deploy/kubernetes-manifest?view=azure-devops>
- Some of the key concepts for this kind of pipeline:
  - Environments <https://docs.microsoft.com/en-us/azure/devops/pipelines/process/environments?view=azure-devops>
  - Deployment jobs <https://docs.microsoft.com/en-us/azure/devops/pipelines/process/deployment-jobs?view=azure-devops>
  - Stages <https://docs.microsoft.com/en-us/azure/devops/pipelines/process/stages?view=azure-devops>
  - Docker registry service connections (the method your pipeline uses to connect to the service) <https://docs.microsoft.com/en-us/azure/devops/pipelines/library/service-endpoints?view=azure-devops#sep-docreg>

## Additional Resources

- [Work with extensions](https://docs.microsoft.com/en-us/cli/azure/azure-cli-extensions-overview?view=azure-cli-latest)
- [Sign in with a Personal Access Token (PAT)](https://docs.microsoft.com/de-de/azure/devops/cli/log-in-via-pat?view=azure-devops&tabs=windows)

## Appendix

### Enable persistence for the environment variables when using Multi Cloud Shell

To make the defined environment variables persistent run

```sh
~/saveenv-az.sh
```

before you shut down the container.

Restore with

```sh
. ~/.az-lab.sh
```

### Example `manifests/deployment.yml`

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cappsecuploader
spec:
  replicas: 1
  selector:
    matchLabels:
      app: cappsecuploader
  template:
    metadata:
      labels:
        app: cappsecuploader
    spec:
      containers:
        - name: cappsecuploader
          image: c1appsecuploaderregistry.azurecr.io/cappsecuploader
          env:
          - name: TREND_AP_KEY
            value: _TREND_AP_KEY
          - name: TREND_AP_SECRET
            value: _TREND_AP_SECRET
          ports:
          - containerPort: 80
```

### Example `manifests/service.yml`

```yaml
apiVersion: v1
kind: Service
metadata:
    name: cappsecuploader
spec:
    type: LoadBalancer
    ports:
    - port: 80
    selector:
        app: cappsecuploader
```

### Example `azure-pipelines.yml`

```yaml
# Deploy to Azure Kubernetes Service
# Build and push image to Azure Container Registry; Deploy to Azure Kubernetes Service
# https://docs.microsoft.com/azure/devops/pipelines/languages/docker

trigger:
- master

resources:
- repo: self

variables:

  # Container registry service connection established during pipeline creation
  dockerRegistryServiceConnection: '38d9fcc9-8e09-4f1b-be98-38c42fcec0bb'
  imageRepository: 'cappsecuploader'
  containerRegistry: 'c1appsecuploaderregistry.azurecr.io'
  dockerfilePath: '**/Dockerfile'
  tag: '$(Build.BuildId)'
  imagePullSecret: 'c1appsecuploaderregistry3b30d-auth'

  # Agent VM image name
  vmImageName: 'ubuntu-latest'

stages:
- stage: Build
  displayName: Build stage
  jobs:  
  - job: Build
    displayName: Build
    pool:
      vmImage: $(vmImageName)
    steps:
    - task: Docker@2
      displayName: Build an image
      inputs:
        command: build
        repository: $(imageRepository)
        dockerfile: $(dockerfilePath)
        containerRegistry: $(dockerRegistryServiceConnection)
        tags: |
          $(tag)

    # Scan the Container Image using Cloud One Container Security
    - script: |
        openssl s_client -showcerts -connect $(dsscHost):443 < /dev/null | \
          sed -ne '/-BEGIN CERTIFICATE-/,/-END CERTIFICATE-/p' > $(dsscHost).crt
        sudo cp $(dsscHost).crt /usr/local/share/ca-certificates/$(dsscHost).crt
        sudo mkdir -p /etc/docker/certs.d/$(dsscHost):5000
        sudo cp $(dsscHost).crt /etc/docker/certs.d/$(dsscHost):5000/ca.crt

        sudo update-ca-certificates

        docker run  -v /var/run/docker.sock:/var/run/docker.sock -v $HOME/.cache/:/root/.cache/ deepsecurity/smartcheck-scan-action \
        --preregistry-scan \
        --preregistry-password=$(dsscBuildScanPassword) \
        --preregistry-user=$(dsscBuildScanUser) \
        --image-name=$(containerRegistry)/$(imageRepository):$(tag) \
        --smartcheck-host=$(dsscHost) \
        --smartcheck-user=$(dsscUser) \
        --smartcheck-password=$(dsscPassword) \
        --insecure-skip-tls-verify \
        --insecure-skip-registry-tls-verify \
        --findings-threshold='{"malware": 200, "vulnerabilities": { "defcon1": 0, "critical": 30, "high": 100 }, "contents": { "defcon1": 0, "critical": 0, "high": 0 }, "checklists": { "defcon1": 0, "critical": 0, "high": 0 }}'
      displayName: "Scan an image"

    - task: Docker@2
      displayName: Push an image
      inputs:
        command: push
        repository: $(imageRepository)
        dockerfile: $(dockerfilePath)
        containerRegistry: $(dockerRegistryServiceConnection)
        tags: |
          $(tag)

    - upload: manifests
      artifact: manifests

- stage: Deploy
  displayName: Deploy stage
  dependsOn: Build

  jobs:
  - deployment: Deploy
    displayName: Deploy
    pool:
      vmImage: $(vmImageName)
    environment: 'mawinklerc1appsecuploader-1352.appcluster-default-1492'
    strategy:
      runOnce:
        deploy:
          steps:
          - task: KubernetesManifest@0
            displayName: Create imagePullSecret
            inputs:
              action: createSecret
              secretName: $(imagePullSecret)
              dockerRegistryEndpoint: $(dockerRegistryServiceConnection)

          # Set Environment Variables for Cloud One Application Security
          - script: |
              sed -i 's|_TREND_AP_KEY|$(applicationSecurityKey)|' $(Pipeline.Workspace)/manifests/deployment.yml
              sed -i 's|_TREND_AP_SECRET|$(applicationSecuritySecret)|' $(Pipeline.Workspace)/manifests/deployment.yml
            displayName: "Configure Cloud One Application Security"

          - task: KubernetesManifest@0
            displayName: Deploy to Kubernetes cluster
            inputs:
              action: deploy
              manifests: |
                $(Pipeline.Workspace)/manifests/deployment.yml
                $(Pipeline.Workspace)/manifests/service.yml
              imagePullSecrets: |
                $(imagePullSecret)
              containers: |
                $(containerRegistry)/$(imageRepository):$(tag)
```

### Suspend Virtual Machines

```sh
export AZ_VMSS=`az vmss list | jq -r '.[].name'`
export AZ_RESOURCE_GROUP=`az vmss list | jq -r '.[].resourceGroup'`
echo ${AZ_VMSS}
echo ${AZ_RESOURCE_GROUP}
az vmss stop --name ${AZ_VMSS} --resource-group ${AZ_RESOURCE_GROUP}
```

### Clean up resources

Whenever you're done with the resources you created above, you can use the following command to delete them:

```sh
az group delete --name ${APP_NAME}
```

## Azure Commands

List locations:

```sh
azure location list --json
```
