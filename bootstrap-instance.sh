#!/bin/bash

# retrieve needed values from our metadata
AWS_INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
AWS_AVZONE=$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone)
AWS_REGION=${AWS_AVZONE::-1}
IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)

# retrieve and save the instance tags (see launch-aws.sh)
echo "Retrieve instance tags"
aws ec2 describe-tags --region $AWS_REGION --filter "Name=resource-id,Values=$AWS_INSTANCE_ID" --output=text | sed -r 's/TAGS\t(.*)\t.*\t.*\t(.*)/\1="\2"/' > /etc/ec2-tags
. /etc/ec2-tags

# extract domain name from the FQDN
DOMAIN_NAME=$(echo $FQDN | awk -F. '{$1="";OFS="." ; print $0}' | sed 's/^.//')

# find the target hosted zone
echo "Retrieve hosted zone"
HOSTED_ZONE=$(aws route53 list-hosted-zones --query 'HostedZones[?starts_with(Name, `'$DOMAIN_NAME'`)==`true`].[Id]' --output text | cut -d / -f 3)

# create changeset for our A record
COMMENT="Auto updating @ `date`"
cat > ~/dns.json << EOF
{
	"Comment":"$COMMENT",
		"Changes":[
		{
			"Action":"UPSERT",
			"ResourceRecordSet":{
				"ResourceRecords":[
						{
							"Value":"$IP"
						}
					],
					"Name":"$FQDN",
					"Type":"A",
					"TTL":60
			}
		}
	]
}
EOF
echo "Setting A record"
aws route53 change-resource-record-sets --hosted-zone-id $HOSTED_ZONE --change-batch file://~/dns.json

# download and start our containers
sudo yum install -y git
git clone $REPO_URL repo
cd repo
docker-compose up -d
