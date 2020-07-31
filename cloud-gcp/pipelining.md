# CI/CD with GCP Cloud Build

- [CI/CD with GCP Cloud Build](#cicd-with-gcp-cloud-build)
  - [Prerequisites](#prerequisites)
  - [Create a Workspace](#create-a-workspace)
  - [Prepare for GKE Cluster](#prepare-for-gke-cluster)
  - [Create GKE Cluster](#create-gke-cluster)
  - [Deploy CloudOne Image Security](#deploy-cloudone-image-security)
  - [Create Repository to Host the App Code](#create-repository-to-host-the-app-code)
    - [Fork Sample Repository](#fork-sample-repository)
    - [Create a Cloud Source Repository](#create-a-cloud-source-repository)
  - [Prepare the Cloud Build, Publishing and Kubernetes Deployment](#prepare-the-cloud-build-publishing-and-kubernetes-deployment)
    - [Create Kubernetes Deployment and Service Definition](#create-kubernetes-deployment-and-service-definition)
    - [Create the Build Trigger](#create-the-build-trigger)
    - [Create the Build Specification cloudbuild.yaml](#create-the-build-specification-cloudbuildyaml)
    - [Manually trigger the pipeline](#manually-trigger-the-pipeline)
    - [Manually build and push](#manually-build-and-push)
  - [Trigger the Pipeline](#trigger-the-pipeline)
  - [GKE](#gke)

## Prerequisites

- Enable Cloud Build API
- Cloud Build, Google Cloud’s continuous integration (CI) and continuous delivery (CD) platform, lets you build software quickly across all languages. Get complete control over defining custom workflows for building, testing, and deploying across multiple environments such as VMs, serverless, Kubernetes, or Firebase.
- Google Container Registry provides secure, private Docker repository storage on Google Cloud Platform. You can use gcloud to push images to your registry , then you can pull images using an HTTP endpoint from any machine, whether it's a Google Compute Engine instance or your own hardware. Learn more

## Create a Workspace

From the Cloud Console, click Activate Cloud Shell `>_`

This virtual machine is loaded with all the development tools you'll need. It offers a persistent 5GB home directory and runs in Google Cloud, greatly enhancing network performance and authentication. Much, if not all, of your work in this codelab can be done with simply a browser or your Chromebook.

Once connected to Cloud Shell, you should see that you are already authenticated and that the project is already set to your project ID.

Run the following command in Cloud Shell to confirm that you are authenticated:

```shell
gcloud auth list
```

Note: The gcloud command-line tool is the powerful and unified command-line tool in Google Cloud. It comes preinstalled in Cloud Shell. You will notice its support for tab completion. For more information, see gcloud command-line tool overview.

## Prepare for GKE Cluster

Set up some variables.

```shell
export PROJECT=$(gcloud info --format='value(config.project)')
export ZONE=europe-west2-b
export CLUSTER=gke-deploy-cluster
```

Store values in gcloud config.

```shell
gcloud config set project $PROJECT
gcloud config set compute/zone $ZONE
```

Run the following commands to see your preset account and project. When you create resources with gcloud, this is where they get stored.

```shell
gcloud config list project
gcloud config list compute/zone
```

Make sure that the following APIs are enabled in the Google Cloud Console:

- GKE API
- Container Registry API
- Cloud Build API
- Cloud Source Repositories API

```shell
gcloud services enable container.googleapis.com \
    containerregistry.googleapis.com \
    cloudbuild.googleapis.com \
    sourcerepo.googleapis.com
```

If you're working with a new project, you likely need to enable billing and afterwards the compute API within our project. For that, we first need to look up available billing accounts.

```shell
gcloud alpha billing accounts list
```

```shell
ACCOUNT_ID            NAME                 OPEN  MASTER_ACCOUNT_ID
019XXX-6XXXX9-4XXXX1  My Billing Account   True
```

We now link that billing account to our project.

```shell
gcloud alpha billing projects link <project id> \
  --billing-account 019XXX-6XXXX9-4XXXX1
```

And finally enable the API.

```shell
gcloud services enable compute.googleapis.com
```

## Create GKE Cluster

Start your cluster with three nodes.

```shell
gcloud container clusters create ${CLUSTER} \
    --project=${PROJECT} \
    --zone=${ZONE} \
    --scopes "https://www.googleapis.com/auth/projecthosting,storage-rw"
```

Give Cloud Build rights to your cluster.

```shell
export PROJECT_NUMBER="$(gcloud projects describe \
    $(gcloud config get-value core/project -q) --format='get(projectNumber)')"

#gcloud projects add-iam-policy-binding ${PROJECT} \
#    --member=serviceAccount:${PROJECT_NUMBER}@cloudbuild.gserviceaccount.com \
#    --role=roles/container.developer

gcloud projects add-iam-policy-binding ${PROJECT} \
    --member=serviceAccount:${PROJECT_NUMBER}@cloudbuild.gserviceaccount.com \
    --role=roles/owner
```

Your environment is ready!

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

Finally, run

```shell
curl -sSL https://raw.githubusercontent.com/mawinkler/devops-training/master/cloudone-image-security/deploy-ip.sh | bash
```

## Create Repository to Host the App Code

### Fork Sample Repository

We are now going to fork the sample Kubernetes service so that we will be able modify the repository and trigger builds.

Login to GitHub and fork the Troopers app:
<https://github.com/mawinkler/troopers>

And now clone it from your git:

```shell
git clone https://github.com/mawinkler/troopers.git
cd troopers
```

### Create a Cloud Source Repository

```shell
gcloud source repos create troopers
git init
git config credential.helper gcloud.sh
git remote add gcp https://source.developers.google.com/p/$PROJECT/r/troopers
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
git push gcp master
```

The repository can be accessed via
<https://source.developers.google.com/p/$PROJECT/r/troopers>

## Prepare the Cloud Build, Publishing and Kubernetes Deployment

### Create Kubernetes Deployment and Service Definition

```shell
export IMAGE_NAME=troopers
export IMAGE_TAG=latest
cat <<EOF > app-gcp.yml
apiVersion: v1
kind: Service
metadata:
  annotations:
    service.alpha.kubernetes.io/tolerate-unready-endpoints: "true"
  name: ${IMAGE_NAME}
  labels:
    app: ${IMAGE_NAME}
spec:
  type: LoadBalancer
  ports:
  - port: 5000
    name: ${IMAGE_NAME}
    targetPort: 5000
  selector:
    app: ${IMAGE_NAME}
---
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app: ${IMAGE_NAME}
  name: ${IMAGE_NAME}
spec:
  replicas: 1
  selector:
    matchLabels:
      app: ${IMAGE_NAME}
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 1
  template:
    metadata:
      labels:
        app: ${IMAGE_NAME}
    spec:
      containers:
      - name: ${IMAGE_NAME}
        image: gcr.io/PROJECT/IMAGE_NAME:IMAGE_TAG
        imagePullPolicy: Always
        ports:
        - containerPort: 5000
EOF
```

### Create the Build Trigger

Set up a build trigger to watch for changes.

```shell
cat <<EOF > build-trigger.json
{
  "triggerTemplate": {
    "projectId": "${PROJECT}",
    "repoName": "${IMAGE_NAME}",
    "branchName": "master"
  },
  "description": "master",
  "substitutions": {
    "_CLOUDSDK_COMPUTE_ZONE": "${ZONE}",
    "_CLOUDSDK_CONTAINER_CLUSTER": "${CLUSTER}",
    "_CLOUDONE_IMAGESECURITY_HOST": "smartcheck-${DSSC_HOST//./-}.nip.io",
    "_CLOUDONE_IMAGESECURITY_USER": "${DSSC_USERNAME}",
    "_CLOUDONE_IMAGESECURITY_PASSWORD": "${DSSC_PASSWORD}",
    "_CLOUDONE_PRESCAN_USER": "${DSSC_REGUSER}",
    "_CLOUDONE_PRESCAN_PASSWORD": "${DSSC_REGPASSWORD}"
  },
  "filename": "cloudbuild.yaml"
}
EOF

curl -X POST \
    https://cloudbuild.googleapis.com/v1/projects/${PROJECT}/triggers \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $(gcloud config config-helper --format='value(credential.access_token)')" \
    --data-binary @build-trigger.json
```

Review Triggers here: <https://console.cloud.google.com/gcr/triggers>

### Create the Build Specification cloudbuild.yaml

```shell
cat <<EOF > cloudbuild.yaml
steps:

### Build

  - id: 'build'
    name: 'gcr.io/cloud-builders/docker'
    entrypoint: 'bash'
    args:
      - '-c'
      - |
          docker build -t gcr.io/${PROJECT}/${IMAGE_NAME}:${IMAGE_TAG} .

### Scan

  - id: 'scan'
    name: 'gcr.io/cloud-builders/docker'
    env:
      - 'CLOUDONE_IMAGESECURITY_HOST=${_CLOUDONE_IMAGESECURITY_HOST}'
      - 'CLOUDONE_IMAGESECURITY_USER=${_CLOUDONE_IMAGESECURITY_USER}'
      - 'CLOUDONE_IMAGESECURITY_PASSWORD=${_CLOUDONE_IMAGESECURITY_PASSWORD}'
      - 'CLOUDONE_PRESCAN_USER=${_CLOUDONE_PRESCAN_USER}'
      - 'CLOUDONE_PRESCAN_PASSWORD=${_CLOUDONE_PRESCAN_PASSWORD}'
    entrypoint: 'bash'
    args:
      - '-c'
      - |
          openssl s_client -showcerts -connect ${CLOUDONE_IMAGESECURITY_HOST}:443 < /dev/null | sed -ne '/-BEGIN CERTIFICATE-/,/-END CERTIFICATE-/p' > smcert.crt
          sudo cp smcert.crt /usr/local/share/ca-certificates/${CLOUDONE_IMAGESECURITY_HOST}.crt
          sudo mkdir -p /etc/docker/certs.d/${CLOUDONE_IMAGESECURITY_HOST}:5000
          sudo cp smcert.crt /etc/docker/certs.d/${CLOUDONE_IMAGESECURITY_HOST}:5000/ca.crt
          sudo update-ca-certificates

          docker run  -v /var/run/docker.sock:/var/run/docker.sock -v $HOME/Library/Caches:/root/.cache/ deepsecurity/smartcheck-scan-action \
          --preregistry-scan \
          --preregistry-password=${CLOUDONE_PRESCAN_PASSWORD} \
          --preregistry-user=${CLOUDONE_PRESCAN_USER} \
          --image-name=gcr.io/${PROJECT}/${IMAGE_NAME}:${IMAGE_TAG} \
          --smartcheck-host=${CLOUDONE_IMAGESECURITY_HOST} \
          --smartcheck-user=${CLOUDONE_IMAGESECURITY_USER} \
          --smartcheck-password=${CLOUDONE_IMAGESECURITY_PASSWORD} \
          --insecure-skip-tls-verify \
          --insecure-skip-registry-tls-verify \
          --findings-threshold='{"malware": 200, "vulnerabilities": { "defcon1": 0, "critical": 0, "high": 1 }, "contents": { "defcon1": 0, "critical": 0, "high": 0 }, "checklists": { "defcon1": 0, "critical": 0, "high": 0 }}'

### Publish
  - id: 'publish'
    name: 'gcr.io/cloud-builders/docker'
    entrypoint: 'bash'
    args:
      - '-c'
      - |
          docker push gcr.io/${PROJECT}/${IMAGE_NAME}:${IMAGE_TAG}

### Deploy
  - id: 'deploy'
    name: 'gcr.io/cloud-builders/gcloud'
    env:
      - 'CLOUDSDK_COMPUTE_ZONE=${_CLOUDSDK_COMPUTE_ZONE}'
      - 'CLOUDSDK_CONTAINER_CLUSTER=${_CLOUDSDK_CONTAINER_CLUSTER}'
      - 'KUBECONFIG=/kube/config'
    entrypoint: 'bash'
    args:
      - '-c'
      - |
          CLUSTER=$$(gcloud config get-value container/cluster)
          PROJECT=$$(gcloud config get-value core/project)
          ZONE=$$(gcloud config get-value compute/zone)

          gcloud container clusters get-credentials "$${CLUSTER}" \
            --project "$${PROJECT}" \
            --zone "$${ZONE}"  

          sed -i 's|gcr.io/PROJECT/IMAGE_NAME:IMAGE_TAG|gcr.io/$PROJECT/$IMAGE_NAME:$IMAGE_TAG|' ./app-gcp.yml

          kubectl get ns troopers || kubectl create ns troopers
          kubectl apply --namespace troopers -f app-gcp.yml
EOF
```

### Manually trigger the pipeline

```shell
# by config
gcloud builds submit --config cloudbuild.yaml .

# by trigger
gcloud alpha builds triggers run master --branch=master
```

### Manually build and push

```shell
# by tag
gcloud builds submit --tag gcr.io/${PROJECT}/${IMAGE_NAME}
```

## Trigger the Pipeline

```shell
git add .
git commit . -m "initial version"
git push gcp master
```

Query the Load Balancer IP by

```shell
kubectl -n troopers get services
```

## GKE

TO delete a cluster:

```shell
gcloud container clusters delete -q ${CLUSTER}
```
