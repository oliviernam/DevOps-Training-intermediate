# Issue 1

Hi Experts,

I need to authenticate to a private registry with a self signed certificate during a Cloud Build step. If I directly execute a `docker login`, for obvious reasons, this fails with an `error: x509: certificate signed by unknown authority` - all fine.

Typically, I'm resolving these kind of issues with the following one-liner:

```shell
openssl s_client -showcerts -connect external-registry.io:5000 < /dev/null | \
    sed -ne '/-BEGIN CERTIFICATE-/,/-END CERTIFICATE-/p' > /usr/local/share/ca-certificates/external-registry.io.crt && \
    update-ca-certificates
```

Sadly, it doesn't work in Cloud Build.

```yaml
name: 'gcr.io/cloud-builders/docker'
env:
entrypoint: 'bash'
args:
    - '-c'
    - |
        openssl s_client -showcerts -connect external-registry.io:5000 < /dev/null | \
            sed -ne '/-BEGIN CERTIFICATE-/,/-END CERTIFICATE-/p' > /usr/local/share/ca-certificates/external-registry.io.crt && \
            update-ca-certificates

        echo password | docker login external-registry.io:5000 --username administrator --password-stdin
        ...
```

The above doesn't work, it fails with `error: x509: certificate signed by unknown authority`.

Interestingly, running the cloud-builders docker container locally everything works flawlessly as expected.

```shell
git clone https://github.com/GoogleCloudPlatform/cloud-builders.git
cd cloud-builders/docker
docker build -f ./Dockerfile-19.03.8 -t cloudbuilder .
docker run -it --entrypoint /bin/bash cloudbuilder
```

now inside the container:

```shell
openssl s_client -showcerts -connect external-registry.io:5000 < /dev/null | \
    sed -ne '/-BEGIN CERTIFICATE-/,/-END CERTIFICATE-/p' > /usr/local/share/ca-certificates/external-registry.io.crt && \
    update-ca-certificates

echo password | docker login external-registry.io:5000 --username administrator --password-stdin

Login Succeeded
```

Any explanation and / or workaround would be very appreciated. How is Google running the cloud-builder containers effectively?

Thank you and cheers!



I tested this with the image `gcr.io/cloud-builders/docker`, but it doesn't work in Cloud Build.