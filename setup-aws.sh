#!/bin/bash

# user variables
AWS_REGION="us-east-2"

# retreive our account id
AWS_ACCOUNT_ID=`aws sts get-caller-identity --output text --query 'Account'`

# find default VPC
AWS_DEFAULT_VPC=`aws ec2 describe-vpcs --region $AWS_REGION --filters Name=isDefault,Values=true --query 'Vpcs[].VpcId' --output text`

# IAM configurations
aws iam create-role --role-name minecraft-server --assume-role-policy-document file://iam-assume-role-policy.json --description "IAM role for a Minecraft server"
aws iam create-policy --policy-name minecraft-server --policy-document file://iam-instance-policy.json --description "IAM policy that grants permissions for Minecraft servers"
aws iam attach-role-policy --role-name minecraft-server --policy-arn arn:aws:iam::${AWS_ACCOUNT_ID}:policy/minecraft-server
aws iam create-instance-profile --instance-profile-name minecraft-server
aws iam add-role-to-instance-profile --instance-profile-name minecraft-server --role-name minecraft-server

# Network configurations
aws ec2 create-security-group --region $AWS_REGION --vpc-id $AWS_DEFAULT_VPC --description "SG for Minecraft servers" --group-name minecraft-server
aws ec2 authorize-security-group-ingress --region $AWS_REGION --group-name minecraft-server --protocol tcp --port 22 --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --region $AWS_REGION --group-name minecraft-server --protocol tcp --port 25565 --cidr 0.0.0.0/0
