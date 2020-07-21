# CI/CD with GCP Cloud Build

- [CI/CD with GCP Cloud Build](#cicd-with-gcp-cloud-build)
  - [Prerequisites](#prerequisites)
  - [Create a Workspace](#create-a-workspace)
  - [Prepare for GKE Cluster](#prepare-for-gke-cluster)
  - [Create GKE Cluster](#create-gke-cluster)
  - [Deploy CloudOne Image Security](#deploy-cloudone-image-security)
  - [Create Repository to Host the App Code](#create-repository-to-host-the-app-code)
    - [Fork Sample Repository](#fork-sample-repository)

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

Command output:

```code
 Credentialed Accounts
ACTIVE  ACCOUNT
*       <my_account>@<my_domain.com>

To set the active account, run:
    $ gcloud config set account `ACCOUNT`
```

Note: The gcloud command-line tool is the powerful and unified command-line tool in Google Cloud. It comes preinstalled in Cloud Shell. You will notice its support for tab completion. For more information, see gcloud command-line tool overview.

```shell
gcloud config list project
```

Command output

```code
[core]
project = <PROJECT_ID>

Your active configuration is: [cloudshell-XXXXX]
```

If it is not, you can set it with this command:

```shell
gcloud config set project <PROJECT_ID>
```

## Prepare for GKE Cluster

Set up some variables.

```shell
export PROJECT=$(gcloud info --format='value(config.project)')
export ZONE=us-central1-b
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

gcloud projects add-iam-policy-binding ${PROJECT} \
    --member=serviceAccount:${PROJECT_NUMBER}@cloudbuild.gserviceaccount.com \
    --role=roles/container.developer
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
helm install -n ${DSSC_NAMESPACE} --values overrides.yml deepsecurity-smartcheck https://github.com/deep-security/smartcheck-helm/archive/master.tar.gz
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

## Create Repository to Host the App Code

### Fork Sample Repository

We are now going to fork the sample Kubernetes service so that we will be able modify the repository and trigger builds.

Login to GitHub and fork the Troopers app:

<https://github.com/mawinkler/troopers>


