#!/bin/bash

# user variables
AWS_REGION="us-east-2"
AWS_INSTANCE_TYPE="t2.small"
AWS_KEY_NAME="somekey"
SERVER_FQDN="minecraft.example.com"
REPO_URL="https://github.com/CrashZebra/minecraft-aws.git"

# find the most recent base image AMI (named amzn2-docker-ce-base*)
AWS_AMI_ID=`aws ec2 describe-images --region $AWS_REGION --owner self \
  --filters "Name=name,Values=amzn2-docker-ce-base*" --query 'Images[].[CreationDate,ImageId,Name]' --output text | sort -k1 | tail -n1 | awk '{print $2}'`

# TODO: select a subnet in the default VPC which was setup in setup-aws.sh

# launch our minecraft-server instance
aws ec2 run-instances --region $AWS_REGION --image-id $AWS_AMI_ID --count 1 \
  --instance-type $AWS_INSTANCE_TYPE --key-name $AWS_KEY_NAME --security-groups minecraft-server \
  --iam-instance-profile Name=minecraft-server --user-data file://bootstrap-aws.sh \
  --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=minecraft-server},{Key=FQDN,Value=${SERVER_FQDN}},{Key=REPO_URL,Value=${REPO_URL}}]"