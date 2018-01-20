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

# find the most recent base image AMI
AWS_AMI_ID=`aws ec2 describe-images --region ${AWS_REGION} --owner self \
   --filters "Name=name,Values=${AWS_BASE_AMI_PREFIX}*" --query 'Images[].[CreationDate,ImageId,Name]' --output text | sort -k1 | tail -n1 | awk '{print $2}'`
if [ $? -ne 0 ]
then
   echo "ERROR - Could not locate base AMI"
   exit 1
fi

# launch our minecraft-server instance
aws ec2 run-instances --region ${AWS_REGION} --image-id ${AWS_AMI_ID} --count 1 \
   --instance-type ${AWS_INSTANCE_TYPE} --key-name ${AWS_KEY_NAME} --security-groups ${AWS_SG_NAME} \
   --iam-instance-profile Name=${AWS_IAM_NAME} --user-data file://bootstrap-instance.sh \
   --tag-specifications "ResourceType=instance,Tags=[{Key=Description,Value=minecraft-server,{Key=FQDN,Value=${SERVER_FQDN}},{Key=REPO_URL,Value=${REPO_URL}}]"