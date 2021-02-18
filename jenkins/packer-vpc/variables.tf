variable "key_name" {
  description = "Jenkins Pub SSH Key Name"
  default = "jenkins"
}

variable "public_key_path" {
  description = "SSH RSA Pub Key Path"
  default = "~/.ssh/id_rsa.pub"
}

variable "private_key_path" {
  description = "SSH RSA Key"
  default = "~/.ssh/id_rsa"
}

variable "aws_region" {
  description = "AWS region"
  default     = "us-east-2"
}

