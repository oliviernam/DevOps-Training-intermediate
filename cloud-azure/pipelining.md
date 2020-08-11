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
  - [Sign in to Azure Pipelines](#sign-in-to-azure-pipelines)
  - [Create the pipeline](#create-the-pipeline)
    - [Connect and select repository](#connect-and-select-repository)
    - [Fix deployment.yml](#fix-deploymentyml)
    - [Integrate Image Security into the Pipeline](#integrate-image-security-into-the-pipeline)
  - [Clean up resources](#clean-up-resources)
  - [Learn more](#learn-more)
  - [Azure Commands](#azure-commands)

## TODO

- Integrate Application Security to the Lab
- Potentially dissect UI workflow
- Change to Uploader
- Potentially integrate DNS??

## Prerequisites

- A GitHub account, where you can create a repository. If you don't have one, you can create one for free.
- An Azure DevOps organization. If you don't have one, you can create one for free <https://docs.microsoft.com/en-us/azure/devops/pipelines/get-started/pipelines-sign-up?view=azure-devops>. (An Azure DevOps organization is different from your GitHub organization. Give them the same name if you want alignment between them.)
- If your team already has one, then make sure you're an administrator of the Azure DevOps project that you want to use.
- An Azure account. If you don't have one, you can create one for free.

## Get the code

Fork the following repository containing a sample application and a Dockerfile to your GitHub account:

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
```

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
          sed -ne '/-BEGIN CERTIFICATE-/,/-END CERTIFICATE-/p' > /usr/local/share/ca-certificates/$(cloudOne_imageSecurityHost).crt
        # sudo cp smcert.crt /usr/local/share/ca-certificates/$(cloudOne_imageSecurityHost).crt
        # sudo mkdir -p /etc/docker/certs.d/$(cloudOne_imageSecurityHost):5000
        # sudo cp smcert.crt /etc/docker/certs.d/$(cloudOne_imageSecurityHost):5000/ca.crt
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
        --findings-threshold='{"malware": 200, "vulnerabilities": { "defcon1": 0, "critical": 0, "high": 1 }, "contents": { "defcon1": 0, "critical": 0, "high": 0 }, "checklists": { "defcon1": 0, "critical": 0, "high": 0 }}'
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
