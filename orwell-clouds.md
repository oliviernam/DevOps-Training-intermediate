# All are equal, but some are more equal than others

- [All are equal, but some are more equal than others](#all-are-equal-but-some-are-more-equal-than-others)
  - [Services Cross Cloud](#services-cross-cloud)
  - [Links](#links)

The table below lists the more or less same services by the public cloud. Here, I'm covering only the most relevant services for the labs, since AWS alone has more than 200 services...

## Services Cross Cloud

Kind | AWS | Azure | GCP
---- | --- | ----- | ---
Managed Kubernetes Cluster | Elastic Kubernetes Services | Kubernetes Service | Kubernetes Engine
Container Registry | Elastic Container Registry | Container Registry | Container Registry
Stateless Containers | Elastic Container Service | Container Instances | Cloud Run
|||
Virtual Server | Amazon EC2 | Virtual Machine | Compute Engine
|||
Object Storage | Simple Storage Service | Blob Storage | Cloud Storage
File Storage | Elastic File System | File Storage | File Store
Virtual Disk Storage | Elastic Block Storage | Premium Storage | Persistent Disk
|||
Serverless Applications | EKS on Fargate | App Service | App Engine
Serverless Functions | Lambda | Service Fabric / Functions | Cloud Functions
Source Code Version Control | CodeCommit | Repos | Cloud Source Repository
Pipeline | CodePipeline | Pipelines | Cloud Build
Build Specification | `buildspec.yml` | `azure-pipelines.yml` | `cloudbuild.yaml`
Interactive Shell | Cloud9 | Cloud Shell | Cloud Shell
Command Line Interface | `aws` | `az` | `gcloud`

## Links

- [AWS Services](https://docs.aws.amazon.com/)
- [Azure Services](https://docs.microsoft.com/en-in/azure/?product=all)
- [Google Services](https://cloud.google.com/docs)