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
  cidr_block = "192.168.0.0/24"
}

# Internet GW - Default VPC
resource "aws_internet_gateway" "default" {
  vpc_id = aws_vpc.default.id
}

# Grant Internet access to the Default VPC, required to update and download stuff from the Internet.
resource "aws_route" "internet_access" {
  route_table_id         = aws_vpc.default.main_route_table_id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.default.id
}

# Subnets
#resource "aws_subnet" "zone-a" {
#  vpc_id                  = aws_vpc.default.id
#  cidr_block              = "153.2.0.0/23"
#  map_public_ip_on_launch = true
#  availability_zone	  = "us-east-2a"
#}

# Firewall - Jenkins
resource "aws_security_group" "jenkins-fw" {
  name        = "jenkins-fw"
  description = "Allow HTTP traffic and SSH"
  vpc_id      = aws_vpc.default.id

  # Jenkins app port
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Jenkins SSH port
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


# Firewall - App
resource "aws_security_group" "app-fw" {
  name        = "app-fw"
  description = "Allow HTTP traffic and SSH"
  vpc_id      = aws_vpc.default.id

  # SSH access from anywhere
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTP access to the Apps from the Default VPC
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["153.2.0.0/20"]
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

resource "aws_instance" "jenkins" {
  connection {
    type = "ssh"
    user = "ec2-user"
    host = self.public_ip
    private_key = file(var.private_key_path)
  }

  instance_type = "t2.micro"
  ami = var.linux_ami_id
  key_name = aws_key_pair.auth.id
  vpc_security_group_ids = [aws_security_group.jenkins-fw.id]
  subnet_id = aws_subnet.zone-a.id

  provisioner "remote-exec" {
    inline = [
      "echo 'Run Ansible Playbook'",
    ]
  }

  provisioner "local-exec" {
    command = "ansible-playbook -u ec2-user -i '${aws_instance.app1-a.public_ip},' --private-key ${var.private_key_path} -e 'public_ip=${aws_instance.app1-a.public_ip}' playbook-app1.yml"
  }

  tags = {
    AppName = "Jenkins"
    NodeName = "Jenkins"
  }
}

resource "aws_instance" "App01" {
  connection {
    type = "ssh"
    user = "ec2-user"
    host = self.public_ip
    private_key = file(var.private_key_path)
  }

  instance_type = "t2.micro"
  ami = var.linux_ami_id
  key_name = aws_key_pair.auth.id
  vpc_security_group_ids = [aws_security_group.app-fw.id]
  subnet_id = aws_subnet.zone-b.id

  provisioner "remote-exec" {
    inline = [
      "echo 'Run Ansible Playbook'",
    ]
  }

  provisioner "local-exec" {
    command = "ansible-playbook -u ec2-user -i '${aws_instance.app1-b.public_ip},' --private-key ${var.private_key_path} -e 'public_ip=${aws_instance.app1-b.public_ip}' playbook-app1.yml"
  }

  tags = {
    AppName = "App01"
    NodeName = "App01"
  }
}


data "aws_route53_zone" "mariannmiranda-com" {
  name         = "mariannmiranda.com."
  private_zone = false
}

resource "aws_route53_record" "jenkins" {
  zone_id = data.aws_route53_zone.mariannmiranda-com.zone_id
  name    = "jenkins.${data.aws_route53_zone.mariannmiranda-com.name}"
  type    = "A"

  alias {
    name                   = aws_instance.jenkins.public_ip
    zone_id                = aws_instance.jenkins.zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "app01" {
  zone_id = data.aws_route53_zone.mariannmiranda-com.zone_id
  name    = "app01.${data.aws_route53_zone.mariannmiranda-com.name}"
  type    = "A"

  alias {
    name                   = aws_instance.app01.public_ip
    zone_id                = aws_instance.app01.zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_zone" "default" {
  name = "mariannmiranda.com"

  vpc {
    vpc_id = aws_vpc.default.id
  }
}

