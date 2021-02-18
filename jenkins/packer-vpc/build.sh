#!/bin/bash

terraform init
terraform plan
terraform apply -auto-approve
packer validate jenkins-ami.json

packer build \
 -var vpc_id=$(terraform output -raw vpc_id) \
 -var subnet_id=$(terraform output -raw subnet_id) \
 -var security_group_id=$(terraform output -raw security_group_id) \
 jenkins-ami.json

terraform destroy -auto-approve

