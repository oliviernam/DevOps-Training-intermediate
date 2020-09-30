# CI/CD with Azure Pipelines

- [CI/CD with Azure Pipelines](#cicd-with-azure-pipelines)
  - [Prerequisites](#prerequisites)
  - [Get the code](#get-the-code)
  - [Create the Azure resources](#create-the-azure-resources)
    - [Create a Resource Group](#create-a-resource-group)
    - [Create a Container Registry](#create-a-container-registry)
    - [Create a Kubernetes Cluster](#create-a-kubernetes-cluster)
  - [Deploy CloudOne Image Security](#deploy-cloudone-image-security)
  - [Configure CloudOne Application Security](#configure-cloudone-application-security)
  - [Build the Azure Pipeline](#build-the-azure-pipeline)
    - [Create a PAT](#create-a-pat)
    - [Create a project](#create-a-project)
    - [Fork Sample Repository](#fork-sample-repository)
    - [Create the pipeline](#create-the-pipeline)
    - [Fix deployment.yml](#fix-deploymentyml)
  - [Integrate Image Security and Application Security into the pipeline](#integrate-image-security-and-application-security-into-the-pipeline)
    - [Variable definitions for the pipeline](#variable-definitions-for-the-pipeline)
    - [Integrate Application Security in the deployment manifest](#integrate-application-security-in-the-deployment-manifest)
    - [Integrate Image Security and Application Security into the pipeline definition](#integrate-image-security-and-application-security-into-the-pipeline-definition)
  - [Learn more](#learn-more)
  - [Additional Resources](#additional-resources)
  - [Appendix](#appendix)
    - [Cloud Shell Timeouts](#cloud-shell-timeouts)
    - [Example `manifests/deployment.yml`](#example-manifestsdeploymentyml)
    - [Example `manifests/service.yml`](#example-manifestsserviceyml)
    - [Example `azure-pipelines.yml`](#example-azure-pipelinesyml)
    - [Clean up resources](#clean-up-resources)
  - [Azure Commands](#azure-commands)
  - [Create the Pipeline (UI Path)](#create-the-pipeline-ui-path)

## Prerequisites

- A GitHub account, where you can create a repository. If you don't have one, you can create one for free.
- An Azure DevOps organization. If you don't have one, you can create one for free <https://docs.microsoft.com/en-us/azure/devops/pipelines/get-started/pipelines-sign-up?view=azure-devops>. (An Azure DevOps organization is different from your GitHub organization. Give them the same name if you want alignment between them)
- If your team already has one, then make sure you're an administrator of the Azure DevOps project that you want to use
- An Azure account
- A CloudOne Application Security Account

## Get the code

Fork the following repository containing a sample application and a Dockerfile to your GitHub account:

<https://github.com/mawinkler/c1-app-sec-uploader>

## Create the Azure resources

Sign in to the Azure Portal <https://portal.azure.com/>, and then select the Cloud Shell button in the upper-right corner.

Info: <https://docs.microsoft.com/en-us/azure/cloud-shell/overview>

### Create a Resource Group

```shell
export APP_NAME=c1-app-sec-uploader && echo "export APP_NAME=${APP_NAME}" >> statefile.sh
az group create --name ${APP_NAME} --location westeurope
```

### Create a Container Registry

```shell
export APP_REGISTRY=c1appsecuploaderregistry$(openssl rand -hex 4) && echo "export APP_REGISTRY=${APP_REGISTRY}" >> statefile.sh
az acr create --resource-group ${APP_NAME} --name ${APP_REGISTRY} --sku Basic
```

### Create a Kubernetes Cluster

```shell
export CLUSTER_NAME=appcluster && echo "export CLUSTER_NAME=${CLUSTER_NAME}" >> statefile.sh
az aks create \
    --resource-group ${APP_NAME} \
    --name ${CLUSTER_NAME} \
    --node-count 2 \
    --enable-addons monitoring \
    --generate-ssh-keys
```

To configure kubectl to connect to your Kubernetes cluster, use the az aks get-credentials command. The following example gets credentials for the AKS cluster named appcluster in the ${APP_NAME} resource group:

```shell
az aks get-credentials --resource-group ${APP_NAME} --name ${CLUSTER_NAME}
```

To verify the connection to your cluster, run the kubectl get nodes command to return a list of the cluster nodes:

```shell
kubectl get nodes
```

```text
NAME                       STATUS   ROLES   AGE   VERSION
aks-nodepool1-30577774-vmss000000   Ready    agent   39m   v1.16.10
aks-nodepool1-30577774-vmss000001   Ready    agent   39m   v1.16.10
```

## Deploy CloudOne Image Security

Define some variables

```shell
export DSSC_NAMESPACE='smartcheck' && echo "export DSSC_NAMESPACE=${DSSC_NAMESPACE}" >> statefile.sh
export DSSC_USERNAME='administrator' && echo "export DSSC_USERNAME=${DSSC_USERNAME}" >> statefile.sh
export DSSC_PASSWORD='trendmicro' && echo "export DSSC_PASSWORD=${DSSC_PASSWORD}" >> statefile.sh
export DSSC_REGUSER='administrator' && echo "export DSSC_REGUSER=${DSSC_REGUSER}" >> statefile.sh
export DSSC_REGPASSWORD='trendmicro' && echo "export DSSC_REGPASSWORD=${DSSC_REGPASSWORD}" >> statefile.sh
```

Set the activation code for Smart Check

```shell
export DSSC_AC=<SMART CHECK ACTIVATION CODE> && echo "export DSSC_AC=${DSSC_AC}" >> statefile.sh
```

Finally, run

```shell
curl -sSL https://raw.githubusercontent.com/mawinkler/devops-training/master/cloudone-image-security/deploy-ip.sh | bash
export DSSC_HOST_IP=$(kubectl get svc -n ${DSSC_NAMESPACE} proxy -o jsonpath='{.status.loadBalancer.ingress[0].ip}') && \
  echo "export DSSC_HOST_IP=${DSSC_HOST_IP}" >> statefile.sh
export DSSC_HOST="smartcheck-${DSSC_HOST_IP//./-}.nip.io" && \
  echo "export DSSC_HOST=${DSSC_HOST}" >> statefile.sh

or

curl -sSL https://raw.githubusercontent.com/mawinkler/deploy/master/deploy-ip.sh | bash
export DSSC_HOST_IP=$(kubectl get svc -n ${DSSC_NAMESPACE} proxy -o jsonpath='{.status.loadBalancer.ingress[0].ip}') && \
  echo "export DSSC_HOST_IP=${DSSC_HOST_IP}" >> statefile.sh
export DSSC_HOST="smartcheck-${DSSC_HOST_IP//./-}.nip.io" && \
  echo "export DSSC_HOST=${DSSC_HOST}" >> statefile.sh
```

## Configure CloudOne Application Security

Define the Application Security Key and Secret.

```shell
export TREND_AP_KEY=<YOUR CLOUD ONE APPLICATION SECURITY KEY> && echo "export TREND_AP_KEY=${TREND_AP_KEY}" >> statefile.sh
export TREND_AP_SECRET=<YOUR CLOUD ONE APPLICATION SECURITY SECRET> && echo "export TREND_AP_SECRET=${TREND_AP_SECRET}" >> statefile.sh
```

## Build the Azure Pipeline

If you do not have an Azure DevOps Organization, sign in to Azure Pipelines <https://azure.microsoft.com/services/devops/pipelines>. After you sign in, your browser goes to <https://dev.azure.com/...> and displays your Azure DevOps dashboard.

If you already own an Azure DevOps Organization, go to <https://aex.dev.azure.com/> and select your organization.

### Create a PAT

A personal access token (PAT) is used as an alternate password to authenticate into Azure DevOps.

Now open the `User settings` (top right) and go to `Security` --> `Personal access tokens`.

Press `New Token`. Give the Token a name (e.g. `MyToken`), set Organization to `All accessible organizations` and Expiration to something >= 30 days. Set the Scope to `Full access`.

Copy the token and store it somewhere secure.

```shell
export AZURE_DEVOPS_EXT_PAT=<YOUR_PAT> && echo "export AZURE_DEVOPS_EXT_PAT=${AZURE_DEVOPS_EXT_PAT}" >> statefile.sh
```

To store it in the environment.

### Create a project

Likely, you need to activate the `azure-devops` extension. To get a list of available extensions type

```shell
az extension list-available --output table | grep devops
```

We only need the `azure-devops` to be installed by

```shell
az extension add --name azure-devops
```

Now, login to your DevOps organization by the use of the PAT

```shell
export DEVOPS_ORGANIZATION=<URL OF YOUR DEVOPS ORGANIZATION, starts with https://dev.azure.com> && \
  echo "export AZURE_DEVOPS_EXT_PAT=${AZURE_DEVOPS_EXT_PAT}" >> statefile.sh
echo ${AZURE_DEVOPS_EXT_PAT} | az devops login --org ${DEVOPS_ORGANIZATION}
az devops project list --org ${DEVOPS_ORGANIZATION}
```

and create a project

```shell
az devops project create \
  --name ${APP_NAME} \
  --description 'Project for the Uploader' \
  --source-control git \
  --visibility private \
  --org ${DEVOPS_ORGANIZATION}
```

Alongside to the project a git repo is automatically created.

**TO IMPROVE WITHIN THE LAB: Get your repo credentials via the Azure DevOps UI Console**

### Fork Sample Repository

We are now going to fork the sample Kubernetes service so that we will be able modify the repository and trigger builds.

Login to GitHub and fork the Uploaders app:
<https://github.com/mawinkler/c1-app-sec-uploader>

And now clone it from your git:

```shell
export GITHUB_USERNAME="[YOUR GITHUB USERNAME]" && echo "export GITHUB_USERNAME=${GITHUB_USERNAME}" >> statefile.sh
git clone https://github.com/${GITHUB_USERNAME}/${APP_NAME}.git
cd ${APP_NAME}
```

```shell
git init
git remote add azure https://${AZURE_DEVOPS_EXT_PAT}@${DEVOPS_ORGANIZATION//https:\/\//}/${APP_NAME}/_git/${APP_NAME}
```

Set the username and email address for your Git commits. Replace [EMAIL_ADDRESS] with your Git email address. Replace [USERNAME] with your Git username.

```shell
git config --global user.email "[EMAIL_ADDRESS]"
git config --global user.name "[USERNAME]"
```

And finally add all the files and folders recursively to the Cloud Source Repository.

```shell
git add .
git commit -m "Initial commit"
git push azure master
```

### Create the pipeline

Next step is to create our pipeline to build, scan, push and deploy the app to the AKS cluster. Do this by

```shell
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

Please enter a choice [Default choice(1)]: `Deploy to Azure Kubernetes Service`

The template requires a few inputs. We will help you fill them out
Using your default Azure subscription Nutzungsbasierte Bezahlung for fetching AKS clusters.
Which kubernetes cluster do you want to target for this pipeline?

Please enter a choice [Default choice(1)]: `appcluster`

Which kubernetes namespace do you want to target?

Please enter a choice [Default choice(1)]: `default`

Using your default Azure subscription Nutzungsbasierte Bezahlung for fetching Azure Container Registries.
Which Azure Container Registry do you want to use for this pipeline?

Please enter a choice [Default choice(1)]: `c1appsecuploaderregistry`

Enter a value for Image Name [Press Enter for default: cappsecuploaderdev]:

Enter a value for Service Port [Press Enter for default: 80]:

Please enter a value for Enable Review App flow for Pull Requests:

Using your default Azure subscription `YOUR SUBSCRIPTION NAME` for creating Azure RM connection.
Which Azure Container Registry do you want to use for this pipeline?
Please enter a choice [Default choice(1)]: c1appsecuploaderregistry

Enter a value for Image Name [Press Enter for default: cappsecuploaderdev]:

Enter a value for Service Port [Press Enter for default: 80]:

Please enter a value for Enable Review App flow for Pull Requests:

Do you want to view/edit the template yaml before proceeding?

Please enter a choice [Default choice(1)]: `Continue with generated yaml`

Files to be added to your repository (3)

1) manifests/deployment.yml
2) manifests/service.yml
3) azure-pipelines.yml

How do you want to commit the files to the repository?

Please enter a choice [Default choice(1)]: `Commit directly to the master branch.`

Checking in file manifests/deployment.yml in the Azure repo c1-app-sec-uploader
Checking in file manifests/service.yml in the Azure repo c1-app-sec-uploader
Checking in file azure-pipelines.yml in the Azure repo c1-app-sec-uploader
Successfully created a pipeline with Name: c1-app-sec-uploader, Id: 13.

{ ... }

`<<<`

Done, puuh.

### Fix deployment.yml

As of writing the lab, there is an error in the deployment.yml generation.

To fix it do the following:

```shell
git pull azure master
code manifests/deployment.yml
```

Correct apiVersion to

```yaml
apiVersion : apps/v1
```

Add the selector within the DeploymentSpec

```yaml
spec:
  replicas: 1
  selector:
    matchLabels:
      app: <same as name in metadata>
```

Your full deployment.yml is shown in the appendix [`manifests/deployment.yml`](#manifestsdeploymentyml)

## Integrate Image Security and Application Security into the pipeline

### Variable definitions for the pipeline

Define the following variables required for the scan action within the variables section of your pipeline.

```shell
az pipelines variable create \
  --name cloudOne_imageSecurityHost \
  --pipeline-name ${APP_NAME} \
  --org ${DEVOPS_ORGANIZATION} \
  --project ${APP_NAME} \
  --value ${DSSC_HOST}

az pipelines variable create \
  --name cloudOne_imageSecurityUser \
  --pipeline-name ${APP_NAME} \
  --org ${DEVOPS_ORGANIZATION} \
  --project ${APP_NAME} \
  --value ${DSSC_USERNAME}

az pipelines variable create \
  --name cloudOne_imageSecurityPassword \
  --pipeline-name ${APP_NAME} \
  --org ${DEVOPS_ORGANIZATION} \
  --project ${APP_NAME} \
  --value ${DSSC_PASSWORD} \
  --secret true

az pipelines variable create \
  --name cloudOne_preScanUser \
  --pipeline-name ${APP_NAME} \
  --org ${DEVOPS_ORGANIZATION} \
  --project ${APP_NAME} \
  --value ${DSSC_REGUSER}

az pipelines variable create \
  --name cloudOne_preScanPassword \
  --pipeline-name ${APP_NAME} \
  --org ${DEVOPS_ORGANIZATION} \
  --project ${APP_NAME} \
  --value ${DSSC_REGPASSWORD} \
  --secret true

az pipelines variable create \
  --name cloudOne_applicationSecurityKey \
  --pipeline-name ${APP_NAME} \
  --org ${DEVOPS_ORGANIZATION} \
  --project ${APP_NAME} \
  --value ${TREND_AP_KEY}

az pipelines variable create \
  --name cloudOne_applicationSecuritySecret \
  --pipeline-name ${APP_NAME} \
  --org ${DEVOPS_ORGANIZATION} \
  --project ${APP_NAME} \
  --value ${TREND_AP_SECRET} \
  --secret true
```

### Integrate Application Security in the deployment manifest

Reopen the deployment.yml and modify the `spec` as shown below

```shell
code manifests/deployment.yml
```

```yaml
    spec:
      containers:
        - name: <same as name in metadata>
          image: ${APP_REGISTRY}.azurecr.io/<same as name in metadata>
          env:
          - name: TREND_AP_KEY
            value: _TREND_AP_KEY
          - name: TREND_AP_SECRET
            value: _TREND_AP_SECRET
          ports:
          - containerPort: 80
```

### Integrate Image Security and Application Security into the pipeline definition

Now, modify the pipeline.

```shell
code azure-pipelines.yml
```

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
        openssl s_client -showcerts -connect $(cloudOne_imageSecurityHost):443 < /dev/null | \
          sed -ne '/-BEGIN CERTIFICATE-/,/-END CERTIFICATE-/p' > $(cloudOne_imageSecurityHost).crt
        sudo cp $(cloudOne_imageSecurityHost).crt /usr/local/share/ca-certificates/$(cloudOne_imageSecurityHost).crt
        sudo mkdir -p /etc/docker/certs.d/$(cloudOne_imageSecurityHost):5000
        sudo cp $(cloudOne_imageSecurityHost).crt /etc/docker/certs.d/$(cloudOne_imageSecurityHost):5000/ca.crt

        sudo update-ca-certificates

        docker run  -v /var/run/docker.sock:/var/run/docker.sock -v $HOME/.cache/:/root/.cache/ deepsecurity/smartcheck-scan-action \
        --preregistry-scan \
        --preregistry-password=$(cloudOne_preScanPassword) \
        --preregistry-user=$(cloudOne_preScanUser) \
        --image-name=$(containerRegistry)/$(imageRepository):$(tag) \
        --smartcheck-host=$(cloudOne_imageSecurityHost) \
        --smartcheck-user=$(cloudOne_imageSecurityUser) \
        --smartcheck-password=$(cloudOne_imageSecurityPassword) \
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
              sed -i 's|_TREND_AP_KEY|$(cloudOne_applicationSecurityKey)|' $(Pipeline.Workspace)/manifests/deployment.yml
              sed -i 's|_TREND_AP_SECRET|$(cloudOne_applicationSecuritySecret)|' $(Pipeline.Workspace)/manifests/deployment.yml
            displayName: "Configure Cloud One Application Security"
```

A full example of the manifests and the pipeline are in the appendix.

If you now `commit` and `push` the pipeline should run successfully.

And finally add all the files and folders recursively to the CodeCommit Repository.

```shell
git commit . -m "cloudone integrated"
git push azure master
```

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

### Cloud Shell Timeouts

During the definition of variables, you should have created a file called statefile.sh. After a timeout of the cloud shell source the script to redefine the variables.

```shell
. ~/statefile.sh
```

```shell
eval "cat <<EOF
$(<cloudbuild.yaml)
EOF
" 2> /dev/null > cloudbuild.yaml
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
        openssl s_client -showcerts -connect $(cloudOne_imageSecurityHost):443 < /dev/null | \
          sed -ne '/-BEGIN CERTIFICATE-/,/-END CERTIFICATE-/p' > $(cloudOne_imageSecurityHost).crt
        sudo cp $(cloudOne_imageSecurityHost).crt /usr/local/share/ca-certificates/$(cloudOne_imageSecurityHost).crt
        sudo mkdir -p /etc/docker/certs.d/$(cloudOne_imageSecurityHost):5000
        sudo cp $(cloudOne_imageSecurityHost).crt /etc/docker/certs.d/$(cloudOne_imageSecurityHost):5000/ca.crt

        sudo update-ca-certificates

        docker run  -v /var/run/docker.sock:/var/run/docker.sock -v $HOME/.cache/:/root/.cache/ deepsecurity/smartcheck-scan-action \
        --preregistry-scan \
        --preregistry-password=$(cloudOne_preScanPassword) \
        --preregistry-user=$(cloudOne_preScanUser) \
        --image-name=$(containerRegistry)/$(imageRepository):$(tag) \
        --smartcheck-host=$(cloudOne_imageSecurityHost) \
        --smartcheck-user=$(cloudOne_imageSecurityUser) \
        --smartcheck-password=$(cloudOne_imageSecurityPassword) \
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
              sed -i 's|_TREND_AP_KEY|$(cloudOne_applicationSecurityKey)|' $(Pipeline.Workspace)/manifests/deployment.yml
              sed -i 's|_TREND_AP_SECRET|$(cloudOne_applicationSecuritySecret)|' $(Pipeline.Workspace)/manifests/deployment.yml
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

### Clean up resources

Whenever you're done with the resources you created above, you can use the following command to delete them:

```shell
az group delete --name ${APP_NAME}
```

## Azure Commands

List locations:

```shell
azure location list --json
```

## Create the Pipeline (UI Path)

1. Sign in to your Azure DevOps organization and navigate to your project.
2. Go to Pipelines, and then select New Pipeline.
3. Walk through the steps of the wizard by first selecting GitHub as the location of your source code.
4. You might be redirected to GitHub to sign in. If so, enter your GitHub credentials.
5. When the list of repositories appears, select your repository.
6. You might be redirected to GitHub to install the Azure Pipelines app. If so, select Approve and install.

When the Configure tab appears, select Deploy to Azure Kubernetes Service.

1. If you are prompted, select the subscription in which you created your registry and cluster.
2. Select the appcluster cluster.
3. For Namespace, select Existing, and then select default.
4. Select the name of your container registry.
5. You can leave the image name and the service port set to the defaults.
6. Set the Enable Review App for Pull Requests checkbox for review app <https://docs.microsoft.com/en-us/azure/devops/pipelines/process/environments-kubernetes?view=azure-devops> related configuration to be included in the pipeline YAML auto-generated in subsequent steps.
7. Select Validate and configure. As Azure Pipelines creates your pipeline, it:
   - Creates a Docker registry service connection to enable your pipeline to push images into your container registry.
   - Creates an environment and a Kubernetes resource within the environment. For an RBAC enabled cluster, the created Kubernetes resource implicitly creates ServiceAccount and RoleBinding objects in the cluster so that the created ServiceAccount can't perform operations outside the chosen namespace.
   - Generates an azure-pipelines.yml file, which defines your pipeline.
   - Generates Kubernetes manifest files. These files are generated by hydrating the deployment.yml and service.yml templates based on selections you made above.
8. When your new pipeline appears, review the YAML to see what it does. For more information, see how we build your pipeline below. When you're ready, select Save and run.
9. The commit that will create your new pipeline appears. You can see the generated files mentioned above. Select Save and run.
10. If you want, change the Commit message to something like Add pipeline to our repository. When you're ready, select Save and run to commit the new pipeline into your repo, and then begin the first run of your new pipeline!
