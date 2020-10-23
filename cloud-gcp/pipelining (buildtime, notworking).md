# CI/CD with GCP Cloud Build

- [CI/CD with GCP Cloud Build](#cicd-with-gcp-cloud-build)
  - [TODO](#todo)
  - [Deploy CloudOne Image Security](#deploy-cloudone-image-security)
  - [Pipelines](#pipelines)
    - [Var 1](#var-1)
    - [Var 2](#var-2)
    - [Var 3](#var-3)
    - [Var 4](#var-4)

## TODO

- Solve Certificate issue

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