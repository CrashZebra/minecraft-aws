#!/bin/bash
#
# This Source Code Form is subject to the terms of the Mozilla Public
#  License, v. 2.0. If a copy of the MPL was not distributed with this
#  file, You can obtain one at http://mozilla.org/MPL/2.0/.

# NOTE:
# This script is executed (once) by cloud-init automatically when the instance is created

# retrieve needed values from our metadata
AWS_INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
AWS_AVZONE=$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone)
AWS_REGION=${AWS_AVZONE::-1}
AWS_SG_NAME=$(curl -s http://169.254.169.254/latest/meta-data/security-groups)
IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)

# retrieve and save the instance tags passed in by the launch script
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

# configure the security group for our port(s)
aws ec2 authorize-security-group-ingress --region $AWS_REGION --group-name $AWS_SG_NAME --protocol tcp --port 25565 --cidr 0.0.0.0/0 2>/dev/null

# install graceful termination script
cat > /etc/rc0.d/K10docker << EOF
#!/bin/bash
PATH=/usr/local/bin:/usr/bin:/usr/local/sbin:/usr/sbin
cd /repo
docker-compose stop -t 60
EOF

# install spot-instance termination handler which calls halt, which triggers the termination script above
cat > /root/watch-spot-termination.sh << EOF
#!/bin/bash
sleep 120
while true
do
   if [ -z $(curl -Is http://169.254.169.254/latest/meta-data/spot/termination-time | head -1 | grep 404 | cut -d \  -f 2) ]
   then
      halt
      break
   else
      sleep 5
   fi
done
EOF
cat >> /etc/rc.local << EOF
/root/watch-spot-termination.sh&
EOF
chmod +x /root/watch-spot-termination.sh
chmod +x /etc/rc.local
systemctl enable rc-local
systemctl start rc-local

# download and start our containers
yum install -y git
git clone $REPO_URL repo
cd repo
docker-compose up -d
