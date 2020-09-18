# Demoing CloudOne File Storage Security

- [Demoing CloudOne File Storage Security](#demoing-cloudone-file-storage-security)
  - [Prerequisites](#prerequisites)
  - [Installation](#installation)
  - [Demoing with Tags](#demoing-with-tags)
  - [Improving the Functionality](#improving-the-functionality)
  - [Demoing Promote or Quarantine](#demoing-promote-or-quarantine)
  - [Deinstallation](#deinstallation)

CloudOne File Storage Security is abbreviated by `FSS`

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

## Demoing with Tags

Open a shell session either on Cloud9 or any other instance with a configured `aws cli`.

The basic functionality of FSS is to scan on file upload to the `filestoragesecurity-scanning-bucket` and add tags to file if it got scanned and if it's malicous or not.

Download the `eicarcom2.zip` and upload it to the scanning bucket.

```shell
export SCANNING_BUCKET=$(aws s3 ls | sed -n 's/.*\(filestoragesecurity-scanning-bucket.*\)/\1/p')

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

## Improving the Functionality

FSS does only tag scanned files. This effectively means, that the logic if the uploaded files should be processed by some logic needs to be on the application side. With the help of a Lambda and a littne SNS we're able to take that part. So, after a scan occurs, we're able to place clean files on one bucket and malicious in another.

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

aws iam create-policy --policy-name FSS_Lambda_Policy --policy-document file://fss-trust-policy.json
```

Create an execution role for the Lambda function

```shell
LAMBDA_TRUST="{
    \"Version\": \"2012-10-17\", 
    \"Statement\": [
        {
            \"Action\": \"sts:AssumeRole\", 
            \"Effect\": \"Allow\", 
            \"Principal\": {
                \"Service\": \"lambda.amazonaws.com\"
            }
        }
    ]
}" 

export POLICY_ARN=$(aws iam list-policies --scope Local | jq -r '.Policies[] | select(.Arn | contains("FSS")) | .Arn')

aws iam create-role --role-name FSS_Lambda_Role --assume-role-policy-document "${LAMBDA_TRUST}"
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
export STORAGE_STACK=$(aws cloudformation list-stacks --region us-east-1 | jq -r '.StackSummaries[] | select(.StackId | contains("FileStorageSecurity-All-In-One-Stack-StorageStack")) | select(.StackStatus=="CREATE_COMPLETE") | .StackName')
export SCAN_RESULT_TOPIC_ARN=$(aws cloudformation list-stack-resources --region us-east-1 --stack-name ${STORAGE_STACK} | jq -r '.StackResourceSummaries[] | select(.LogicalResourceId=="ScanResultTopic") | .PhysicalResourceId')
```

Query the Lambda ARN

```shell
export LAMBDA_ARN=$(aws lambda list-functions --region us-east-1 | jq -r '.Functions[] | select(.FunctionName | contains("FSS_Prom_Quar_Lambda")) | .FunctionArn')
```

Subscribe the Lambda to the SNS topic

```shell
aws sns subscribe --topic-arn ${SCAN_RESULT_TOPIC_ARN} --protocol lambda --notification-endpoint ${LAMBDA_ARN} --region us-east-1
```

## Demoing Promote or Quarantine

Download the `eicar.com` and upload it to the scanning bucket.

```shell
export SCANNING_BUCKET=$(aws s3 ls | sed -n 's/.*\(filestoragesecurity-scanning-bucket.*\)/\1/p')

wget https://secure.eicar.org/eicar.com
aws s3 cp eicar.com s3://${SCANNING_BUCKET}/eicar.com
```

Download a second, clean file and upload it.

```shell
wget https://www.google.de/images/branding/googlelogo/2x/googlelogo_color_272x92dp.png
aws s3 cp googlelogo_color_272x92dp.png s3://${SCANNING_BUCKET}/googlelogo_color_272x92dp.png
```

If everything works, you should be able to find the eicar file in the quarantine bucket, the image file in the promote bucket.

## Deinstallation

Got to CloudFormation on AWS and delete the FileStorageSecurity-All-In-One-Stack. Afterwards eventually remaining Storage Stacks.

**At the time of writing, there is no possibility to delete orphaned stacks on the console of Cloud One.**
