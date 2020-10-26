# DevOps Intermediate Training - Cloud One Smart Check

- [DevOps Intermediate Training - Cloud One Smart Check](#devops-intermediate-training---cloud-one-smart-check)
  - [Objective](#objective)
  - [Prerequisites](#prerequisites)
  - [Files](#files)

## Objective

This folder does contain some scripts to ease a Smart Check deployment in different environments. The deployment scripts are all capable of doing the initially required password change.

Please use `deploy-dns.sh` when the load balancer in the target environment uses a public DNS name (e.g. in AWS).

Use `deploy-ip.sh` if you only have an IP from the load balancer (e.g. in Azure).

The scripts `deploy-ng.sh` and `deploy-cpw.sh` do belong together. The first one deploys Smart Check as service of type `NodePort`. You will then need to create a publicly available service endpoint for Smart Check yourself. Do this for example by creating an ingress or setting up a proxy. Afterwards, the script `deploy-cpw.sh` can be used to do the password change. (e.g. in GCP)

All scripts require to have the following environment variables set:

Key | Value
--- | -----
`DSSC_NAMESPACE` | e.g. `smartcheck`
`DSSC_USERNAME` | e.g. `admin`
`DSSC_PASSWORD`| e.g. `trendmicro`
`DSSC_REGUSER` | e.g. `administrator`
`DSSC_REGPASSWORD` | e.g. `trendmicro`
`DSSC_AC` | `<SMART CHECK ACTIVATION CODE>`

The script `deploy-cpw.sh` requires the additional variable `DSSC_HOST` to be set to the IP of the load balancer.

## Prerequisites

- Smart Check license
- Optional: Multi Cloud Shell

## Files

The file `values.yml` does contain all possible settings for a Smart Check deployment as of version 1.2.51. The file got created with the following command:

```sh
helm inspect values https://github.com/deep-security/smartcheck-helm/archive/1.2.51.tar.gz > values.yml
```

During the cloud-labs, the following deploy-scripts are used:

`deploy-dns.sh` (AWS)

```sh
curl -sSL https://gist.githubusercontent.com/mawinkler/68391667fdfe98d9294417f3a24d337b/raw --output deploy-dns.sh
```

`deploy-ip.sh` (Azure)

```sh
curl -sSL https://gist.githubusercontent.com/mawinkler/7b9cc48a8b2cf96e07e4eadd6e8e9497/raw --output deploy-ip.sh
```

`deploy-np.sh` (GCP)

```sh
curl -sSL https://gist.githubusercontent.com/mawinkler/5421b398d4f46073f5f854d0485987bc/raw --output deploy-np.sh
```

`deploy-cpw.sh`: (GCP)

```sh
curl -sSL https://gist.githubusercontent.com/mawinkler/9a64134f1398d09f69e6c8549cf80755/raw --output deploy-cpw.sh
```
