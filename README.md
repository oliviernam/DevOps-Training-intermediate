# DevOps Intermediate Training

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
C1 Conformity - Demoing |
C1 File Storage Security - Demoing |
CI/CD w/ AWS CodePipeline & Demoing Application Security |

**Day 2** |
----- |
C1 Application Security - Demoing Serverless Apps |
C1 Container Control - Admission-Controllers and Demoing |
CI/CD w/ Azure Pipelines |

**Day 3** |
----- |
MOADSD-NG - Use-Cases and Best Practices |
C1 Smart Check - Reporting, Deployment Scripts |
CI/CD w/ GCP Cloud Build |

## Before you start

### 1. Clone the DevOps Training Material

Do this by starting a terminal (I do prefer iTerm2 :-)), change to your usual develop folder (which you hopefully have) and do a

```shell
git clone https://github.com/mawinkler/devops-training.git
cd devops-training
```

### 2. (Optional) Create your Multi Cloud Shell Container

If you want to have your shell locally, you can simply use the Multi Cloud Shell Container environment which has all the required tools prepopulated for you.

```shell
cd shell
./build.sh
./start.sh
```

Otherwise use the cloud shells of the provides (beware of the timeouts!) or use you own environment.
