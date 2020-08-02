# Agenda DevOps Training v2

- [Agenda DevOps Training v2](#agenda-devops-training-v2)
  - [Top Requested](#top-requested)
  - [Additional Value](#additional-value)
  - [Topics](#topics)
  - [Things to Prepare](#things-to-prepare)
  - [Things to Decide](#things-to-decide)
  - [Postponed](#postponed)
  - [Links](#links)

## Top Requested

- Cloud One Conformity
- Cloud One Application Security
- Cloud One Container Security
- How to PoC the above

## Additional Value

In **BOLD** the ones I think we should do

- **Open Policy Agent --> K8s Admission Controller**
- Chef/Puppet
- **Setting up and demoing MOADSD-NG use cases**
- Full Kubernetes Deployment
- Use Cases
- CTF
- **EKS, GKS**, AKS
- **API usage**
- More in-depth introduction into DevOps and Orchestrators

## Topics

- MOADSD-NG(-SERVER) on Cloud9 / Macbook
  - Prepare Training Environment
  - Lab: Troopers or similar
- C1 Conformity
  - Introduction
  - How to Demo (Demo Script done)
  - Lab:
    - Integrate own cloud account, filter for most important findings and solve some
    - Template Scanner, Identify Findings
    - Conformity API
  - How to PoC
- C1 Container Security
  - Image Security
    - Lab:
      - How to query scan results nicely (Reporting Script done)
      - Webhook
      - Connect to Slack
    - How to PoC
      - Within different environments
      - Limit the scope...
  - Kubernetes Admission Controller / (Container Control if available)
    - Introduction
    - Lab
- C1 Application Security
  - Introduction
  - How to Demo (Demo Script done)
  - Lab: How to integrate
    - Apps (integrate some different applications with AppSec, Java, Python, Tomcat, Lambda, etc.)
    - How to integrate appSec with Pipelines / K8s
  - How to PoC
- EKS / GKE
  - Pipelining with CodeBuild / Cloud Build
  - Lab: Build AWS demo with Pipeline and Smartcheck

## Things to Prepare

- C1 Conformity
  - Intro-Slides
  - Develop Lab
    - AWS, Integrate own cloud account, filter for most important findings and solve some
    - Template Scanner, Identify Findings
  - How to PoC (Slides / Checklist)
- C1 Application Security
  - Slides
  - Select Apps / Lambdas to integrate in
  - Decide on Languages
  - How to PoC (Slides / Checklist)
- C1 Container Security
  - Image Security
    - Develop Lab
      - How to query scan results nicely with
        https://github.com/mawinkler/vulnerability-management/tree/master/cloudone-image-security
    - How to PoC (Slides / Checklist)
  - Kubernetes Admission Controller / Open Policy Agent / (Container Control if available)
    - Intro-Slides
    - Develop Lab ??

## Things to Decide

- Lab Guides as Markdown
- Decide on Languages for Application Security
- Decide on demo containers / projects / Lambdas

## Postponed

K8s Capture the flag
K8s Troubleshooting
K8s deep dive - Explore your cluster

## Links

<https://docs.giantswarm.io/guides/creating-your-own-admission-controller/>
