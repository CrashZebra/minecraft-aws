#!/bin/bash
#
# This Source Code Form is subject to the terms of the Mozilla Public
#  License, v. 2.0. If a copy of the MPL was not distributed with this
#  file, You can obtain one at http://mozilla.org/MPL/2.0/.

# calculate the script's path
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# source config
if [ -f "$DIR/config.env" ]
then
   . "$DIR/config.env"
else
   echo "ERROR - Please create config.env from the sample and try again"
   exit 1
fi

# make sure the utilities we need are present
if [ ! -x "`which aws`" ]
then
   echo "ERROR - Please install the AWS CLI tools and try again"
   exit 1
fi

# retreive our account id
AWS_ACCOUNT_ID=`aws sts get-caller-identity --output text --query 'Account'`
if [ $? -ne 0 ]
then
   echo "ERROR - Please check AWS configuration/credentials and try again"
   exit 1
fi

# find default VPC
AWS_DEFAULT_VPC=`aws ec2 describe-vpcs --region $AWS_REGION --filters Name=isDefault,Values=true --query 'Vpcs[].VpcId' --output text`
if [ $? -ne 0 ]
then
   echo "ERROR - No default VPC found"
   exit 1
fi

# find hosted zone
DOMAIN_NAME=$(echo $SERVER_FQDN | awk -F. '{$1="";OFS="." ; print $0}' | sed 's/^.//')
HOSTED_ZONE=$(aws route53 list-hosted-zones --query 'HostedZones[?starts_with(Name, `'$DOMAIN_NAME'`)==`true`].[Id]' --output text | cut -d / -f 3)
if [ -z "$HOSTED_ZONE" ]
then
   echo "ERROR - Could not fine the hosted zone in Route 53 to handle $DOMAIN_NAME"
   exit 1
fi

# check/create S3 bucket
echo "INFO - Configuring S3"
aws s3api head-bucket --bucket $AWS_S3_BUCKET 2>/dev/null
if [ $? -ne 0 ]
then
   aws s3api create-bucket --acl private --bucket $AWS_S3_BUCKET --region $AWS_REGION --create-bucket-configuration LocationConstraint=$AWS_REGION >/dev/null
   if [ $? -ne 0 ]
   then
      echo "ERROR - Failed to create S3 bucket"
      exit 1
   fi
fi
aws s3api head-bucket --bucket $AWS_S3_BUCKET 2>/dev/null
if [ $? -ne 0 ]
then
   echo "ERROR - Failed to locate S3 bucket"
   exit 1
fi

# generate policy documents
INSTANCE_POLICY_DOC=`mktemp`
cat << EOF > ${INSTANCE_POLICY_DOC}
{
   "Version": "2012-10-17",
   "Statement": [
      {
         "Effect": "Allow",
         "Action": [
            "ec2:DescribeImages",
            "ec2:DescribeTags",
            "route53:ListHostedZones"
         ],
         "Resource" : "*"
      },
      {
         "Effect": "Allow",
         "Action": [
            "route53:ChangeResourceRecordSets",
            "route53:GetChange",
            "route53:GetHostedZone",
            "route53:ListResourceRecordSets"
         ],
         "Resource" : "arn:aws:route53:::hostedzone/${HOSTED_ZONE}"
      },
      {
         "Effect": "Allow",
         "Action": [
            "ec2:AuthorizeSecurityGroupIngress"
         ],
         "Resource" : "arn:aws:ec2:::security-group/${AWS_SG_NAME}"
      },
      {
         "Effect": "Allow",
         "Action": [
            "s3:ListBucket",
            "s3:PutObject",
            "s3:GetObject",
            "s3:DeleteObject"
         ],
         "Resource": [
            "arn:aws:s3:::${AWS_S3_BUCKET}",
            "arn:aws:s3:::${AWS_S3_BUCKET}/*"
         ]
      }          
   ]
}
EOF
ASSUME_ROLE_POLICY_DOC=`mktemp`
cat << EOF > ${ASSUME_ROLE_POLICY_DOC}
{
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Principal": {
          "Service": "ec2.amazonaws.com"
        },
        "Action": "sts:AssumeRole"
      }
    ]
  }
EOF

# IAM configurations
echo "INFO - Configuring IAM"
aws iam create-role --role-name $AWS_IAM_NAME --assume-role-policy-document file://${ASSUME_ROLE_POLICY_DOC} --description "IAM role for a Minecraft server" 2>/dev/null
aws iam detach-role-policy --role-name $AWS_IAM_NAME --policy-arn arn:aws:iam::${AWS_ACCOUNT_ID}:policy/${AWS_IAM_NAME} 2>/dev/null
aws iam delete-policy --policy-arn arn:aws:iam::${AWS_ACCOUNT_ID}:policy/${AWS_IAM_NAME} 2>/dev/null
aws iam create-policy --policy-name $AWS_IAM_NAME --policy-document file://${INSTANCE_POLICY_DOC} --description "IAM policy that grants required permissions for Minecraft servers" >/dev/null
if [ $? -eq 0 ]
then
   aws iam attach-role-policy --role-name $AWS_IAM_NAME --policy-arn arn:aws:iam::${AWS_ACCOUNT_ID}:policy/${AWS_IAM_NAME}
   aws iam create-instance-profile --instance-profile-name $AWS_IAM_NAME 2>/dev/null
   aws iam add-role-to-instance-profile --instance-profile-name $AWS_IAM_NAME --role-name $AWS_IAM_NAME 2>/dev/null
else
   echo "ERROR - Failed to create IAM policy"
fi

# Network configurations
echo "INFO - Configuring EC2"
aws ec2 create-security-group --region $AWS_REGION --vpc-id $AWS_DEFAULT_VPC --description "SG for Minecraft servers" --group-name $AWS_SG_NAME 2>/dev/null
aws ec2 authorize-security-group-ingress --region $AWS_REGION --group-name $AWS_SG_NAME --protocol tcp --port 22 --cidr 0.0.0.0/0 2>/dev/null

# Cleanup
rm -f $ASSUME_ROLE_POLICY_DOC
rm -f $INSTANCE_POLICY_DOC

echo "INFO - Complete"
