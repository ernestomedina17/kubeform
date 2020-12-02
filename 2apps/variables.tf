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
  description = "RHEL7 AMI - https://aws.amazon.com/marketplace/pp/B08KSFB57X"
  default     = "ami-05fb6f2cb5192cf18"
}
