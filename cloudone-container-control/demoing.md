# Container Security Demoing

- [Container Security Demoing](#container-security-demoing)
  - [If you need a cluster...](#if-you-need-a-cluster)
  - [Deploy Container Control](#deploy-container-control)
  - [Demo Container Control with Smart Check](#demo-container-control-with-smart-check)
  - [Demo Namespace Exclusions](#demo-namespace-exclusions)
  - [Explore](#explore)
  - [Appendix](#appendix)
    - [Nginx with three Replicas](#nginx-with-three-replicas)

## If you need a cluster...

There are multiple ways to demo Container Control, whereby the variant with the greatest flexibility would be MOADSD-NG.
If that is to heavy, you can quickly run the script `rapid-gke.sh` from within a shell, authenticated to GCP.

```sh
../cloud-gcp/rapid-gke.sh
```

This will create a fresh cluster on GCP.

## Deploy Container Control

The deployment is typically a two step process:

1. Deployment of the policy-based deployment controller
2. Integration with Smart Check

Follow the steps described [here](https://cloudone.trendmicro.com/docs/container-security/get-started/#install-the-policy-based-deployment-controller) and [here](https://cloudone.trendmicro.com/docs/container-security/get-started/#integrate-with-deep-security-smart-check).

Then, create a policy (only one possible) for your cluster.

Be very careful with the `Images that are not scanned` check box. You should check that, but you should monitor your cluster a little to see if blocked events show up. If that is the case, do the following:

1. Identify the namespace(s) of the blocked pod(s)
2. run `kubectl label ns <NAMESPACE> ignoreAdmissionControl=true --overwrite`

If the Container Control turns quiet, you should be able to continue within the lab.

## Demo Container Control with Smart Check

Ensure to have the block rule `Images that are not scanned` applied to your Container Control policy.

Then, run a pod with an unchecked image, e.g.

```sh
export TARGET_IMAGE=busybox
export TARGET_IMAGE_TAG=latest

kubectl create ns ${IMAGE}
kubectl run -n ${IMAGE} --image=${IMAGE} --generator=run-pod/v1 ${IMAGE}
```

This should lead to an an error in the console and an event in Container Security.

Then let Smart Check scan the image

```sh
export DSSC_REGISTRY="<smart check preregistry url:port>"
export DSSC_SERVICE="<smart check url:port>"
export DSSC_USERNAME="<smart check username>"
export DSSC_PASSWORD="<smart check password>"
export DSSC_REGISTRY_USERNAME="<smart check preregistry username>"
export DSSC_REGISTRY_PASSWORD="<smart check preregistry password>"

docker pull ${TARGET_IMAGE}:${TARGET_IMAGE_TAG}

docker run -v /var/run/docker.sock:/var/run/docker.sock \
  deepsecurity/smartcheck-scan-action \
  --image-name "${TARGET_IMAGE}:${TARGET_IMAGE_TAG}" \
  --preregistry-host="${DSSC_REGISTRY}" \
  --smartcheck-host="${DSSC_SERVICE}" \
  --smartcheck-user="${DSSC_USERNAME}" \
  --smartcheck-password="${DSSC_PASSWORD}" \
  --insecure-skip-tls-verify \
  --preregistry-scan \
  --preregistry-user "${DSSC_REGISTRY_USERNAME}" \
  --preregistry-password "${DSSC_REGISTRY_PASSWORD}"

docker run mawinkler/scan-report:dev -O \
  --name "${TARGET_IMAGE}" \
  --image_tag "${TARGET_IMAGE_TAG}" \
  --service "${DSSC_SERVICE}" \
  --username "${DSSC_USERNAME}" \
  --password "${DSSC_PASSWORD}" > report_${TARGET_IMAGE}.pdf
```

Now, rerun

```sh
kubectl run -n ${IMAGE} --image=${IMAGE} --generator=run-pod/v1 ${IMAGE}
```

It should now work, at least in regards the `Images that are not scanned`. It will eventually still be blocked depending on the other settings of your policy.

## Demo Namespace Exclusions

Ensure to have the block rule `Images that are not scanned` applied to your Container Control policy, as above,

Create a namespace for a different pod and try to deploy it

```sh
export TARGET_IMAGE=nginx
export TARGET_IMAGE_TAG=latest

kubectl create ns ${IMAGE}
kubectl run -n ${IMAGE} --image=${IMAGE} --generator=run-pod/v1 ${IMAGE}
```

The above should fail.

If you want to exclude a namespace from admission control, label it

```sh
kubectl label ns ${IMAGE} ignoreAdmissionControl=true --overwrite

kubectl get ns --show-labels

kubectl run -n ${IMAGE} --image=${IMAGE} --generator=run-pod/v1 ${IMAGE}
```

This should now work, because Container Control is ignoring the labeled namespace.

## Explore

The potentially most interesting part on your cluster (in reagards Container Control) is the ValidatingWebhookConfiguration. Review and understand it.

```sh
kubectl get ValidatingWebhookConfiguration
kubectl edit ValidatingWebhookConfiguration trendmicro-trendmicro-admission-controller

helm inspect values https://github.com/trendmicro/cloudone-admission-controller-helm/archive/master.tar.gz
```

If you're running MOADSD-NG and have OPA deployed, you can compare the webhooks. They look pretty similar, or?

```sh
kubectl edit ValidatingWebhookConfiguration opa-validating-webhook
```

## Appendix

### Nginx with three Replicas

```sh
cat <<EOF > nginx.yml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
  labels:
    app: nginx
spec:
  replicas: 3
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx:1.14.2
        ports:
        - containerPort: 80
EOF

kubectl apply -n nginx -f nginx.yml
```
