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

  # HTTP access from anywhere
  ingress {
    from_port   = 80
    to_port     = 8080
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

  # HTTP access from the VPC, Port forward
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

# 3.140.156.177 app1.mariannmiranda.com 
data "aws_eip" "app1-eip" {
  id = "eipalloc-066d40c1a2b14b042" 
}

#  3.140.78.72   app2.mariannmiranda.com 
data "aws_eip" "app2-eip" {
  id = "eipalloc-004c409f6ad310ee9" 
}

resource "aws_lb" "app1-lb" {
  name               = "app1-lb"
  load_balancer_type = "application"
  internal           = false
  subnets            = [aws_subnet.zone-a.id, aws_subnet.zone-b.id]
  security_groups    = [aws_security_group.lb-fw.id]

  #subnet_mapping {
  #  subnet_id     = aws_subnet.default.id
  #  allocation_id = data.aws_eip.app1-eip.id
  #}
}

resource "aws_lb" "app2-lb" {
  name               = "app2-lb"
  load_balancer_type = "application"
  internal           = false
  subnets            = [aws_subnet.zone-a.id, aws_subnet.zone-b.id]
  security_groups    = [aws_security_group.lb-fw.id]

  #subnet_mapping {
  #  subnet_id     = aws_subnet.default.id
  #  allocation_id = data.aws_eip.app2-eip.id
  #}
}


resource "aws_lb_target_group" "app1-lb-tgt-grp-8080" {
  name     = "app1-lb-tgt-gpr-8080"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = aws_vpc.default.id
}

resource "aws_lb_target_group" "app2-lb-tgt-grp-8080" {
  name     = "app2-lb-tgt-gpr-8080"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = aws_vpc.default.id
}


resource "aws_lb_target_group_attachment" "app1-a" {
  target_group_arn = aws_lb_target_group.app1-lb-tgt-grp-8080.arn
  target_id        = aws_instance.app1-a.id
  port             = 8080
}

resource "aws_lb_target_group_attachment" "app1-b" {
  target_group_arn = aws_lb_target_group.app1-lb-tgt-grp-8080.arn
  target_id        = aws_instance.app1-b.id
  port             = 8080
}


resource "aws_lb_target_group_attachment" "app2-a" {
  target_group_arn = aws_lb_target_group.app2-lb-tgt-grp-8080.arn
  target_id        = aws_instance.app2-a.id
  port             = 8080
}

resource "aws_lb_target_group_attachment" "app2-b" {
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
      port        = "8080"
      protocol    = "HTTP"
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
      port        = "8080"
      protocol    = "HTTP"
      status_code = "HTTP_301"
    }
  }
}


resource "aws_lb_listener" "app1-lb-lsr-02" {
  load_balancer_arn = aws_lb.app1-lb.arn
  port              = "8080"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app1-lb-tgt-grp-8080.arn
  }
}

resource "aws_lb_listener" "app2-lb-lsr-02" {
  load_balancer_arn = aws_lb.app2-lb.arn
  port              = "8080"
  protocol          = "HTTP"

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

