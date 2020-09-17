# Demoing CloudOne Conformity

- [Demoing CloudOne Conformity](#demoing-cloudone-conformity)
  - [Prerequisites](#prerequisites)
  - [About Conformity](#about-conformity)
  - [Start with the Dashboard](#start-with-the-dashboard)
  - [Now Begin Digging in](#now-begin-digging-in)
  - [Rule Configuration](#rule-configuration)
  - [Profiles](#profiles)
  - [Reports](#reports)
    - [Communication](#communication)
  - [Real Time Monitoring](#real-time-monitoring)

CloudOne Conformity is abbreviated by `CC`

## Prerequisites

- Have a "used" AWS account with
  - EC2 instances
  - Public Read and or Write S3 Buckets, preferably unencrypted
  - ...

Important for demoing `CC`, **login to your AWS!**

## About Conformity

- Basically, `CC` at it's base is an infrastructure monitoring tool for
  - AWS
  - Azure
  - Google (planned)
- Within this demo we're focussing on AWS
- `CC` currently has **540+ different rule** and
- covers **70 different services**

## Start with the Dashboard

- All accounts dashboard provides a **high level overview**
  - **how many checks are done**
  - **overview on risk, succeeds and failures**
- Geographical spread etc.

![alt text](images/01_high_level_overview.png "High Level Overview")

## Now Begin Digging in

![alt text](images/02_browse_all_checks.png "Browse all Checks")

- **Dashboard --> Browse all checks**
  - High level overview what's surfaced on your accounts
  - Typically by far to many findings, usually. So we need to limit and prioritize them.
  - Filter Settings you can use *(this might be different in your AWS account, so please adapt if necessary)*:
    - Services `S3`, `dynamodb`
      - only security
      - all frameworks
      - Risk level high++
      - Status Failures
  - It's now reasonable to address
  - Optionally, you can generate a **report** with Selected Services Security Only
  - Go to **S3 Bucker Default Encryption**
  ![alt text](images/03_s3_bucket_default_encryption.png "S3 Bucket Default Encryption")
    - Here we do have underneeth the checks taken out associated to that account
    - `CC` tells about the **context**
    - Direct **Link** to the ressource - brings you to the resource in AWS
  - `CC` does tell as well on how to mitigate the finding. Click the **Resolve** button
    - That gives you info about **"what the rule is checking for"** and
    - **"why it is important"**
    - **"how to resolve that issue"**
    - We always provide the instructions to resolve the issue

## Rule Configuration

  - **Dashboard --> Settings --> Configure now**
  ![alt text](images/04_rule_settings.png "Rule Settings")
    - Filter for `non-active rules`, and `Requires configuration check`
    - Search for `regions`
    ![alt text](images/05_rule_regions.png "Rule Regions")
    - Most of the rules are active by default, but one can **customize*- the active rules or configure custom rules
      - e.g. User activity in blacklisted regions
        - blacklist everything outside europe as an example
  - All rules can be configured
    - e.g. there are **very valid reasons** why you might want public read access to an s3 bucket (e.g. public web site)
    - Filter Services for `S3`
    ![alt text](images/06_rule_s3_bucket_read_access.png "Rule S3 Bucket Read Access")
    - S3 Bucket Public 'READ' Access
      - do exceptions here (S3 bucket name even with regex or tags)
    - Eliminating false positives

## Profiles

  - **Dashboard Menubar --> Profiles**
  - An accounts configuration should be saved as a profile
  ![alt text](images/07_profiles.png "Profiles")
    - Profiles - Baseline
      - All configurations are now saved as a new profile
  - Accounts can be grouped
    - Create a new Group (dev, test, staging, prod)
    - Creates views

## Reports

  - **Dashboard --> Reports...**
  ![alt text](images/08_configured_reports.png "Configured Reports")
  - New Report...
    - Same filtering but here you can save your filter options and define the report
    - Schedule them
    - Send email
    - View by Standard or Framework
      - AWS Well-Architected Framework - very good way to start improving your environment
        - more info brings you to the source of truth
      - Filter as above

### Communication

  - **Dashboard --> Settings (top right) --> Update communication settings...**
  ![alt text](images/09_communication_settings.png "Update Communication Settings")
  - CC is designed that you don't need to login day by day.
    - for that we have the communication settings which allows us to integrate into various systems
    - there is really no reason to logon anymore
    - all alerts are then send to that channel according to the configuration
      - e.g. slack only security findings for security channel (very high+)
        - turn on
        - configure triggers...
        - configure channel
      - jira closes the ticket when the finding is mitigated

## Real Time Monitoring

  - **Dashboard --> Threat monitoring**
  ![alt text](images/10_threat_monitoring.png "Threat Monitoring")
  - Essentially it is a connection to `AWS CloudTrail` and `AWS CloudWatch`
  - `CC` is receiving a copy of the events
    - **Open activity Dashboard**
    ![alt text](images/11_user_activity.png "User Activity")
    - **Open monitoring dashboard**
    ![alt text](images/12_real_time_monitoring.png "Real-Time Monitoring")

That was a very brief overview about CloudOne Conformity
