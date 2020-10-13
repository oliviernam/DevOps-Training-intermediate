# Theory

- [Theory](#theory)
  - [Services - Containers](#services---containers)
    - [The Google Way](#the-google-way)
    - [GKE](#gke)
      - [Kubernetes Engine Features](#kubernetes-engine-features)
      - [The Complete Container Solution](#the-complete-container-solution)
  - [Services - Serverless](#services---serverless)
    - [Cloud Run](#cloud-run)
    - [App Engine](#app-engine)
    - [Cloud Functions](#cloud-functions)
    - [Knative](#knative)
  - [Services - DevOps](#services---devops)
    - [Project](#project)
    - [Cloud Source Repository](#cloud-source-repository)
    - [Cloud Build](#cloud-build)
    - [Build Trigger](#build-trigger)
    - [Build Specification cloudbuild.yaml](#build-specification-cloudbuildyaml)
  - [Misc Knowledge, Tools and Services](#misc-knowledge-tools-and-services)
    - [Cloud Shell](#cloud-shell)

This document covers most of the technologies and GCP services used within the CI/CD Pipelining Lab on Google Cloud. Lot's of links for more in depth information are given. A good starting point in regards documentation is here: <https://cloud.google.com/docs>.

## Services - Containers

### The Google Way

From Gmail to YouTube to Search, everything at Google runs in containers. Containerization allows our development teams to move fast, deploy software efficiently, and operate at an unprecedented scale. Each week, we start over several billion containers. We’ve learned a lot about running containerized workloads in production over the past decade, and we’ve shared this knowledge with the community along the way: from the early days of contributing cgroups to the Linux kernel, to taking designs from our internal tools and open sourcing them as the Kubernetes project. We’ve packaged this expertise into Google Cloud Platform so that developers and businesses of any size can easily tap the latest in container innovation.

### GKE

Kubernetes Engine is fully managed by Google reliability engineers, the ones who know containers the best, ensuring your cluster is highly available and up-to-date. It integrates seamlessly with all GCP services, such as Stackdriver monitoring, diagnostics, and logging; Identity and Access Management; and Google’s best-in-class networking infrastructure.

#### Kubernetes Engine Features

- Managed open-source Kubernetes
- 99.5% SLA, and high availability with integrated multi-zone deployments
- Seamless integration of other GCP services
- Industry leading price per performance
- Flexible & interoperable with your on-premises clusters or other cloud providers
- Google-grade managed-infrastructure

But we love to give you options. Google Cloud Platform offers you a full spectrum for running your containers. From fully managed environment with Google Cloud Run to cluster management with Kubernetes Engine to roll-it-yourself infrastructure on world-class price-to-performance Google Compute Engine, you can find your ideal solution for running containers on Google Cloud Platform.

![alt text](images/your-cluster-2x.png "Google Cloud Platform")

#### The Complete Container Solution

It doesn’t stop there. Google Cloud Platform provides the tools you need to use containers from development to production. Cloud Build and Container Registry provide Docker image storage and management, backed by both Google’s high security standards and world-class network. Google’s Container-Optimized OS provides a lightweight, highly secure operating system that comes with the Docker and Kubernetes runtimes pre-installed. All your container management can take place on GCP.

![alt text](images/complete-container-solution-2x.png "Google Container Solution")

## Services - Serverless

### Cloud Run

### App Engine

### Cloud Functions

### Knative


## Services - DevOps

### Project

### Cloud Source Repository

### Cloud Build

### Build Trigger

### Build Specification cloudbuild.yaml

## Misc Knowledge, Tools and Services

### Cloud Shell
