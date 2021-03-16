#!/bin/bash

# Get latest ID
aws ssm get-parameters-by-path --path /aws/service/ami-amazon-linux-latest | egrep -i 'value|date|arn'

terraform init
terraform plan
terraform apply -auto-approve
packer validate jenkins-ami.json

packer build -force \
 -var vpc_id=$(terraform output -raw vpc_id) \
 -var subnet_id=$(terraform output -raw subnet_id) \
 -var security_group_id=$(terraform output -raw security_group_id) \
 jenkins-ami-v2.json

terraform destroy -auto-approve

