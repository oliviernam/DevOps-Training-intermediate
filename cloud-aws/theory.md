# Theory to Cover

- ARN
- IAM
  - Create Users
  - Policies
  - Roles
  - Trust
  - Instance Profiles
  - Permissions
- STS
  - get-caller-identity
- KMS
  - Secrets Encryption
  
<https://aws.amazon.com/de/premiumsupport/knowledge-center/iam-assume-role-cli/>

## ARN

Amazon Resource Names (ARNs) uniquely identify AWS resources. We require an ARN when you need to specify a resource unambiguously across all of AWS, such as in IAM policies, Amazon Relational Database Service (Amazon RDS) tags, and API calls.

The following are the general formats for ARNs. The specific formats depend on the resource. To use an ARN, replace the italicized text with the resource-specific information. Be aware that the ARNs for some resources omit the Region, the account ID, or both the Region and the account ID.

```text
arn:partition:service:region:account-id:resource-id
arn:partition:service:region:account-id:resource-type/resource-id
arn:partition:service:region:account-id:resource-type:resource-id
```

## How do I assume an IAM role using the AWS CLI?

aws iam create-user --user-name Bob
aws iam create-policy
aws iam attach-user-policy
aws iam create-role
aws iam attach-role-policy
aws iam create-access-key
