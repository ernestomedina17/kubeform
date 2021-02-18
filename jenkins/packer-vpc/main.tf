terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = var.aws_region
  # access_key = "export AWS_ACCESS_KEY_ID='' in .bashrc"
  # secret_key = "export AWS_SECRET_ACCESS_KEY='' in .bashrc"
}

# Default VPC
resource "aws_vpc" "default" {
  cidr_block = "172.31.0.0/16"
}

# Internet GW - Default VPC
resource "aws_internet_gateway" "default" {
  vpc_id = aws_vpc.default.id
}

# Grant Internet access to the Default VPC
resource "aws_route" "internet_access" {
  route_table_id         = aws_vpc.default.main_route_table_id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.default.id
}

# Subnets
resource "aws_subnet" "zone-a" {
  vpc_id                  = aws_vpc.default.id
  cidr_block              = "172.31.0.0/20"
  map_public_ip_on_launch = true
  availability_zone	  = "us-east-2a"
}

#resource "aws_subnet" "zone-b" {
#  vpc_id                  = aws_vpc.default.id
#  cidr_block              = "172.31.16.0/20"
#  map_public_ip_on_launch = true
#  availability_zone	  = "us-east-2b"
#}
#
#resource "aws_subnet" "zone-c" {
#  vpc_id                  = aws_vpc.default.id
#  cidr_block              = "172.31.32.0/20"
#  map_public_ip_on_launch = true
#  availability_zone	  = "us-east-2c"
#}

# Firewall - Security Group - SSH
resource "aws_security_group" "default" {
  name        = "default-fw"
  description = "EC2 FW for Packer"
  vpc_id      = aws_vpc.default.id

  # SSH access from anywhere
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # outbound internet access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


resource "aws_key_pair" "auth" {
  key_name   = var.key_name
  public_key = file(var.public_key_path)
}

