variable "key_name" {
  description = "Desired name of AWS key pair"
  default = "svcn26-ssh-pub"
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

variable "linux_ami_id" {
  description = "Custom AMI created with Packer and based on RHEL7 - https://aws.amazon.com/marketplace/pp/B08KSFB57X"
  default     = "ami-0ad900ff53030830f"
}
