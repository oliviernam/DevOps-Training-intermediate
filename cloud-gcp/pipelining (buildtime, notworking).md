# CI/CD with GCP Cloud Build

- [CI/CD with GCP Cloud Build](#cicd-with-gcp-cloud-build)
  - [TODO](#todo)
  - [Prerequisites](#prerequisites)
  - [Create the GCP resources](#create-the-gcp-resources)
    - [Create a Workspace](#create-a-workspace)
    - [Prepare for our GKE Cluster](#prepare-for-our-gke-cluster)
    - [Create GKE Cluster](#create-gke-cluster)
  - [JSON Key File](#json-key-file)
  - [Deploy CloudOne Image Security](#deploy-cloudone-image-security)
  - [Configure CloudOne Application Security](#configure-cloudone-application-security)
  - [Prepare the Cloud Build, Publishing and Kubernetes Deployment](#prepare-the-cloud-build-publishing-and-kubernetes-deployment)
    - [Fork Sample Repository](#fork-sample-repository)
    - [Create a Cloud Source Repository](#create-a-cloud-source-repository)
    - [Create Kubernetes Deployment and Service Definition](#create-kubernetes-deployment-and-service-definition)
    - [Create the Build Trigger](#create-the-build-trigger)
    - [Create the Build Specification cloudbuild.yaml](#create-the-build-specification-cloudbuildyaml)
  - [Trigger the Pipeline](#trigger-the-pipeline)
  - [Knowledge](#knowledge)
    - [Links](#links)
    - [Ingress](#ingress)
    - [Google-managed SSL certificate](#google-managed-ssl-certificate)
    - [Cloud Builders](#cloud-builders)
    - [Manually trigger the pipeline](#manually-trigger-the-pipeline)
    - [Manually build and push](#manually-build-and-push)
    - [Delete a cluster](#delete-a-cluster)
    - [Troubleshoot Google Cloud Build](#troubleshoot-google-cloud-build)
  - [Pipelines](#pipelines)
    - [Var 1](#var-1)
    - [Var 2](#var-2)
    - [Var 3](#var-3)
    - [Var 4](#var-4)

## TODO

- Solve Certificate issue

## Prerequisites

- Enable Cloud Build API
- Cloud Build, Google Cloud’s continuous integration (CI) and continuous delivery (CD) platform, lets you build software quickly across all languages. Get complete control over defining custom workflows for building, testing, and deploying across multiple environments such as VMs, serverless, Kubernetes, or Firebase.
- Google Container Registry provides secure, private Docker repository storage on Google Cloud Platform. You can use gcloud to push images to your registry , then you can pull images using an HTTP endpoint from any machine, whether it's a Google Compute Engine instance or your own hardware. Learn more

## Create the GCP resources

### Create a Workspace

From the Cloud Console, click Activate Cloud Shell `>_`

This virtual machine is loaded with all the development tools you'll need. It offers a persistent 5GB home directory and runs in Google Cloud, greatly enhancing network performance and authentication. Much, if not all, of your work in this codelab can be done with simply a browser or your Chromebook.

Once connected to Cloud Shell, you should see that you are already authenticated and that the project is already set to your project ID.

Run the following command in Cloud Shell to confirm that you are authenticated:

```shell
gcloud auth list
```

If you are not authenticated run 

```shell
gcloud auth login
```

and follow the process.

Note: The gcloud command-line tool is the powerful and unified command-line tool in Google Cloud. It comes preinstalled in Cloud Shell. You will notice its support for tab completion. For more information, see gcloud command-line tool overview.

### Prepare for our GKE Cluster

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
gcloud alpha billing projects link $PROJECT \
  --billing-account 019XXX-6XXXX9-4XXXX1
```

And finally enable the API.

```shell
gcloud services enable compute.googleapis.com
```

### Create GKE Cluster

Start your cluster with three nodes.

```shell
gcloud container clusters create ${CLUSTER} \
    --project=${PROJECT} \
    --zone=${ZONE} \
    --release-channel=rapid \
    --scopes "https://www.googleapis.com/auth/projecthosting,storage-rw"
```

Grant Cloud Build rights to your cluster.

```shell
export PROJECT_NUMBER="$(gcloud projects describe \
    $(gcloud config get-value core/project -q) --format='get(projectNumber)')"

gcloud projects add-iam-policy-binding ${PROJECT} \
    --member=serviceAccount:${PROJECT_NUMBER}@cloudbuild.gserviceaccount.com \
    --role=roles/container.developer

# gcloud projects add-iam-policy-binding ${PROJECT} \
#     --member=serviceAccount:${PROJECT_NUMBER}@cloudbuild.gserviceaccount.com \
#     --role=roles/owner
```

## JSON Key File

A service account key is a long-lived key-pair that you can use as a credential for a service account. You are responsible for security of the private key and other key management operations, such as key rotation.

Anyone who has access to a valid private key for a service account will be able to access resources through the service account. For example, some service accounts automatically created by Google Cloud, such as the Container Registry service account, are granted the read-write Editor role for the parent project. The Compute Engine default service account is configured with read-only access to storage within the same project.

In addition, the lifecycle of the key's access to the service account (and thus, the data the service account has access to) is independent of the lifecycle of the user who has downloaded the key.

```shell
export GCR_SERVICE_ACCOUNT=service-gcrsvc

gcloud iam service-accounts create ${GCR_SERVICE_ACCOUNT}

gcloud projects add-iam-policy-binding ${PROJECT} --member "serviceAccount:gcrsvc@${PROJECT}.iam.gserviceaccount.com" --role "roles/storage.admin"

gcloud iam service-accounts keys create ${GCR_SERVICE_ACCOUNT}_keyfile.json --iam-account gcrsvc@${PROJECT}.iam.gserviceaccount.com
```

Your environment is ready!

## Deploy CloudOne Image Security

First, a note on certificates.

Google is very strict when it comes to certificates. You'll likely realized that when using the Chrome browser already. For the same reason, we cannot use self signed certificates for services when Google services like CloudBuild should be able to connect to them. That effectively means, we need to use certificates with are trusted by other services and browsers.

In short, we're going to deploy Smart Check with a NodePort service (not LoadBalancer). Next we do create Google managed certificates and an ingresses which we bind together.

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

1. Deploy Smart Check as NodePort Service
2. Create a static address
3. Create managed certificate
4. Create Ingress w/o certificate
5. Get the LoadBalancer IP of the Ingress
6. Bind certificate to ingress

```shell
gcloud compute addresses create smartcheck-address --global
gcloud compute addresses create smartcheck-registry-address --global
```

Describe the address and set DSSC_HOST and DSSC_REG_HOST

```shell
export DSSC_HOST=$(gcloud compute addresses describe smartcheck-address --global | sed -n 's/address: \(.*\)/\1/p')
export DSSC_REG_HOST=$(gcloud compute addresses describe smartcheck-registry-address --global | sed -n 's/address: \(.*\)/\1/p')
```

To deploy Smart Check as a NodePort service, run

```shell
curl -sSL https://raw.githubusercontent.com/mawinkler/devops-training/master/cloudone-image-security/deploy-np.sh | bash
```

or

```shell
curl -sSL https://raw.githubusercontent.com/mawinkler/deploy/master/deploy-np.sh | bash
```

But beware, Smart Check will not be accessible via the internet as of now, since we deployed it as a NodePort service only.

Now, let's request a publicly trusted certificate for Smart Check...

```shell
cat <<EOF > smartcheck-managed-certificate.yml
apiVersion: networking.gke.io/v1beta2
kind: ManagedCertificate
metadata:
  name: smartcheck-certificate
spec:
  domains:
    - smartcheck-${DSSC_HOST//./-}.nip.io
EOF

kubectl -n ${DSSC_NAMESPACE} apply -f smartcheck-managed-certificate.yml
```

...and the internal registry.

```shell
cat <<EOF > smartcheck-registry-managed-certificate.yml
apiVersion: networking.gke.io/v1beta2
kind: ManagedCertificate
metadata:
  name: smartcheck-registry-certificate
spec:
  domains:
    - smartcheck-registry-${DSSC_REG_HOST//./-}.nip.io
EOF

kubectl -n ${DSSC_NAMESPACE} apply -f smartcheck-registry-managed-certificate.yml
```

Next, we're defining the backend config for the health checks and 

```shell
cat <<EOF > smartcheck-registry-backendconfig.yml
apiVersion: cloud.google.com/v1
kind: BackendConfig
metadata:
  name: smartcheck-registry-config
spec:
  healthCheck:
    type: SSL
EOF

kubectl -n ${DSSC_NAMESPACE} apply -f smartcheck-registry-backendconfig.yml

kubectl -n smartcheck annotate service proxy cloud.google.com/app-protocols='{"https":"HTTPS","http":"HTTP","registryhttps":"HTTPS"}'
kubectl -n smartcheck annotate service proxy cloud.google.com/backend-config='{"ports": {"registryhttps":"smartcheck-registry-config"}}'
```

Now assign the certs to the ingresses we're creating below:

```shell
cat <<EOF > smartcheck-managed-ingress.yml
apiVersion: networking.k8s.io/v1beta1
kind: Ingress
metadata:
  name: proxy-ingress
  annotations:
    kubernetes.io/ingress.global-static-ip-name: smartcheck-address
    networking.gke.io/managed-certificates: smartcheck-certificate
    # ingress.kubernetes.io/backend-protocol: HTTPS
    # ingress.kubernetes.io/secure-backends: "true"
  labels:
    service: proxy
spec:
  backend:
    serviceName: proxy
    servicePort: 443
EOF

kubectl -n ${DSSC_NAMESPACE} apply -f smartcheck-managed-ingress.yml

cat <<EOF > smartcheck-registry-managed-ingress.yml
apiVersion: networking.k8s.io/v1beta1
kind: Ingress
metadata:
  name: proxy-ingress-registry
  annotations:
    kubernetes.io/ingress.global-static-ip-name: smartcheck-registry-address
    networking.gke.io/managed-certificates: smartcheck-registry-certificate
  labels:
    service: proxy
spec:
  backend:
    serviceName: proxy
    servicePort: 5000
EOF

kubectl -n ${DSSC_NAMESPACE} apply -f smartcheck-registry-managed-ingress.yml
```

It will take a couple of minutes (15 to 20) to get the certificates and the load balancer in configured active state. You can verify the status with

```shell
watch kubectl -n ${DSSC_NAMESPACE} describe managedcertificates
```

```text
Name:         smartcheck-certificate
Namespace:    smartcheck
Labels:       <none>
Annotations:  <none>
API Version:  networking.gke.io/v1beta2
Kind:         ManagedCertificate
Metadata:
  Creation Timestamp:  2020-09-10T10:40:51Z
  Generation:          2
  Resource Version:    295671
  Self Link:           /apis/networking.gke.io/v1beta2/namespaces/smartcheck/managedcertificates/smartcheck-certificate
  UID:                 a02673d9-27b9-4c8d-b7e6-7c2c597c979b
Spec:
  Domains:
    smartcheck-34-120-180-43.nip.io
Status:
  Certificate Name:    mcrt-dbc47353-86ef-423a-9aa1-d064ecba4318
  Certificate Status:  Provisioning
  Domain Status:
    Domain:  smartcheck-34-120-180-43.nip.io
    Status:  Provisioning
Events:
  Type    Reason  Age   From                            Message
  ----    ------  ----  ----                            -------
  Normal  Create  40s   managed-certificate-controller  Create SslCertificate mcrt-dbc47353-86ef-423a-9aa1-d064ecba4318
```

The certificate status should change to `Active` after some time.

---

Finally, run

```shell
curl -sSL https://raw.githubusercontent.com/mawinkler/devops-training/master/cloudone-image-security/deploy-ip.sh | bash
export DSSC_HOST_IP=$(kubectl get svc -n ${DSSC_NAMESPACE} proxy -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
export DSSC_HOST="https://smartcheck-${DSSC_HOST_IP//./-}.nip.io"
```

or

```shell
curl -sSL https://raw.githubusercontent.com/mawinkler/deploy/master/deploy-ip.sh | bash
export DSSC_HOST_IP=$(kubectl get svc -n ${DSSC_NAMESPACE} proxy -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
export DSSC_HOST="https://smartcheck-${DSSC_HOST_IP//./-}.nip.io"
```

## Configure CloudOne Application Security

Define the Application Security Key and Secret.

```shell
export TREND_AP_KEY=<YOUR CLOUD ONE APPLICATION SECURITY KEY>
export TREND_AP_SECRET=<YOUR CLOUD ONE APPLICATION SECURITY SECRET>
```

## Prepare the Cloud Build, Publishing and Kubernetes Deployment

### Fork Sample Repository

We are now going to fork the sample Kubernetes service so that we will be able modify the repository and trigger builds.

Login to GitHub and fork the Uploaders app:
<https://github.com/mawinkler/c1-app-sec-uploader>

And now clone it from your git:

```shell
export APP_NAME=c1-app-sec-uploader
git clone https://github.com/mawinkler/${APP_NAME}.git
cd ${APP_NAME}
```

### Create a Cloud Source Repository

```shell
gcloud source repos create ${APP_NAME}
git init
git config credential.helper gcloud.sh
git remote add gcp https://source.developers.google.com/p/${PROJECT}/r/${APP_NAME}
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
<https://source.developers.google.com/p/${PROJECT}/r/${APP_NAME}>

### Create Kubernetes Deployment and Service Definition

In the next chapters, we're defining everything which is required to run the pipeline in GCP Cloud Build. This includes the integration of Image Security and Application Security, of course.

First, we create our deployment and service manifests.

```shell
export IMAGE_NAME=${APP_NAME}
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
        env:
        - name: TREND_AP_KEY
          value: _TREND_AP_KEY
        - name: TREND_AP_SECRET
          value: _TREND_AP_SECRET
        imagePullPolicy: Always
        ports:
        - containerPort: 5000
EOF
```

### Create the Build Trigger

Here, we set up a build trigger to watch for changes in the source code version control system.

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
    "_CLOUDONE_PRESCAN_HOST": "smartcheck-registry-${DSSC_REG_HOST//./-}.nip.io",
    "_CLOUDONE_PRESCAN_USER": "${DSSC_REGUSER}",
    "_CLOUDONE_PRESCAN_PASSWORD": "${DSSC_REGPASSWORD}",
    "_CLOUDONE_TREND_AP_KEY": "${TREND_AP_KEY}",
    "_CLOUDONE_TREND_AP_SECRET": "${TREND_AP_SECRET}"
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

Lastly, we create the heart of the pipeline, the `cloudbuild.yaml`.

Still in our source directory, download and review the pipeline definition. Just look, do not change anything now.

```shell
curl -sSL https://raw.githubusercontent.com/mawinkler/devops-training/master/cloud-gcp/snippets/cloudbuild.yaml --output $cloudbuild.yaml

# or

curl -sSL https://raw.githubusercontent.com/mawinkler/deploy/master/cloudbuild.yaml --output cloudbuild.yaml
```

Populate the paramentes.

```shell
eval "cat <<EOF
$(<cloudbuild.yaml)
EOF
" 2> /dev/null > cloudbuild.yaml
```

## Trigger the Pipeline

```shell
git add .
git commit . -m "initial version"
git push gcp master
```

Query the Load Balancer IP by

```shell
kubectl -n ${APP_NAME} get services
```

## Knowledge

### Links

- <https://cloud.google.com/kubernetes-engine/docs/concepts/ingress>
- <https://cloud.google.com/kubernetes-engine/docs/how-to/load-balance-ingress>
- <https://cloud.google.com/kubernetes-engine/docs/concepts/ingress-xlb#setting_up_https_tls_between_client_and_load_balancer>
- <https://cloud.google.com/kubernetes-engine/docs/concepts/ingress-xlb#disabling_http>
- <https://cloud.google.com/kubernetes-engine/docs/concepts/ingress-xlb#https_tls_between_load_balancer_and_your_application>
- <https://cloud.google.com/kubernetes-engine/docs/tutorials/http-balancer>

### Ingress

As per the official definition, Ingress is an

*API object that manages external access to the services in a cluster, typically HTTP. Ingress can provide load balancing, SSL termination, and name-based virtual hosting*

One of the main use cases of ingress is, it allows users to access Kubernetes services from outside the Kubernetes cluster.

Ingress has 2 parts, ingress controller (there are many controllers) and ingress rules. We create ingress rules and we need a controller that satisfies and process those rules. Only applying ingress rules does not affect the cluster.

### Google-managed SSL certificate

Managed Certificate is a Custom Resource object created by google. This CRD allows users to automatically acquire an SSL certificate from a Certificate Authority, configure certificate on the load balancer and auto-renew it on time when it’s expired.

The process is super simple and users only need to provide a domain for which they want to obtain a certificate.

### Cloud Builders

Cloud builders are container images with common languages and tools installed in them. You can configure Cloud Build to run a specific command within the context of these builders.

This page describes the types of builders that you can use with Cloud Build.

<https://cloud.google.com/cloud-build/docs/cloud-builders>

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

### Delete a cluster

```shell
gcloud container clusters delete -q ${CLUSTER}
```

### Troubleshoot Google Cloud Build

Use debugging - To get additional information during the build process you can set the verbosity to debug:

```yaml
steps:
- name: 'gcr.io/cloud-builders/npm'
  args: ['install']
- name: "gcr.io/cloud-builders/gcloud"
  args: ['app', 'deploy', 'app.yaml', '--verbosity', 'debug']
```

Use cloud-build-local - It is possible to run the exact same build process which runs in Cloud Build on your local machine. Please keep in mind Docker is required.

```shell
cloud-build-local --config=cloudbuild.yaml .
```

or

```shell
cloud-build-local --config=cloudbuild.yaml \
  --dryrun=false \
  --push .
```

## Pipelines

### Var 1

```yaml
steps:

### Build

  - id: 'build'
    name: 'gcr.io/cloud-builders/docker'
    args: ['build', '-t', 'gcr.io/devtest-285306/c1-app-sec-uploader:latest', '.']

### Scan

  - id: 'scan'
    name: 'gcr.io/cloud-builders/docker'
    env:
      - 'CLOUDONE_IMAGESECURITY_HOST=${_CLOUDONE_IMAGESECURITY_HOST}'
      - 'CLOUDONE_IMAGESECURITY_USER=${_CLOUDONE_IMAGESECURITY_USER}'
      - 'CLOUDONE_IMAGESECURITY_PASSWORD=${_CLOUDONE_IMAGESECURITY_PASSWORD}'
      - 'CLOUDONE_PRESCAN_USER=${_CLOUDONE_PRESCAN_USER}'
      - 'CLOUDONE_PRESCAN_PASSWORD=${_CLOUDONE_PRESCAN_PASSWORD}'
      - 'DOCKER_TLS_CERTDIR=/usr/local/share/ca-certificates'
    entrypoint: 'bash'
    args:
      - '-c'
      - |
          openssl s_client -showcerts -connect $${CLOUDONE_IMAGESECURITY_HOST}:443 < /dev/null | \
            sed -ne '/-BEGIN CERTIFICATE-/,/-END CERTIFICATE-/p' > /usr/local/share/ca-certificates/$${CLOUDONE_IMAGESECURITY_HOST}.crt
          update-ca-certificates

          echo $${CLOUDONE_PRESCAN_PASSWORD} | docker login $${CLOUDONE_IMAGESECURITY_HOST}:5000 --username $${CLOUDONE_PRESCAN_USER} --password-stdin
          cat /proc/self/mounts

          docker run  -v /var/run/docker.sock:/var/run/docker.sock \
            -v /home/marwin_mu/.cache:/root/.cache/ deepsecurity/smartcheck-scan-action \
            --preregistry-scan \
            --preregistry-host=$${CLOUDONE_IMAGESECURITY_HOST} \
            --preregistry-user=$${CLOUDONE_PRESCAN_USER} \
            --preregistry-password=$${CLOUDONE_PRESCAN_PASSWORD} \
            --image-name=gcr.io/devtest-285306/c1-app-sec-uploader:latest \
            --smartcheck-host=$${CLOUDONE_IMAGESECURITY_HOST} \
            --smartcheck-user=$${CLOUDONE_IMAGESECURITY_USER} \
            --smartcheck-password=$${CLOUDONE_IMAGESECURITY_PASSWORD} \
            --insecure-skip-tls-verify \
            --insecure-skip-registry-tls-verify \
            --findings-threshold='{"malware": 200, "vulnerabilities": { "defcon1": 0, "critical": 0, "high": 1 }, "contents": { "defcon1": 0, "critical": 0, "high": 0 }, "checklists": { "defcon1": 0, "critical": 0, "high": 0 }}'

### Publish
  - id: 'publish'
    name: 'gcr.io/cloud-builders/docker'
    #entrypoint: 'bash'
    args: ['push', 'gcr.io/devtest-285306/c1-app-sec-uploader:latest']
    #args:
    #  - '-c'
    #  - |
    #      docker push gcr.io/devtest-285306/c1-app-sec-uploader:latest

### Deploy
  - id: 'deploy'
    name: 'gcr.io/google.com/cloudsdktool/cloud-sdk'
    env:
      - 'CLOUDSDK_COMPUTE_ZONE=${_CLOUDSDK_COMPUTE_ZONE}'
      - 'CLOUDSDK_CONTAINER_CLUSTER=${_CLOUDSDK_CONTAINER_CLUSTER}'
      - 'KUBECONFIG=/kube/config'
    entrypoint: 'bash'
    args:
      - '-c'
      - |
          CLUSTER=$(gcloud config get-value container/cluster)
          PROJECT=$(gcloud config get-value core/project)
          ZONE=$(gcloud config get-value compute/zone)

          gcloud container clusters get-credentials "$${CLUSTER}"             --project "$${PROJECT}"             --zone "$${ZONE}"  

          sed -i 's|gcr.io/PROJECT/IMAGE_NAME:IMAGE_TAG|gcr.io/devtest-285306/c1-app-sec-uploader:latest|' ./app-gcp.yml

          kubectl get ns c1-app-sec-uploader || kubectl create ns c1-app-sec-uploader
          kubectl apply --namespace c1-app-sec-uploader -f app-gcp.yml
```

### Var 2

```yaml
  - id: 'scan'
    # name: 'gcr.io/cloud-builders/docker'
    name: 'deepsecurity/smartcheck-scan-action'
    env:
      - 'CLOUDONE_IMAGESECURITY_HOST=${_CLOUDONE_IMAGESECURITY_HOST}'
      - 'CLOUDONE_IMAGESECURITY_USER=${_CLOUDONE_IMAGESECURITY_USER}'
      - 'CLOUDONE_IMAGESECURITY_PASSWORD=${_CLOUDONE_IMAGESECURITY_PASSWORD}'
      - 'CLOUDONE_PRESCAN_USER=${_CLOUDONE_PRESCAN_USER}'
      - 'CLOUDONE_PRESCAN_PASSWORD=${_CLOUDONE_PRESCAN_PASSWORD}'
    entrypoint: 'sh'
    args:
      - '-c'
      - |
          openssl s_client -showcerts -connect $${CLOUDONE_IMAGESECURITY_HOST}:443 < /dev/null | \
            sed -ne '/-BEGIN CERTIFICATE-/,/-END CERTIFICATE-/p' > /usr/local/share/ca-certificates/$${CLOUDONE_IMAGESECURITY_HOST}.crt
          update-ca-certificates

          node /app/dist/index.js --preregistry-scan \
            --preregistry-password=$${CLOUDONE_PRESCAN_PASSWORD} \
            --preregistry-user=$${CLOUDONE_PRESCAN_USER} \
            --image-name=gcr.io/devtest-285306/c1-app-sec-uploader:latest \
            --smartcheck-host=$${CLOUDONE_IMAGESECURITY_HOST} \
            --smartcheck-user=$${CLOUDONE_IMAGESECURITY_USER} \
            --smartcheck-password=$${CLOUDONE_IMAGESECURITY_PASSWORD} \
            --insecure-skip-tls-verify \
            --insecure-skip-registry-tls-verify \
            --findings-threshold='{"malware": 200, "vulnerabilities": { "defcon1": 0, "critical": 0, "high": 1 }, "contents": { "defcon1": 0, "critical": 0, "high": 0 }, "checklists": { "defcon1": 0, "critical": 0, "high": 0 }}'
```

### Var 3

```yaml
  - id: 'scan'
    # name: 'gcr.io/cloud-builders/docker'
    name: 'deepsecurity/smartcheck-scan-action'
    env:
      - 'CLOUDONE_IMAGESECURITY_HOST=${_CLOUDONE_IMAGESECURITY_HOST}'
      - 'CLOUDONE_IMAGESECURITY_USER=${_CLOUDONE_IMAGESECURITY_USER}'
      - 'CLOUDONE_IMAGESECURITY_PASSWORD=${_CLOUDONE_IMAGESECURITY_PASSWORD}'
      - 'CLOUDONE_PRESCAN_USER=${_CLOUDONE_PRESCAN_USER}'
      - 'CLOUDONE_PRESCAN_PASSWORD=${_CLOUDONE_PRESCAN_PASSWORD}'
      - 'SSL_CERT_FILE=/usr/local/share/ca-certificates/${_CLOUDONE_IMAGESECURITY_HOST}.crt'
      - 'NODE_EXTRA_CA_CERTS=/usr/local/share/ca-certificates/${_CLOUDONE_IMAGESECURITY_HOST}.crt'
    entrypoint: 'sh'
    args:
      - '-c'
      - |
          apk update
          apk add ca-certificates openssl

          mkdir -p /usr/local/share/ca-certificates
          openssl s_client -showcerts -connect $${CLOUDONE_IMAGESECURITY_HOST}:443 < /dev/null | \
            sed -ne '/-BEGIN CERTIFICATE-/,/-END CERTIFICATE-/p' > /usr/local/share/ca-certificates/$${CLOUDONE_IMAGESECURITY_HOST}.crt
          update-ca-certificates

          npm config set cafile /usr/local/share/ca-certificates/$${CLOUDONE_IMAGESECURITY_HOST}.crt

          echo $${NODE_EXTRA_CA_CERTS}

          node /app/dist/index.js \
            --use-openssl-ca \
            --preregistry-scan \
            --preregistry-password=$${CLOUDONE_PRESCAN_PASSWORD} \
            --preregistry-user=$${CLOUDONE_PRESCAN_USER} \
            --image-name=gcr.io/devtest-285306/c1-app-sec-uploader:latest \
            --smartcheck-host=$${CLOUDONE_IMAGESECURITY_HOST} \
            --smartcheck-user=$${CLOUDONE_IMAGESECURITY_USER} \
            --smartcheck-password=$${CLOUDONE_IMAGESECURITY_PASSWORD} \
            --insecure-skip-tls-verify \
            --insecure-skip-registry-tls-verify \
            --findings-threshold='{"malware": 200, "vulnerabilities": { "defcon1": 0, "critical": 0, "high": 1 }, "contents": { "defcon1": 0, "critical": 0, "high": 0 }, "checklists": { "defcon1": 0, "critical": 0, "high": 0 }}'
```

### Var 4

```yaml
steps:

### Build

  - id: 'build'
    name: 'gcr.io/cloud-builders/docker'
    args: ['build', '-t', 'gcr.io/devtest-285306/c1-app-sec-uploader:latest', '.']

### Scan

  - id: 'scan'
    name: 'gcr.io/cloud-builders/docker'
    env:
      - 'CLOUDONE_IMAGESECURITY_HOST=${_CLOUDONE_IMAGESECURITY_HOST}'
      - 'CLOUDONE_IMAGESECURITY_USER=${_CLOUDONE_IMAGESECURITY_USER}'
      - 'CLOUDONE_IMAGESECURITY_PASSWORD=${_CLOUDONE_IMAGESECURITY_PASSWORD}'
      - 'CLOUDONE_PRESCAN_USER=${_CLOUDONE_PRESCAN_USER}'
      - 'CLOUDONE_PRESCAN_PASSWORD=${_CLOUDONE_PRESCAN_PASSWORD}'
      - 'DOCKER_TLS_CERTDIR=/usr/local/share/ca-certificates'
    entrypoint: 'bash'
    args:
      - '-c'
      - |
          openssl s_client -showcerts -connect $${CLOUDONE_IMAGESECURITY_HOST}:5000 < /dev/null | \
            sed -ne '/-BEGIN CERTIFICATE-/,/-END CERTIFICATE-/p' > /usr/local/share/ca-certificates/$${CLOUDONE_IMAGESECURITY_HOST}.crt

          mkdir -p /etc/docker/certs.d/$${CLOUDONE_IMAGESECURITY_HOST}:5000
          cp /usr/local/share/ca-certificates/$${CLOUDONE_IMAGESECURITY_HOST}.crt /etc/docker/certs.d/$${CLOUDONE_IMAGESECURITY_HOST}:5000/ca.crt

          update-ca-certificates
          /etc/init.d/docker restart

          echo $${CLOUDONE_PRESCAN_PASSWORD} | docker login $${CLOUDONE_IMAGESECURITY_HOST}:5000 --username $${CLOUDONE_PRESCAN_USER} --password-stdin

          docker run  -v /var/run/docker.sock:/var/run/docker.sock \
            -v /home/marwin_mu/.cache:/root/.cache/ deepsecurity/smartcheck-scan-action \
            --preregistry-scan \
            --preregistry-password=$${CLOUDONE_PRESCAN_PASSWORD} \
            --preregistry-user=$${CLOUDONE_PRESCAN_USER} \
            --image-name=gcr.io/devtest-285306/c1-app-sec-uploader:latest \
            --smartcheck-host=$${CLOUDONE_IMAGESECURITY_HOST} \
            --smartcheck-user=$${CLOUDONE_IMAGESECURITY_USER} \
            --smartcheck-password=$${CLOUDONE_IMAGESECURITY_PASSWORD} \
            --insecure-skip-tls-verify \
            --insecure-skip-registry-tls-verify \
            --findings-threshold='{"malware": 200, "vulnerabilities": { "defcon1": 0, "critical": 0, "high": 1 }, "contents": { "defcon1": 0, "critical": 0, "high": 0 }, "checklists": { "defcon1": 0, "critical": 0, "high": 0 }}'

### Publish
  - id: 'publish'
    name: 'gcr.io/cloud-builders/docker'
    #entrypoint: 'bash'
    args: ['push', 'gcr.io/devtest-285306/c1-app-sec-uploader:latest']
    #args:
    #  - '-c'
    #  - |
    #      docker push gcr.io/devtest-285306/c1-app-sec-uploader:latest

### Deploy
  - id: 'deploy'
    name: 'gcr.io/google.com/cloudsdktool/cloud-sdk'
    env:
      - 'CLOUDSDK_COMPUTE_ZONE=${_CLOUDSDK_COMPUTE_ZONE}'
      - 'CLOUDSDK_CONTAINER_CLUSTER=${_CLOUDSDK_CONTAINER_CLUSTER}'
      - 'KUBECONFIG=/kube/config'
    entrypoint: 'bash'
    args:
      - '-c'
      - |
          CLUSTER=$(gcloud config get-value container/cluster)
          PROJECT=$(gcloud config get-value core/project)
          ZONE=$(gcloud config get-value compute/zone)

          gcloud container clusters get-credentials "$${CLUSTER}"             --project "$${PROJECT}"             --zone "$${ZONE}"  

          sed -i 's|gcr.io/PROJECT/IMAGE_NAME:IMAGE_TAG|gcr.io/devtest-285306/c1-app-sec-uploader:latest|' ./app-gcp.yml

          kubectl get ns c1-app-sec-uploader || kubectl create ns c1-app-sec-uploader
          kubectl apply --namespace c1-app-sec-uploader -f app-gcp.yml
```