# Demoing CloudOne File Storage Security

- [Demoing CloudOne File Storage Security](#demoing-cloudone-file-storage-security)
  - [TODO](#todo)
  - [Prerequisites](#prerequisites)
  - [Installation](#installation)
  - [Demoing](#demoing)
    - [Tags](#tags)
    - [Promote or Quarantine](#promote-or-quarantine)
  - [Deinstallation](#deinstallation)

CloudOne File Storage Security is abbreviated by `FSS`

## TODO

- Create an execution role for the Lambda function
- Subscribe the Lambda to the SNS topic

## Prerequisites

- Have an AWS account
- Have access to Cloud One File Storage Security

## Installation

- Authenticate to Cloud One and select `File Storage Security`
- Click on [Deploy All-in-One Stack] and follow the Steps
  - Sign in to the AWS account
  - Launch Stack
  - Fill in the ManagementRoleARNs which you get from the outputs tab on the All-in-One stack.
    - ScannerStackManagementRoleARN (e.g. arn:aws:iam::63450XXXXXXX:role/FileStorageSecurity-All-In-One-Stac-ManagementRole-EINRH7TWRJJO)
    - StorageStackManagementRoleARN (e.g. arn:aws:iam::63450XXXXXXX:role/FileStorageSecurity-All-In-One-Stac-ManagementRole-1XGN3868ED9CY)
- Click submit

Note: During the private preview phase of FSS you don't need to specify the license layer.

Afterwards you should have a Scanner Stack and one Storage Stack shown in the Cloud One console. On AWS S3 you should see the following buckets:

- `filestoragesecurity-scanning-bucket-??????`
- `filestoragesecurity-all-in-one-copyzipsdestbucket-??????`
- `filestoragesecurity-all-in-one-copyzipsdestbucket-??????`

## Demoing

Open a shell session either on Cloud9 or any other instance with a configures aws cli.

### Tags

The basic functionality of FSS is to scan on file upload to the `filestoragesecurity-scanning-bucket` and add tags to file if it got scanned and if it's malicous or not.

Download the `eicar.com` and upload it to the scanning bucket.

```shell
export SCANNING_BUCKET=$(aws s3 ls | sed -n 's/.*\(filestoragesecurity-scanning-bucket.*\)/\1/p')
# wget https://secure.eicar.org/eicar.com
# wget https://secure.eicar.org/eicar_com.zip
wget https://secure.eicar.org/eicarcom2.zip

aws s3 cp eicarcom2.zip s3://${SCANNING_BUCKET}/eicarcom2.zip
```

To get the scan result, simply query the tags of the file

```shell
aws s3api get-object-tagging --bucket ${SCANNING_BUCKET} --key eicarcom2.zip
```

```json
{
    "TagSet": [
        {
            "Value": "2020/09/17 13:53:11",
            "Key": "fss-scan-date"
        },
        {
            "Value": "malicious",
            "Key": "fss-scan-result"
        },
        {
            "Value": "true",
            "Key": "fss-scanned"
        }
    ]
}
```

### Promote or Quarantine

After a scan occurs, we're able to place clean files on one bucket and malicious in another.

Still being in your aws cli session create two S3 buckets.

```shell
export PROMOTE_BUCKET=filestoragesecurity-promote-bucket-$(cat /dev/urandom | tr -dc 'a-z0-9' | fold -w 8 | head -n 1)
export QUARANTINE_BUCKET=filestoragesecurity-quarantine-bucket-$(cat /dev/urandom | tr -dc 'a-z0-9' | fold -w 8 | head -n 1)

aws s3 mb s3://${PROMOTE_BUCKET} --region us-east-1
aws s3 mb s3://${QUARANTINE_BUCKET} --region us-east-1
```

Create the FSS trust policy

```shell
cat <<EOF > fss-trust-policy.json
{
    "Version": "2012-10-17",
    "Statement": [
    {
            "Sid": "CopyFromScanningBucket",
            "Effect": "Allow",
            "Action": [
                "s3:GetObject",
                "s3:DeleteObject",
                "s3:GetObjectTagging"
            ],
            "Resource": "arn:aws:s3:::${SCANNING_BUCKET}/*"
        },
        {
            "Sid": "CopyToPromoteOrQuarantineBucket",
            "Effect": "Allow",
            "Action": [
                "s3:PutObject",
                "s3:PutObjectTagging"
            ],
            "Resource": [
                "arn:aws:s3:::${QUARANTINE_BUCKET}/*",
                "arn:aws:s3:::${PROMOTE_BUCKET}/*"
            ]
        }
    ]
}
EOF

aws iam create-policy --policy-name "PolicyName": " --policy-document file://fss-trust-policy.json
```

**TODO**

Create an execution role for the Lambda function

```shell
export POLICY_ARN=$(aws iam list-policies --scope Local | jq -r '.Policies[] | select(.Arn | contains("FSS")) | .Arn')

aws iam create-role --role-name FSS_Lambda_Role
aws iam attach-role-policy --role-name FSS_Lambda_Role --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole
aws iam attach-role-policy --role-name FSS_Lambda_Role --policy-arn ${POLICY_ARN}

export ROLE_ARN=$(aws iam list-roles | jq -r '.Roles[] | select(.Arn | contains("FSS")) | .Arn')
```

Deploy the Lambda

```shell
wget https://raw.githubusercontent.com/trendmicro/cloudone-filestorage-plugins/master/post-scan-actions/aws-python-promote-or-quarantine/handler.py

zip promote-or-quarantine.zip handler.py

aws lambda create-function --function-name FSS_Prom_Quar_Lambda \
  --role ${ROLE_ARN} \
  --region us-east-1 \
  --runtime python3.8 \
  --timeout 30 \
  --memory-size 512 \
  --handler handler.lambda_handler \
  --zip-file fileb://promote-or-quarantine.zip \
  --environment Variables=\{PROMOTEBUCKET=${PROMOTE_BUCKET},QUARANTINEBUCKET=${QUARANTINE_BUCKET}\}
```

Subscribe the Lambda to the SNS topic

Query the ScanResultTopic ARN

```shell
export SCAN_RESULT_TOPIC_ARN=$(aws cloudformation list-stack-resources --region us-east-1 --stack-name FileStorageSecurity-All-In-One-Stack-StorageStack-17GKRTOW9LTC5 | jq -r '.StackResourceSummaries[] | select(.LogicalResourceId=="ScanResultTopic") | .PhysicalResourceId')
```

Query the Lambda ARN

```shell
export LAMBDA_ARN=$(aws lambda list-functions --region us-east-1 | jq -r '.Functions[] | select(.FunctionName | contains("FSS_Prom_Quar_Lambda")) | .FunctionArn')
```

**TODO**

Subscribe the Lambda to the SNS topic

```shell
aws sns subscribe --topic-arn ${SCAN_RESULT_TOPIC_ARN} --notification-endpoint ${LAMBDA_ARN} --protocol lambda
```

## Deinstallation

Got to CloudFormation on AWS and delete the FileStorageSecurity-All-In-One-Stack. Afterwards the eventually remaining Storage Stacks.

At the time of writing, there is no possibility to delete orphaned stacks on the console of Cloud One.
