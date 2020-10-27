# Container Security Demoing

- [Container Security Demoing](#container-security-demoing)
  - [If you need a cluster...](#if-you-need-a-cluster)
  - [Explore](#explore)
  - [Demo Namespace Exclusions](#demo-namespace-exclusions)
  - [Appendix](#appendix)
    - [Nginx with three Replicas](#nginx-with-three-replicas)

## If you need a cluster...

Run the script `rapid-gke.sh` from within a shell, authenticated to GCP. The script is here: 

```sh
../cloud-gcp/rapid-gke.sh
```

## Explore

```sh
kubectl get ValidatingWebhookConfiguration
kubectl edit ValidatingWebhookConfiguration trendmicro-trendmicro-admission-controller

helm inspect values https://github.com/trendmicro/cloudone-admission-controller-helm/archive/master.tar.gz
```

If you're running MOADSD-NG and have OPA deployed, you can compare the webhooks. They look pretty similar, or?

```sh
kubectl edit ValidatingWebhookConfiguration opa-validating-webhook
```

## Demo Namespace Exclusions

*Configure Container Control policy to not allow unscanned images*

Create a namespace for nginx and try to deploy it

```sh
kubectl create ns nginx

kubectl run -n nginx --image=nginx --generator=run-pod/v1 nginx
```

The above should fail.

If you want to exclude a namespace from admission control, label it

```sh
kubectl label ns nginx ignoreAdmissionControl=true --overwrite

kubectl get ns --show-labels

kubectl run -n nginx --image=nginx --generator=run-pod/v1 nginx
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
