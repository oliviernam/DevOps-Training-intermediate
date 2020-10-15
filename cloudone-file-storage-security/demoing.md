# Demoing CloudOne File Storage Security

- [Demoing CloudOne File Storage Security](#demoing-cloudone-file-storage-security)
  - [Prerequisites](#prerequisites)
  - [Installation](#installation)
  - [Demoing with Tags](#demoing-with-tags)
  - [Logs](#logs)
    - [Identify Log Group and Log Stream](#identify-log-group-and-log-stream)
    - [Query the Logs](#query-the-logs)
    - [Query with CloudWatch Insights](#query-with-cloudwatch-insights)
  - [Improving the Functionality](#improving-the-functionality)
  - [Demoing Promote or Quarantine](#demoing-promote-or-quarantine)
  - [Logs with Promote or Quarantine](#logs-with-promote-or-quarantine)
    - [Identify Log Group and Log Stream](#identify-log-group-and-log-stream-1)
  - [Remove File Storage Security](#remove-file-storage-security)

CloudOne File Storage Security is abbreviated by `FSS`

## Prerequisites

- Have an AWS account
- Have access to Cloud One File Storage Security

## Installation

First, create a scanning bucket in the desired region:

```sh
export REGION=[YOUR DESIRED AWS REGION HERE]
export SCANNING_BUCKET=filestoragesecurity-scanning-bucket-$(cat /dev/urandom | tr -dc 'a-z0-9' | fold -w 8 | head -n 1)

aws s3 mb s3://${SCANNING_BUCKET} --region ${REGION}
```

- Authenticate to Cloud One and select `File Storage Security`
- Click on [Deploy All-in-One Stack] and follow the Steps
  - Sign in to the AWS account
  - Launch Stack
  - Choose the target region for the stack (top right)
  - Fill in the scanning bucket name from above

*Note: You don't need to specify the license layer during the private preview phase of FSS.*

After the stack deployment has been completed, query the `ScannerStackManagementRoleARN` and `StorageStackManagementRoleARN`.

```sh
export STACK_NAME=<THE STACK NAME YOU CHOSE, default FileStorageSecurity-All-In-One-Stack>

echo "ScannerStackManagementRoleARN:" $(aws cloudformation describe-stacks --region ${REGION} --stack-name ${STACK_NAME} | jq -r '.Stacks[].Outputs[] | select(.OutputKey=="ScannerStackManagementRoleARN") | .OutputValue')

echo "StorageStackManagementRoleARN:" $(aws cloudformation describe-stacks --region ${REGION} --stack-name ${STACK_NAME} | jq -r '.Stacks[].Outputs[] | select(.OutputKey=="StorageStackManagementRoleARN") | .OutputValue')
```

Back on the Cloud One console, fill in the ManagementRoleARNs which you queried just before and click submit.

## Demoing with Tags

Open a shell session either on Cloud9 or any other instance with a configured `aws cli`.

The basic functionality of FSS is to scan on file upload to the `filestoragesecurity-scanning-bucket` and add tags to file if it got scanned and if it's malicous or not.

Download the `eicarcom2.zip` and upload it to the scanning bucket.

```sh
wget https://secure.eicar.org/eicarcom2.zip
aws s3 cp eicarcom2.zip s3://${SCANNING_BUCKET}/eicarcom2.zip
```

Give the scanner a few seconds to complete the scan and tag the files accordingly.

To get the scan results, simply query the tags of the file.

```sh
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

## Logs

### Identify Log Group and Log Stream

First, lets list the log groups:

```sh
aws logs describe-log-groups --region ${REGION}
```

Identify the log group by searching for `PostScanAction` and store it in a variable.

```sh
export LOGGROUP_PSA=$(aws logs describe-log-groups --region ${REGION} | jq -r '.logGroups[] | select(.logGroupName | contains("PostScanAction")) | .logGroupName')
echo ${LOGGROUP_PSA}
```

```sh
/aws/lambda/FileStorageSecurity-All-In-PostScanActionTagLambda-PDHWFFZU04BK
```

Lets list the logs streams on our log group

```sh
aws logs describe-log-streams --region ${REGION} --log-group-name ${LOGGROUP_PSA}
```

```json
{
    "logStreams": [
        {
            "firstEventTimestamp": 1600349510605, 
            "lastEventTimestamp": 1600349510855, 
            "creationTime": 1600349519656, 
            "uploadSequenceToken": "49610139180714023749403413996239608667913851474239290306", 
            "logStreamName": "2020/09/17/[$LATEST]157ba4d555ed40d8abea891cdf200607", 
            "lastIngestionTime": 1600349519663, 
            "arn": "arn:aws:logs:us-east-1:634503960501:log-group:/aws/lambda/FileStorageSecurity-All-In-PostScanActionTagLambda-PDHWFFZU04BK:log-stream:2020/09/17/[$LATEST]157ba4d555ed40d8abea891cdf200607", 
            "storedBytes": 781
        }, 
        {
            "firstEventTimestamp": 1600350792901, 
            "lastEventTimestamp": 1600350793191, 
            "creationTime": 1600350801961, 
            "uploadSequenceToken": "49610792935600704085589188193092891304439081523009500210", 
            "logStreamName": "2020/09/17/[$LATEST]2d9e363e865d4203a7a916d1efb09b76", 
            "lastIngestionTime": 1600350801969, 
            "arn": "arn:aws:logs:us-east-1:634503960501:log-group:/aws/lambda/FileStorageSecurity-All-In-PostScanActionTagLambda-PDHWFFZU04BK:log-stream:2020/09/17/[$LATEST]2d9e363e865d4203a7a916d1efb09b76", 
            "storedBytes": 780
        }
    ]
}
```

If you have a lot of objets and you already now the date of the test, you can use it as a prefix filter. Like:

```sh
aws logs describe-log-streams --log-group-name ${LOGGROUP_PSA} --log-stream-name-prefix 2020/09/23
```

For this lab, we're just using the latest log stream

```sh
export LOGSTREAM_PSA=$(aws logs describe-log-streams --region ${REGION} --log-group-name ${LOGGROUP_PSA} | jq -r '.logStreams | sort_by(.lastEventTimestamp)[-1].logStreamName')
echo ${LOGSTREAM_PSA}
```

### Query the Logs

```sh
aws logs get-log-events --region ${REGION} --log-group-name ${LOGGROUP_PSA} --log-stream-name ${LOGSTREAM_PSA}
```

In the output of the command we will see the result of the scan on the log:

```json
{
    "nextForwardToken": "f/35689015267218867514194892400432095196956202115806265351", 
    "events": [
        {
            "ingestionTime": 1600350801969, 
            "timestamp": 1600350792901, 
            "message": "START RequestId: 1be54d1b-ed5b-48c6-bc13-c0a76e168e2c Version: $LATEST\n"
        }, 
        {
            "ingestionTime": 1600350801969, 
            "timestamp": 1600350792906, 
            "message": "version: 0.1.2\n"
        }, 
        {
            "ingestionTime": 1600350801969, 
            "timestamp": 1600350792906, 
            "message": "{\"timestamp\": 1600350791.9830256, \"sqs_message_id\": \"c8e79806-474b-47ec-b1b8-c3c72810bb5c\", \"file_url\": \"https://filestoragesecurity-scanning-bucket-gw6i2g.s3.amazonaws.com/eicarcom2.zip\", \"scanner_status\": 0, \"scanner_status_message\": \"successful scan\", \"scanning_result\": {\"TotalBytesOfFile\": 308, \"Findings\": [{\"malware\": \"Eicar_test_file\", \"type\": \"Virus\"}], \"Error\": \"\"}}\n"
        }, 
        {
            "ingestionTime": 1600350801969, 
            "timestamp": 1600350792906, 
            "message": "findings: [{\"malware\": \"Eicar_test_file\", \"type\": \"Virus\"}]\n"
        }, 
        {
            "ingestionTime": 1600350801969, 
            "timestamp": 1600350792906, 
            "message": "scan result: malicious\n"
        }, 
        {
            "ingestionTime": 1600350801969, 
            "timestamp": 1600350793186, 
            "message": "the object has been tagged with scanning results\n"
        }, 
        {
            "ingestionTime": 1600350801969, 
            "timestamp": 1600350793191, 
            "message": "END RequestId: 1be54d1b-ed5b-48c6-bc13-c0a76e168e2c\n"
        }, 
        {
            "ingestionTime": 1600350801969, 
            "timestamp": 1600350793191, 
            "message": "REPORT RequestId: 1be54d1b-ed5b-48c6-bc13-c0a76e168e2c\tDuration: 289.87 ms\tBilled Duration: 300 ms\tMemory Size: 128 MB\tMax Memory Used: 80 MB\tInit Duration: 500.26 ms\t\n"
        }
    ], 
    "nextBackwardToken": "b/35689015260751651406621011689386736897888177279071944704"
}
```

If you are interested on the total time spent to scan the files, we need to dig into a different log group, which you can identify with the "ScannerLambda" within its name.

```sh
export LOGGROUP_SL=$(aws logs describe-log-groups --region ${REGION} | jq -r '.logGroups[] | select(.logGroupName | contains("ScannerLambda")) | .logGroupName')
echo ${LOGGROUP_SL}
```

```sh
/aws/lambda/FileStorageSecurity-All-In-One-Stack-ScannerLambda-170WMQJ2HLTJR
```

```sh
export LOGSTREAM_SL=$(aws logs describe-log-streams --region ${REGION} --log-group-name ${LOGGROUP_SL} | jq -r '.logStreams | sort_by(.lastEventTimestamp)[-1].logStreamName')
echo ${LOGSTREAM_SL}
```

```sh
2020/09/18/[$LATEST]875f932baf734fb7b53f6e3c6ceb6e3f
```

To query scan results, execute

```sh
aws logs get-log-events --region ${REGION} --log-group-name ${LOGGROUP_SL} --log-stream-name ${LOGSTREAM_SL} | jq -r '.events[] | select(.message | startswith("scan context") or startswith("scanner result")) | .message'
```

Note that the time is in milliseconds. The output of the command: (check the `scanDurationMS` field)

```sh
scanner result: {"timestamp": 1600424846.7413783, "sqs_message_id": "aba6b077-5fa4-49cb-ac7f-796349b7e238", "file_url": "https://filestoragesecurity-scanning-bucket-gw6i2g.s3.amazonaws.com/eicar.com", "scanner_status": 0, "scanner_status_message": "successful scan", "scanning_result": {"TotalBytesOfFile": 68, "Findings": [{"malware": "Eicar_test_file", "type": "Virus"}], "Error": ""}}

scan context: {"messageID": "aba6b077-5fa4-49cb-ac7f-796349b7e238", "messageFirstReceiveTimestamp": 1600424844186, "messageReceiveCount": 1, "bucket": "filestoragesecurity-scanning-bucket-gw6i2g", "objectKey": "eicar.com", "scanDurationMS": 250, "scanStartTimestamp": 1600424846}

scanner result: {"timestamp": 1600424962.7634487, "sqs_message_id": "ad471ca3-a000-4409-83b4-eceac8dccf81", "file_url": "https://filestoragesecurity-scanning-bucket-gw6i2g.s3.amazonaws.com/googlelogo_color_272x92dp.png", "scanner_status": 0, "scanner_status_message": "successful scan", "scanning_result": {"TotalBytesOfFile": 13504, "Findings": [], "Error": ""}}

scan context: {"messageID": "ad471ca3-a000-4409-83b4-eceac8dccf81", "messageFirstReceiveTimestamp": 1600424962619, "messageReceiveCount": 1, "bucket": "filestoragesecurity-scanning-bucket-gw6i2g", "objectKey": "googlelogo_color_272x92dp.png", "scanDurationMS": 112, "scanStartTimestamp": 1600424962}
```

### Query with CloudWatch Insights

As an option, you can do a query through the CloudWatch Insights. This is just another way to show the logs of the scanner.

Lets do it:

```sh
export LOGGROUP_SL=$(aws logs describe-log-groups --region ${REGION} | jq -r '.logGroups[] | select(.logGroupName | contains("ScannerLambda")) | .logGroupName')

aws logs start-query --region ${REGION} \
  --log-group-name ${LOGGROUP_SL} \
  --start-time `date -d "30 Days ago" +"%s"` \
  --end-time `date "+%s"` \
  --query-string 'fields @timestamp, @message | filter @message like "scanner result" | sort @timestamp desc | limit 20'
```

The command returned the query id.

```json
{
    "queryId": "93873c9d-ba90-4520-b7fa-4bf511f90bb4"
}
```

So, lets use this id to get the logs that we queried.

```sh
aws logs get-query-results --region ${REGION} --query-id 93873c9d-ba90-4520-b7fa-4bf511f90bb4
```

```json
{
    "status": "Complete", 
    "statistics": {
        "recordsMatched": 4.0, 
        "recordsScanned": 72.0, 
        "bytesScanned": 10826.0
    }, 
    "results": [
        [
            {
                "field": "@timestamp", 
                "value": "2020-09-18 10:29:22.763"
            }, 
            {
                "field": "@message", 
                "value": "scanner result: {\"timestamp\": 1600424962.7634487, \"sqs_message_id\": \"ad471ca3-a000-4409-83b4-eceac8dccf81\", \"file_url\": \"https://filestoragesecurity-scanning-bucket-gw6i2g.s3.amazonaws.com/googlelogo_color_272x92dp.png\", \"scanner_status\": 0, \"scanner_status_message\": \"successful scan\", \"scanning_result\": {\"TotalBytesOfFile\": 13504, \"Findings\": [], \"Error\": \"\"}}\n"
            }, 
            {
                "field": "@ptr", 
                "value": "CpYBCl0KWTYzNDUwMzk2MDUwMTovYXdzL2xhbWJkYS9GaWxlU3RvcmFnZVNlY3VyaXR5LUFsbC1Jbi1PbmUtU3RhY2stU2Nhbm5lckxhbWJkYS0xNzBXTVFKMkhMVEpSEAcSNRoYAgXwN6G3AAAAAHy/wHYABfZIt/AAAAByIAEo19SLhsouMPzWi4bKLjgQQK8TSPI/UKExEAoYAQ=="
            }
        ], 
        [
            {
                "field": "@timestamp", 
                "value": "2020-09-18 10:27:26.741"
            }, 
            {
                "field": "@message", 
                "value": "scanner result: {\"timestamp\": 1600424846.7413783, \"sqs_message_id\": \"aba6b077-5fa4-49cb-ac7f-796349b7e238\", \"file_url\": \"https://filestoragesecurity-scanning-bucket-gw6i2g.s3.amazonaws.com/eicar.com\", \"scanner_status\": 0, \"scanner_status_message\": \"successful scan\", \"scanning_result\": {\"TotalBytesOfFile\": 68, \"Findings\": [{\"malware\": \"Eicar_test_file\", \"type\": \"Virus\"}], \"Error\": \"\"}}\n"
            }, 
            {
                "field": "@ptr", 
                "value": "CpYBCl0KWTYzNDUwMzk2MDUwMTovYXdzL2xhbWJkYS9GaWxlU3RvcmFnZVNlY3VyaXR5LUFsbC1Jbi1PbmUtU3RhY2stU2Nhbm5lckxhbWJkYS0xNzBXTVFKMkhMVEpSEAMSNRoYAgXqDv8wAAAAAYcWzx8ABfZIsTAAAAYCIAEo+b6EhsouMLnMhIbKLjgSQJMVSMNIUOw3EAwYAQ=="
            }
        ], 
        [
            {
                "field": "@timestamp", 
                "value": "2020-09-17 13:53:11.983"
            }, 
            {
                "field": "@message", 
                "value": "scanner result: {\"timestamp\": 1600350791.9830256, \"sqs_message_id\": \"c8e79806-474b-47ec-b1b8-c3c72810bb5c\", \"file_url\": \"https://filestoragesecurity-scanning-bucket-gw6i2g.s3.amazonaws.com/eicarcom2.zip\", \"scanner_status\": 0, \"scanner_status_message\": \"successful scan\", \"scanning_result\": {\"TotalBytesOfFile\": 308, \"Findings\": [{\"malware\": \"Eicar_test_file\", \"type\": \"Virus\"}], \"Error\": \"\"}}\n"
            }, 
            {
                "field": "@ptr", 
                "value": "CpYBCl0KWTYzNDUwMzk2MDUwMTovYXdzL2xhbWJkYS9GaWxlU3RvcmFnZVNlY3VyaXR5LUFsbC1Jbi1PbmUtU3RhY2stU2Nhbm5lckxhbWJkYS0xNzBXTVFKMkhMVEpSEAQSNRoYAgXbxshSAAAABHXF2zEABfY2m1AAAAAiIAEog8Lc4skuMOXT3OLJLjgUQPYWSKJpUIpSEA4YAQ=="
            }
        ], 
        [
            {
                "field": "@timestamp", 
                "value": "2020-09-17 13:31:49.562"
            }, 
            {
                "field": "@message", 
                "value": "scanner result: {\"timestamp\": 1600349509.562536, \"sqs_message_id\": \"38c6e5e8-5ea4-42e6-81d9-198d9aaf6f0a\", \"file_url\": \"https://filestoragesecurity-scanning-bucket-gw6i2g.s3.amazonaws.com/eicar.txt\", \"scanner_status\": 0, \"scanner_status_message\": \"successful scan\", \"scanning_result\": {\"TotalBytesOfFile\": 69, \"Findings\": [{\"malware\": \"Eicar_test_file\", \"type\": \"Virus\"}], \"Error\": \"\"}}\n"
            }, 
            {
                "field": "@ptr", 
                "value": "CpYBCl0KWTYzNDUwMzk2MDUwMTovYXdzL2xhbWJkYS9GaWxlU3RvcmFnZVNlY3VyaXR5LUFsbC1Jbi1PbmUtU3RhY2stU2Nhbm5lckxhbWJkYS0xNzBXTVFKMkhMVEpSEAMSNRoYAgXqDv8wAAAAAYULjJsABfY2UkAAAAYCIAEotqKO4skuMO2wjuLJLjgSQJIVSLVIUN43EAwYAQ=="
            }
        ]
    ]
}
```

## Improving the Functionality

FSS does only tag scanned files. This effectively means, that the logic if the uploaded files should be processed by some logic needs to be on the application side. With the help of a Lambda and a littne SNS we're able to take that part. So, after a scan occurs, we're able to place clean files on one bucket and malicious in another.

Still being in your aws cli session create two S3 buckets.

```sh
export PROMOTE_BUCKET=filestoragesecurity-promote-bucket-$(cat /dev/urandom | tr -dc 'a-z0-9' | fold -w 8 | head -n 1)
export QUARANTINE_BUCKET=filestoragesecurity-quarantine-bucket-$(cat /dev/urandom | tr -dc 'a-z0-9' | fold -w 8 | head -n 1)

aws s3 mb s3://${PROMOTE_BUCKET} --region ${REGION}
aws s3 mb s3://${QUARANTINE_BUCKET} --region ${REGION}
```

Create the FSS trust policy

```sh
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

```sh
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

```sh
wget https://raw.githubusercontent.com/trendmicro/cloudone-filestorage-plugins/master/post-scan-actions/aws-python-promote-or-quarantine/handler.py

zip promote-or-quarantine.zip handler.py

aws lambda create-function --function-name FSS_Prom_Quar_Lambda \
  --role ${ROLE_ARN} \
  --region ${REGION} \
  --runtime python3.8 \
  --timeout 30 \
  --memory-size 512 \
  --handler handler.lambda_handler \
  --zip-file fileb://promote-or-quarantine.zip \
  --environment Variables=\{PROMOTEBUCKET=${PROMOTE_BUCKET},QUARANTINEBUCKET=${QUARANTINE_BUCKET}\}
```

Subscribe the Lambda to the SNS topic

Query the ScanResultTopic ARN

```sh
export STORAGE_STACK=$(aws cloudformation list-stacks --region ${REGION} | jq --arg stack_name ${STACK_NAME} -r '.StackSummaries[] | select(.StackId | contains($stack_name) and contains("-StorageStack")) | select(.StackStatus=="CREATE_COMPLETE") | .StackName')

export SCAN_RESULT_TOPIC_ARN=$(aws cloudformation list-stack-resources --region ${REGION} --stack-name ${STORAGE_STACK} | jq -r '.StackResourceSummaries[] | select(.LogicalResourceId=="ScanResultTopic") | .PhysicalResourceId')
```

Query the Lambda ARN

```sh
export LAMBDA_ARN=$(aws lambda list-functions --region ${REGION} | jq -r '.Functions[] | select(.FunctionName | contains("FSS_Prom_Quar_Lambda")) | .FunctionArn')
```

Subscribe the Lambda to the SNS topic

```sh
aws sns subscribe --topic-arn ${SCAN_RESULT_TOPIC_ARN} --protocol lambda --notification-endpoint ${LAMBDA_ARN} --region ${REGION}
```

Lastly, we need to grant the SNS service permission to invoke our function.

```sh
aws lambda add-permission \
  --function-name FSS_Prom_Quar_Lambda \
  --region ${REGION} \
  --statement-id sns \
  --action lambda:InvokeFunction \
  --principal sns.amazonaws.com \
  --source-arn ${SCAN_RESULT_TOPIC_ARN}
```


## Demoing Promote or Quarantine

Download the `eicar.com` and upload it to the scanning bucket.

```sh
wget https://secure.eicar.org/eicar.com
aws s3 cp eicar.com s3://${SCANNING_BUCKET}/eicar.com
```

Download a second, clean file and upload it.

```sh
wget https://www.google.de/images/branding/googlelogo/2x/googlelogo_color_272x92dp.png
aws s3 cp googlelogo_color_272x92dp.png s3://${SCANNING_BUCKET}/googlelogo_color_272x92dp.png
```

If everything works, you should be able to find the eicar file in the quarantine bucket, the image file in the promote bucket.

## Logs with Promote or Quarantine

### Identify Log Group and Log Stream

First, lets list the log groups:

```sh
aws logs describe-log-groups --region ${REGION}
```

Identify the log group by searching for `FSS_Prom_Quar` and store it in a variable.

```sh
export LOGGROUP_PQL=$(aws logs describe-log-groups --region ${REGION} | jq -r '.logGroups[] | select(.logGroupName | contains("FSS_Prom_Quar")) | .logGroupName')
```

Lets list the logs streams on our log group

```sh
aws logs describe-log-streams --region ${REGION} --log-group-name ${LOGGROUP_PQL}
```

You should get as many log stream as you have scanned files.

If you have a lot of objets and you already now the date of the test, you can use it as a prefix filter. Like:

```sh
aws logs describe-log-streams --log-group-name --region ${REGION} ${LOGGROUP_PQL} --log-stream-name-prefix $(date +"%Y/%m/%d")
```

Lastly, lets review the scan results.

```sh
export LOGSTREAMS_SL=$(aws logs describe-log-streams --region ${REGION} --log-group-name ${LOGGROUP_PQL} | jq -r '.logStreams[] | .logStreamName')

for ls in ${LOGSTREAMS_SL} ; do 
  aws logs get-log-events --region ${REGION} \
    --log-group-name ${LOGGROUP_PQL} \
    --log-stream-name $ls | \
      jq -r '.events[] | select(.message | contains("scanning_result")) | .message' ;
done
```

## Remove File Storage Security

Got to CloudFormation on AWS and delete the FileStorageSecurity-All-In-One-Stack. Afterwards eventually remaining Storage Stacks.

Be sure to delete the policy and role named FSS_Prom_Quar as well.

*At the time of writing, there is no possibility to delete orphaned stacks on the console of Cloud One.*
