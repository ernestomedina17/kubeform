#!/bin/bash

terraform init
terraform plan
terraform apply -auto-approve
packer validate jenkins-ami.json
packer build jenkins-ami.json
terraform destroy -auto-approve

