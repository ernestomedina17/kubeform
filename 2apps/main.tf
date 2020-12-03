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
  cidr_block = "153.2.0.0/16"
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
  cidr_block              = "153.2.0.0/23"
  map_public_ip_on_launch = true
  availability_zone	  = "us-east-2a"
}

resource "aws_subnet" "zone-b" {
  vpc_id                  = aws_vpc.default.id
  cidr_block              = "153.2.2.0/23"
  map_public_ip_on_launch = true
  availability_zone	  = "us-east-2b"
}

# Firewall - Same rules for both LBs
resource "aws_security_group" "lb-fw" {
  name        = "lb-fw"
  description = "Allow HTTP traffic"
  vpc_id      = aws_vpc.default.id

  # HTTP to HTTPS redirect, access from anywhere
  ingress {
    from_port   = 80
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTPS access from anywhere
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # SSL Termination for 8080
  ingress {
    from_port   = 443
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # SSL Termination for 5000
  ingress {
    from_port   = 443
    to_port     = 5000
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


# Our default security group to access
# the instances over SSH and HTTP
resource "aws_security_group" "default" {
  name        = "default-fw"
  description = "EC2 FW"
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
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["153.2.0.0/20"]
  }

  ingress {
    from_port   = 5000
    to_port     = 5000
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


resource "aws_lb" "app1-lb" {
  name               = "app1-lb"
  load_balancer_type = "application"
  internal           = false
  subnets            = [aws_subnet.zone-a.id, aws_subnet.zone-b.id]
  security_groups    = [aws_security_group.lb-fw.id]
}

resource "aws_lb" "app2-lb" {
  name               = "app2-lb"
  load_balancer_type = "application"
  internal           = false
  subnets            = [aws_subnet.zone-a.id, aws_subnet.zone-b.id]
  security_groups    = [aws_security_group.lb-fw.id]
}


resource "aws_lb_target_group" "app1-lb-tgt-grp-8080" {
  name     = "app1-lb-tgt-gpr-8080"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = aws_vpc.default.id
}

resource "aws_lb_target_group" "app1-lb-tgt-grp-5000" {
  name     = "app1-lb-tgt-gpr-5000"
  port     = 5000
  protocol = "HTTP"
  vpc_id   = aws_vpc.default.id
}


resource "aws_lb_target_group" "app2-lb-tgt-grp-8080" {
  name     = "app2-lb-tgt-gpr-8080"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = aws_vpc.default.id
}


resource "aws_lb_target_group_attachment" "app1-a-8080" {
  target_group_arn = aws_lb_target_group.app1-lb-tgt-grp-8080.arn
  target_id        = aws_instance.app1-a.id
  port             = 8080
}

resource "aws_lb_target_group_attachment" "app1-b-8080" {
  target_group_arn = aws_lb_target_group.app1-lb-tgt-grp-8080.arn
  target_id        = aws_instance.app1-b.id
  port             = 8080
}


resource "aws_lb_target_group_attachment" "app1-a-5000" {
  target_group_arn = aws_lb_target_group.app1-lb-tgt-grp-5000.arn
  target_id        = aws_instance.app1-a.id
  port             = 5000
}

resource "aws_lb_target_group_attachment" "app1-b-5000" {
  target_group_arn = aws_lb_target_group.app1-lb-tgt-grp-5000.arn
  target_id        = aws_instance.app1-b.id
  port             = 5000
}


resource "aws_lb_target_group_attachment" "app2-a-8080" {
  target_group_arn = aws_lb_target_group.app2-lb-tgt-grp-8080.arn
  target_id        = aws_instance.app2-a.id
  port             = 8080
}

resource "aws_lb_target_group_attachment" "app2-b-8080" {
  target_group_arn = aws_lb_target_group.app2-lb-tgt-grp-8080.arn
  target_id        = aws_instance.app2-b.id
  port             = 8080
}


resource "aws_lb_listener" "app1-lb-lsr-01" {
  load_balancer_arn = aws_lb.app1-lb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

resource "aws_lb_listener" "app2-lb-lsr-01" {
  load_balancer_arn = aws_lb.app2-lb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}


resource "aws_lb_listener" "app1-lb-lsr-02" {
  load_balancer_arn = aws_lb.app1-lb.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = "arn:aws:acm:us-east-2:055317306440:certificate/e50daa5d-f63c-46a4-9399-aa78c2070ee7"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app1-lb-tgt-grp-8080.arn
  }
}

resource "aws_lb_listener" "app2-lb-lsr-02" {
  load_balancer_arn = aws_lb.app2-lb.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = "arn:aws:acm:us-east-2:055317306440:certificate/e50daa5d-f63c-46a4-9399-aa78c2070ee7"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app2-lb-tgt-grp-8080.arn
  }
}


resource "aws_key_pair" "auth" {
  key_name   = var.key_name
  public_key = file(var.public_key_path)
}

resource "aws_instance" "app1-a" {
  connection {
    type = "ssh"
    user = "ec2-user"
    host = self.public_ip
    private_key = file(var.private_key_path)
  }

  instance_type = "t2.micro"
  ami = var.linux_ami_id
  key_name = aws_key_pair.auth.id
  vpc_security_group_ids = [aws_security_group.default.id]
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
    AppName = "App1"
    NodeName = "App1-A"
  }
}

resource "aws_instance" "app1-b" {
  connection {
    type = "ssh"
    user = "ec2-user"
    host = self.public_ip
    private_key = file(var.private_key_path)
  }

  instance_type = "t2.micro"
  ami = var.linux_ami_id
  key_name = aws_key_pair.auth.id
  vpc_security_group_ids = [aws_security_group.default.id]
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
    AppName = "App1"
    NodeName = "App1-B"
  }
}

resource "aws_instance" "app2-a" {
  connection {
    type = "ssh"
    user = "ec2-user"
    host = self.public_ip
    private_key = file(var.private_key_path)
  }

  instance_type = "t2.micro"
  ami = var.linux_ami_id
  key_name = aws_key_pair.auth.id
  vpc_security_group_ids = [aws_security_group.default.id]
  subnet_id = aws_subnet.zone-a.id

  provisioner "remote-exec" {
    inline = [
      "echo 'Run Ansible Playbook'",
    ]
  }
  provisioner "local-exec" {
    command = "ansible-playbook -u ec2-user -i '${aws_instance.app2-a.public_ip},' --private-key ${var.private_key_path} -e 'public_ip=${aws_instance.app2-a.public_ip}' playbook-app2.yml"
  }

  tags = {
    AppName = "App2"
    NodeName = "App2-A"
  }
}

resource "aws_instance" "app2-b" {
  connection {
    type = "ssh"
    user = "ec2-user"
    host = self.public_ip
    private_key = file(var.private_key_path)
  }

  instance_type = "t2.micro"
  ami = var.linux_ami_id
  key_name = aws_key_pair.auth.id
  vpc_security_group_ids = [aws_security_group.default.id]
  subnet_id = aws_subnet.zone-b.id

  provisioner "remote-exec" {
    inline = [
      "echo 'Run Ansible Playbook'",
    ]
  }
  provisioner "local-exec" {
    command = "ansible-playbook -u ec2-user -i '${aws_instance.app2-b.public_ip},' --private-key ${var.private_key_path} -e 'public_ip=${aws_instance.app2-b.public_ip}' playbook-app2.yml"
  }

  tags = {
    AppName = "App2"
    NodeName = "App2-B"
  }
}


data "aws_route53_zone" "mariannmiranda-com" {
  name         = "mariannmiranda.com."
  private_zone = false
}

resource "aws_route53_record" "app1" {
  zone_id = data.aws_route53_zone.mariannmiranda-com.zone_id
  name    = "app1.${data.aws_route53_zone.mariannmiranda-com.name}"
  type    = "A"

  alias {
    name                   = aws_lb.app1-lb.dns_name
    zone_id                = aws_lb.app1-lb.zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "app2" {
  zone_id = data.aws_route53_zone.mariannmiranda-com.zone_id
  name    = "app2.${data.aws_route53_zone.mariannmiranda-com.name}"
  type    = "A"

  alias {
    name                   = aws_lb.app2-lb.dns_name
    zone_id                = aws_lb.app2-lb.zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_zone" "default" {
  name = "mariannmiranda.com"

  vpc {
    vpc_id = aws_vpc.default.id
  }
}


##### VPN 
resource "aws_vpc" "vpn" {
  cidr_block = "10.8.224.0/19"
}

# Subnets
resource "aws_subnet" "vpn-zone-a" {
  vpc_id                  = aws_vpc.vpn.id
  cidr_block              = "10.8.224.0/23"
  map_public_ip_on_launch = true
  availability_zone       = "us-east-2a"
}

resource "aws_subnet" "vpn-zone-b" {
  vpc_id                  = aws_vpc.vpn.id
  cidr_block              = "10.8.226.0/23"
  map_public_ip_on_launch = true
  availability_zone       = "us-east-2b"
}


##### Office 
resource "aws_vpc" "office" {
  cidr_block = "156.134.176.0/20"
}

# Subnets
resource "aws_subnet" "office-zone-a" {
  vpc_id                  = aws_vpc.office.id
  cidr_block              = "156.134.176.0/23"
  map_public_ip_on_launch = true
  availability_zone       = "us-east-2a"
}

resource "aws_subnet" "office-zone-b" {
  vpc_id                  = aws_vpc.office.id
  cidr_block              = "156.134.178.0/23"
  map_public_ip_on_launch = true
  availability_zone       = "us-east-2c"
}


