# DevOps Intermediate Training - AWS Pipelining Lab

- [DevOps Intermediate Training - AWS Pipelining Lab](#devops-intermediate-training---aws-pipelining-lab)
  - [Lab Objective](#lab-objective)
  - [Prerequisites](#prerequisites)
  - [Files](#files)

## Lab Objective

The AWS Pipeline Lab will guide you step-by-step through the process of setting up a CI/CD-Pipeline with the AWS native services and tools. You're integrating Smart Check pre-registry scanning and Cloud One Application Security into the pipeline.

## Prerequisites

- AWS Subscription
- Smart Check license
- Cloud One Application Security
- Optional: Multi Cloud Shell

## Files

- [Lab](./pipelining.md)
- [Theory](./theory.md)

During the lab you're downloading three files from my gists:

`app-pipeline.cfn.yml`

```sh
curl -sSL https://gist.githubusercontent.com/mawinkler/8f208b2fc73209bc99013f60dcc81679/raw --output app-pipeline.cfn.yml
```

`buildspec.yml`

```sh
curl -sSL https://gist.githubusercontent.com/mawinkler/f7d271ea2b821cfd29b53d6c950cac8a/raw --output buildspec.yml
```

`app-eks.yml`

```sh
curl -sSL https://gist.githubusercontent.com/mawinkler/f553ada2dd083558befd484eeb7c8845/raw --output app-eks.yml
```
