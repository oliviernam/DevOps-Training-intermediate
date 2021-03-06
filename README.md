# DevOps Intermediate Training

- [DevOps Intermediate Training](#devops-intermediate-training)
  - [Course Description](#course-description)
    - [Target Audience](#target-audience)
    - [Prerequisites](#prerequisites)
    - [Course Objectives](#course-objectives)
    - [Training Topics](#training-topics)
    - [Agenda](#agenda)
  - [Before you start](#before-you-start)
    - [1. Clone the DevOps Training Material](#1-clone-the-devops-training-material)
    - [2. (Optional) Create your Multi Cloud Shell Container](#2-optional-create-your-multi-cloud-shell-container)

## Course Description

The DevOps Intermediate Training is a three days instructor led course. Participants will learn how to demo Trend Micro Cloud One security services from a DevOps perspective. The course discusses automation using continuous integration and delivery (CI/CD) pipelines using AWS CodePipeline, Azure Pipelines and GCP Cloud Build. This course incorporates a variety of hands-on lab exercises, allowing participants to put the lesson content into action.

### Target Audience

Sales Engineers

### Prerequisites

Participants must have experience with the topics of the DevOps Foundation Training prior to attending the DevOps Intermediate course. Especially, profound experience with Containers, Kubernetes and CI/CD Pipelines is required.
Participants are required to bring a laptop computer with a recommended screen resolution of at least 1980 x 1080 or above.
Important: Valid subscriptions for AWS, GCP and Azure are required.

### Course Objectives

After completing this training course participants will be able to:

- Demo Cloud One within the three major public cloud platforms (AWS, GCP & Azure)
- Demo and understand Cloud One Application Security, Conformity, File Storage Security and Container Security

### Training Topics

- Demoing Cloud One Conformity
- Demoing Cloud One File Storage Security
- Demoing Cloud One Application Security (applications and serverless)
- Demoing Cloud One Container Control
- CI/CD w/AWS CodePipeline
- CI/CD w/Azure Pipelines
- CI/CD w/GCP Cloud Build
- K8s Admission Controllers
- MOADSD-NG Use cases and Best Practices
- Cloud One Smart Check – Reporting and Installation Scripts

### Agenda

**Day 1** |
----- |
[C1 Conformity](./cloudone-conformity/README.md) - Demoing |
[C1 File Storage Security](./cloudone-file-storage-security/README.md) - Demoing |
[AWS Pipelining](./cloud-aws/README.md) - CI/CD w/ AWS CodePipeline & Demoing Application Security |

**Day 2** |
----- |
[C1 Application Security](./cloudone-application-security/README.md) - Demoing Serverless Apps |
[C1 Container Control](./cloudone-container-control/README.md) - Admission-Controllers and Demoing |
[Azure Pipeliing](./cloud-azure/README.md) - CI/CD w/ Azure Pipelines |

**Day 3** |
----- |
[MOADSD-NG](./moadsd-ng/README.md) - Use-Cases and Best Practices |
[Smart Check](./cloudone-smart-check/README.md) - Reporting, Deployment Scripts |
[GCP Pipelining](./cloud-gcp/README.md) - CI/CD w/ GCP Cloud Build |

## Before you start

### 1. Clone the DevOps Training Material

Do this by starting a terminal (I do prefer iTerm2 :-)). Then change to your usual develop folder (which you hopefully have) and do a

```shell
git clone https://github.com/mawinkler/devops-training.git
cd devops-training
```

### 2. (Optional) Create your Multi Cloud Shell Container

If you want to have your shell locally, you can simply use the *Multi Cloud Shell* Container environment which has all the required tools prepopulated for you.

**Note:** If you are using a Mac and iCloud Drive, you should move the shell folder to a location *not* within the scope if iCloud Drive. This is not mandatory but recommended.

```shell
cd shell
./build.sh
./start.sh
```

Otherwise use the cloud shells of the providers (pay attention to the timeouts!) or use you own environment.
