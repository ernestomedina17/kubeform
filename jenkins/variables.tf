variable "key_name" {
  description = "Desired name of AWS key pair"
  default = "sysadmin-ssh-pub"
}

variable "public_key_path" {
  description = "SSH RSA Pub Key"
  default = "~/.ssh/id_rsa.pub"
}

variable "private_key_path" {
  description = "SSH RSA Key"
  default = "~/.ssh/id_rsa"
}

variable "aws_region" {
  description = "AWS region to launch servers."
  default     = "us-east-2"
}

# List AWS managed AMIs - https://us-east-2.console.aws.amazon.com/imagebuilder/home?region=us-east-2#/images 
# https://us-east-2.console.aws.amazon.com/systems-manager/parameters/aws/service/ecs/optimized-ami/amazon-linux-2/recommended/image_id/description?region=us-east-2#
variable "linux_ami_id" {
  description = "Custom AMI created with Packer based on ami-09c93f5e8e4b50e05 /aws/service/ecs/optimized-ami/amazon-linux-2/recommended/image_id"
  default     = "ami-09c93f5e8e4b50e05"
}
