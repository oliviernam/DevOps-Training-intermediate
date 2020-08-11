# CI/CD with Azure Pipelines

- [CI/CD with Azure Pipelines](#cicd-with-azure-pipelines)
  - [TODO](#todo)
  - [Prerequisites](#prerequisites)
  - [Get the code](#get-the-code)
  - [Create the Azure resources](#create-the-azure-resources)
    - [Create a Resource Group](#create-a-resource-group)
    - [Create a container registry](#create-a-container-registry)
    - [Create a Kubernetes cluster](#create-a-kubernetes-cluster)
  - [Deploy CloudOne Image Security](#deploy-cloudone-image-security)
  - [Build the Azure Pipeline](#build-the-azure-pipeline)
    - [Create a PAT](#create-a-pat)
    - [Create a project](#create-a-project)
    - [Create the pipeline](#create-the-pipeline)
    - [Fix deployment.yml](#fix-deploymentyml)
  - [Integrate Image Security into the Pipeline](#integrate-image-security-into-the-pipeline)
  - [Clean up resources](#clean-up-resources)
  - [Learn more](#learn-more)
  - [Additional Resources](#additional-resources)
  - [Azure Commands](#azure-commands)
  - [Create the Pipeline (UI Path)](#create-the-pipeline-ui-path)

## TODO

- Integrate Application Security to the Lab

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
export APP_NAME=c1-app-sec-uploader
az group create --name ${APP_NAME} --location westeurope
```

### Create a container registry

```shell
az acr create --resource-group ${APP_NAME} --name c1appsecuploaderregistry --sku Basic
```

### Create a Kubernetes cluster

```shell
export CLUSTER_NAME=appcluster
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
export DSSC_NAMESPACE='smartcheck'
export DSSC_USERNAME='administrator'
export DSSC_PASSWORD='trendmicro'
export DSSC_REGUSER='administrator'
export DSSC_REGPASSWORD='trendmicro'
```

Set the activation code for Smart Check

```shell
export DSSC_AC=<activation code>
```

Finally, run

```shell
curl -sSL https://raw.githubusercontent.com/mawinkler/devops-training/master/cloudone-image-security/deploy-ip.sh | bash
export DSSC_HOST_IP=$(kubectl get svc -n ${DSSC_NAMESPACE} proxy -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
export DSSC_HOST="https://smartcheck-${DSSC_HOST_IP//./-}.nip.io"

or

curl -sSL https://raw.githubusercontent.com/mawinkler/deploy/master/deploy-ip.sh | bash
export DSSC_HOST_IP=$(kubectl get svc -n ${DSSC_NAMESPACE} proxy -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
export DSSC_HOST="https://smartcheck-${DSSC_HOST_IP//./-}.nip.io"
```

## Build the Azure Pipeline

If you do not have an Azure DevOps Organization, sign in to Azure Pipelines <https://azure.microsoft.com/services/devops/pipelines>. After you sign in, your browser goes to <https://dev.azure.com/...> and displays your Azure DevOps dashboard.

If you already own an Azure DevOps Organization, go to <https://aex.dev.azure.com/> and select your organization.

### Create a PAT

A personal access token (PAT) is used as an alternate password to authenticate into Azure DevOps.

Now open the `User settings` (top right) and go to `Security` --> `Personal access tokens`.

Press `New Token`. Give the Token a name (e.g. `MyToken`), set Organization to `All accessible organizations` and Expiration to something >= 30 days. Set the Scope to `Full access`.

Copy the token and store it somewhere secure.

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
export DEVOPS_ORGANIZATION=<URL OF YOUR DEVOPS ORGANIZATION, starts with dev.azure.com>
az devops login --org ${DEVOPS_ORGANIZATION}
az devops project list --org ${DEVOPS_ORGANIZATION}
{
  "continuationToken": null,
  "value": []
}
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

### Create the pipeline

Next step is to create our pipeline to build, scan, push and deploy the app to the AKS cluster. Do this by

```shell
export GITHUB_USERNAME=<YOUR GITHUB USERNAME>
az pipelines create \
  --name ${APP_NAME} \
  --branch master \
  --description 'Pipeline for the Uploader' \
  --org ${DEVOPS_ORGANIZATION} \
  --project ${APP_NAME} \
  --repository https://github.com/${GITHUB_USERNAME}/${APP_NAME}
```

A little longish conversation should start...

`>>>`

This command is in preview. It may be changed/removed in a future release.
We need to create a Personal Access Token to communicate with GitHub. A new PAT with scopes (admin:repo_hook, repo, user) will be created.
You can set the PAT in the environment variable (AZURE_DEVOPS_EXT_GITHUB_PAT) to avoid getting prompted.

Enter your GitHub username (leave blank for using already generated PAT): `YOUR GITHUB USERNAME`

Enter your GitHub password: `YOUR GITHUB PASSWORD`

Confirm Enter your GitHub password: `YOUR GITHUB PASSWORD`

Created new personal access token with scopes (admin:repo_hook, repo, user). Name: AzureDevopsCLIExtensionToken_20200811T121603345744 You can revoke this from your GitHub settings if thepipeline is no longer required.

Enter a service connection name to create? `azure_connection`

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

Checking in file manifests/deployment.yml in the Github repository `YOUR GITHUB USERNAME`/c1-app-sec-uploader
Checking in file manifests/service.yml in the Github repository `YOUR GITHUB USERNAME`/c1-app-sec-uploader
Checking in file azure-pipelines.yml in the Github repository `YOUR GITHUB USERNAME`/c1-app-sec-uploader
Successfully created a pipeline with Name: c1-app-sec-uploader, Id: 9.

{ ... }

`<<<`

Done, puuh.

### Fix deployment.yml

As of writing the lab, there seems to be an error in the deployment.yml generation.

To fix it do the following:

```shell
git clone https://github.com/${GITHUB_USERNAME}/${APP_NAME}-dev.git
cd ${APP_NAME}-dev
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

## Integrate Image Security into the Pipeline

Define the following five variables required for the scan action within the variables section of your pipeline (top right). Of course, you should keep the values for passwords secret. If you chose to use a different username / password above, use these of course.

```yaml
  cloudOne_imageSecurityHost: <YOUR SMARTCHECK DNS NAME, e.g.g smartcheck-10-0-0-1.nip.io>
  cloudOne_imageSecurityUser: administrator
  cloudOne_imageSecurityPassword: trendmicro
  cloudOne_preScanUser: administrator
  cloudOne_preScanPassword: trendmicro
```

Split the `buildAndPush`-task in a build and a push task, insert the scan task in the middle. It should look like the below code fragment.s

```yaml
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

        docker run  -v /var/run/docker.sock:/var/run/docker.sock -v $HOME:/root/.cache/ deepsecurity/smartcheck-scan-action \
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

Finally, 

```shell
eval "cat <<EOF
$(<azure-pipelines.yml)
EOF
" 2> /dev/null > azure-pipelines.yml
```

## Clean up resources

Whenever you're done with the resources you created above, you can use the following command to delete them:

```shell
az group delete --name ${APP_NAME}
```

```shell
az group delete --name MC_${APP_NAME}_myapp_germanywestcentral
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