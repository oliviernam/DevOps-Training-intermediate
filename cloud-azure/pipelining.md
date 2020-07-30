# CI/CD with Azure Pipelines

- [CI/CD with Azure Pipelines](#cicd-with-azure-pipelines)
  - [Prerequisites](#prerequisites)
  - [Get the code](#get-the-code)
  - [Create the Azure resources](#create-the-azure-resources)
    - [Create a Resource Group](#create-a-resource-group)
    - [Create a container registry](#create-a-container-registry)
    - [Create a Kubernetes cluster](#create-a-kubernetes-cluster)
  - [Deploy CloudOne Image Security](#deploy-cloudone-image-security)
  - [Sign in to Azure Pipelines](#sign-in-to-azure-pipelines)
  - [Create the pipeline](#create-the-pipeline)
    - [Connect and select repository](#connect-and-select-repository)
    - [Fix deployment.yml](#fix-deploymentyml)
    - [Integrate Image Security into the Pipeline](#integrate-image-security-into-the-pipeline)
  - [Clean up resources](#clean-up-resources)
  - [Learn more](#learn-more)
  - [Azure Commands](#azure-commands)
  - [Azure Pipeline (remove me)](#azure-pipeline-remove-me)

## Prerequisites

- A GitHub account, where you can create a repository. If you don't have one, you can create one for free.
- An Azure DevOps organization. If you don't have one, you can create one for free <https://docs.microsoft.com/en-us/azure/devops/pipelines/get-started/pipelines-sign-up?view=azure-devops>. (An Azure DevOps organization is different from your GitHub organization. Give them the same name if you want alignment between them.)
- If your team already has one, then make sure you're an administrator of the Azure DevOps project that you want to use.
- An Azure account. If you don't have one, you can create one for free.

## Get the code

Fork the following repository containing a sample application and a Dockerfile:

<https://github.com/mawinkler/troopers>

## Create the Azure resources

Sign in to the Azure Portal <https://portal.azure.com/>, and then select the Cloud Shell <https://docs.microsoft.com/en-us/azure/cloud-shell/overview> button in the upper-right corner.

### Create a Resource Group

```shell
az group create --name troopers --location westeurope
```

### Create a container registry

```shell
az acr create --resource-group troopers --name troopersRegistry --sku Basic
```

### Create a Kubernetes cluster

TODO: name, node-count

```shell
az aks create \
    --resource-group troopers \
    --name appcluster \
    --node-count 2 \
    --enable-addons monitoring \
    --generate-ssh-keys
```

To configure kubectl to connect to your Kubernetes cluster, use the az aks get-credentials command. The following example gets credentials for the AKS cluster named appcluster in the troopers resource group:

```shell
az aks get-credentials --resource-group troopers --name appcluster
```

```text
Merged "appcluster" as current context in /home/markus/.kube/config
```

To verify the connection to your cluster, run the kubectl get nodes command to return a list of the cluster nodes:

```shell
kubectl get nodes
```

```text
NAME                       STATUS   ROLES   AGE   VERSION
aks-nodepool1-30577774-vmss000000   Ready    agent   39m   v1.16.10
aks-nodepool1-30577774-vmss000001   Ready    agent   39m   v1.16.10
aks-nodepool1-30577774-vmss000002   Ready    agent   39m   v1.16.10
```

## Deploy CloudOne Image Security

Define some variables

```shell
export DSSC_NAMESPACE='smartcheck'
export DSSC_USERNAME='administrator'
export DSSC_TEMPPW='justatemppw'
export DSSC_PASSWORD='trendmicro'
export DSSC_REGUSER='administrator'
export DSSC_REGPASSWORD='trendmicro'
```

Set the activation code for Smart Check

```shell
export DSSC_AC=<activation code>
```

Create CloudOne Image Security namespace

```shell
kubectl create namespace ${DSSC_NAMESPACE}
```

Create certificate request for load balancer certificate:

```shell
cat <<EOF>./req.conf
[req]
  distinguished_name=req
[san]
  subjectAltName=DNS:*.smartcheck.com
EOF

openssl req -x509 -newkey rsa:4096 -sha256 -days 3650 -nodes -keyout k8s.key -out k8s.crt -subj "/CN=*.smartcheck.com" -extensions san -config req.conf
kubectl create secret tls k8s-certificate --cert=k8s.crt --key=k8s.key --dry-run=true -n ${DSSC_NAMESPACE} -o yaml | kubectl apply -f -
```

Create overrides for Image Security:

```shell
cat <<EOF >./overrides-image-security.yml
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
EOF
cat <<EOF >./overrides-image-security-upgrade.yml
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
helm install -n ${DSSC_NAMESPACE} --values overrides-image-security.yml deepsecurity-smartcheck https://github.com/deep-security/smartcheck-helm/archive/master.tar.gz
```

To monitor how the deployments of Smart Check are getting available you can use the following watch command:

```shell
watch kubectl -n ${DSSC_NAMESPACE} get deployments
```

Wait for Image Security to be up and do the initial password change:

```shell
DSSC_HOST=''
while [[ "$DSSC_HOST" == '' ]];do
  export DSSC_HOST=`kubectl get svc -n ${DSSC_NAMESPACE} proxy -o jsonpath='{.status.loadBalancer.ingress[0].ip}'`
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

Create certificate request for load balancer certificate:

```shell
cat <<EOF>./req.conf
[req]
  distinguished_name=req
[san]
  subjectAltName=DNS:smartcheck-${DSSC_HOST//./-}.nip.io
EOF

openssl req -x509 -newkey rsa:4096 -sha256 -days 3650 -nodes -keyout k8s.key -out k8s.crt -subj "/CN=smartcheck-${DSSC_HOST//./-}.nip.io" -extensions san -config req.conf
kubectl create secret tls k8s-certificate --cert=k8s.crt --key=k8s.key --dry-run=true -n ${DSSC_NAMESPACE} -o yaml | kubectl apply -f -
```

```shell
helm upgrade --namespace ${DSSC_NAMESPACE} --values overrides-image-security-upgrade.yml deepsecurity-smartcheck https://github.com/deep-security/smartcheck-helm/archive/master.tar.gz --reuse-values
```

## Sign in to Azure Pipelines

If you do not have an Azure DevOps Organization, sign in to Azure Pipelines <https://azure.microsoft.com/services/devops/pipelines>. After you sign in, your browser goes to <https://dev.azure.com/...> and displays your Azure DevOps dashboard.

If you already own an Azure DevOps Organization, go to <https://aex.dev.azure.com/> and select your organization.

Within your selected organization, create a project. If you don't have any projects in your organization, you see a Create a project to get started screen. Otherwise, select the Create Project button in the upper-right corner of the dashboard.

## Create the pipeline

### Connect and select repository

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

### Fix deployment.yml

As of writing the lab, there seems to be an error in the deployment.yml generation.

Corret apiVersion to

```yaml
apiVersion : apps/v1
´´´

Add the selector within the DeploymentSpec

```yaml
spec:
  replicas: 1
  selector:
    matchLabels:
      app: <same as name in metadata>
```

### Integrate Image Security into the Pipeline

Define the following five variables required for the scan action within the variables section of your pipeline (top right). Of course, you should keep the values for passwords secret. If you chose to use a different username / password above, use these of course.

```yaml
cloudOne_imageSecurityHost: <URL to your Image Security instance running on the cluster>
cloudOne_imageSecurityUser: administrator
cloudOne_imageSecurityPassword: trendmicro
cloudOne_preScanUser: administrator
cloudOne_preScanPassword: trendmicro
```

Just after the `buildAndPush`-task paste the following task to your pipeline.

```yaml
    # Scan the Container Image using Cloud One Container Security
    - script: |
        openssl s_client -showcerts -connect $(cloudOne_imageSecurityHost):443 < /dev/null | sed -ne '/-BEGIN CERTIFICATE-/,/-END CERTIFICATE-/p' > smcert.crt
        sudo cp smcert.crt /usr/local/share/ca-certificates/$(cloudOne_imageSecurityHost).crt
        sudo mkdir -p /etc/docker/certs.d/$(cloudOne_imageSecurityHost):5000
        sudo cp smcert.crt /etc/docker/certs.d/$(cloudOne_imageSecurityHost):5000/ca.crt
        sudo update-ca-certificates

        docker run  -v /var/run/docker.sock:/var/run/docker.sock -v $HOME/Library/Caches:/root/.cache/ deepsecurity/smartcheck-scan-action \
        --preregistry-scan \
        --preregistry-password=$(cloudOne_preScanPassword) \
        --preregistry-user=$(cloudOne_preScanUser) \
        --image-name=$(containerRegistry)/$(imageRepository):$(tag) \
        --smartcheck-host=$(cloudOne_imageSecurityHost) \
        --smartcheck-user=$(cloudOne_imageSecurityUser) \
        --smartcheck-password=$(cloudOne_imageSecurityPassword) \
        --insecure-skip-tls-verify \
        --insecure-skip-registry-tls-verify \
        --findings-threshold='{"malware": 200, "vulnerabilities": { "defcon1": 0, "critical": 0, "high": 0 }, "contents": { "defcon1": 0, "critical": 0, "high": 0 }, "checklists": { "defcon1": 0, "critical": 0, "high": 0 }}'
      displayName: "Cloud One Container Security Scan"
```

## Clean up resources

Whenever you're done with the resources you created above, you can use the following command to delete them:

```shell
az group delete --name troopers
```

```shell
az group delete --name MC_troopers_myapp_germanywestcentral
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

## Azure Commands

List locations:

```shell
azure location list --json
```

## Azure Pipeline (remove me)

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
  dockerRegistryServiceConnection: '782fb958-53be-43c1-88aa-b7963403d2b2'
  imageRepository: 'mawinklertroopersdev'
  containerRegistry: 'troopersregistry.azurecr.io'
  dockerfilePath: '**/Dockerfile'
  tag: '$(Build.BuildId)'
  imagePullSecret: 'troopersregistrye311-auth'

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
      displayName: Build and push an image to container registry
      inputs:
        command: build
        repository: $(imageRepository)
        dockerfile: $(dockerfilePath)
        containerRegistry: $(dockerRegistryServiceConnection)
        tags: |
          $(tag)
          
    # Scan the Container Image using Cloud One Container Security
    - script: |
        openssl s_client -showcerts -connect $(cloudOne_imageSecurityHost):443 < /dev/null | sed -ne '/-BEGIN CERTIFICATE-/,/-END CERTIFICATE-/p' > smcert.crt
        sudo cp smcert.crt /usr/local/share/ca-certificates/$(cloudOne_imageSecurityHost).crt
        sudo mkdir -p /etc/docker/certs.d/$(cloudOne_imageSecurityHost):5000
        sudo cp smcert.crt /etc/docker/certs.d/$(cloudOne_imageSecurityHost):5000/ca.crt
        sudo update-ca-certificates

        docker run  -v /var/run/docker.sock:/var/run/docker.sock -v $HOME/Library/Caches:/root/.cache/ deepsecurity/smartcheck-scan-action \
        --preregistry-scan \
        --preregistry-password=$(cloudOne_preScanPassword) \
        --preregistry-user=$(cloudOne_preScanUser) \
        --image-name=$(containerRegistry)/$(imageRepository):$(tag) \
        --smartcheck-host=$(cloudOne_imageSecurityHost) \
        --smartcheck-user=$(cloudOne_imageSecurityUser) \
        --smartcheck-password=$(cloudOne_imageSecurityPassword) \
        --insecure-skip-tls-verify \
        --insecure-skip-registry-tls-verify \
        --findings-threshold='{"malware": 200, "vulnerabilities": { "defcon1": 0, "critical": 0, "high": 1 }, "contents": { "defcon1": 0, "critical": 0, "high": 0 }, "checklists": { "defcon1": 0, "critical": 0, "high": 0 }}'
      displayName: "Cloud One Container Security Scan"
      
    - task: Docker@2
      displayName: Build and push an image to container registry
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
    environment: 'mawinklertroopersdev.default'
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