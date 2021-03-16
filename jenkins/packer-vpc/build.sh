#!/bin/bash

# Get latest ID
aws ssm get-parameters-by-path --path /aws/service/ami-amazon-linux-latest | egrep -i 'value|date|arn'

# install ansible roles
ansible-galaxy install ernestomedina17.java
ansible-galaxy install ernestomedina17.jenkins

# terraform - aws vpc
terraform init
terraform plan
terraform apply -auto-approve
packer validate jenkins-ami.json

# packer aws ami 
time packer build -force \
 -var vpc_id=$(terraform output -raw vpc_id) \
 -var subnet_id=$(terraform output -raw subnet_id) \
 -var security_group_id=$(terraform output -raw security_group_id) \
 jenkins-ami-v2.json

# clean up
terraform destroy -auto-approve

