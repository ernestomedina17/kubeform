variable "key_name" {
  description = "Jenkins SSH Pub Key"
  default = "jenkins-ssh-pub"
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

