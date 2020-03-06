provider "aws" {
  version = "~> 2.5"
  region  = "us-east-2"
}

resource "aws_organizations_organizational_unit" "ou" {
  name      = "Information Technology"
  parent_id = "r-pkgo"
}

resource "aws_iam_role" "eks-role" {
  name = "cluster-admin"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "eks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy_attachment" "AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks-role.name
}

resource "aws_iam_role_policy_attachment" "AmazonEKSServicePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
  role       = aws_iam_role.eks-role.name
}

### Network
resource "aws_vpc" "eks-vpc" {
  cidr_block = "192.168.1.0/27"
  enable_dns_hostnames = true

  tags = {
    "kubernetes.io/cluster/dev" = "shared"
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_subnet" "eks-subnet-priv" {
  count = 2

  availability_zone = data.aws_availability_zones.available.names[count.index]
  cidr_block        = cidrsubnet(aws_vpc.eks-vpc.cidr_block, 1, count.index)
  vpc_id            = aws_vpc.eks-vpc.id
  map_public_ip_on_launch = true

  tags = {
    # https://docs.aws.amazon.com/eks/latest/userguide/network_reqs.html
    "kubernetes.io/cluster/dev" = "shared"
    "kubernetes.io/role/internal-elb" = 1
  }
}

### Cluster
resource "aws_eks_cluster" "k8s" {
  name     = "dev"
  role_arn = aws_iam_role.eks-role.arn
  version  = "1.14"

  vpc_config {
    subnet_ids = aws_subnet.eks-subnet-priv[*].id
    endpoint_public_access = true
    endpoint_private_access = true
    public_access_cidrs = ["0.0.0.0/0"]
    security_group_ids = [aws_security_group.kube-cluster.id]
  }

  # Ensure that IAM Role permissions are created before and deleted after EKS Cluster handling.
  # Otherwise, EKS will not be able to properly delete EKS managed EC2 infrastructure such as Security Groups.
  depends_on = [
    aws_iam_role_policy_attachment.AmazonEKSClusterPolicy,
    aws_iam_role_policy_attachment.AmazonEKSServicePolicy,
    aws_cloudwatch_log_group.eks-log-group,
  ]

  enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler",]
}

resource "aws_cloudwatch_log_group" "eks-log-group" {
  name              = "/aws/eks/k8s/cluster"
  retention_in_days = 7
}

output "endpoint" {
  value = aws_eks_cluster.k8s.endpoint
}

output "kubeconfig-certificate-authority-data" {
  value = aws_eks_cluster.k8s.certificate_authority.0.data
}


resource "aws_iam_role" "eks-role2" {
  name = "node-creator"

  assume_role_policy = jsonencode({
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
    Version = "2012-10-17"
  })
}

resource "aws_iam_role_policy_attachment" "AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks-role2.name
}

resource "aws_iam_role_policy_attachment" "AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks-role2.name
}

resource "aws_iam_role_policy_attachment" "AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks-role2.name
}

resource "aws_eks_node_group" "eks-nodes" {
  cluster_name    = aws_eks_cluster.k8s.name
  node_group_name = "community-of-the-ring"
  node_role_arn   = aws_iam_role.eks-role2.arn
  subnet_ids = aws_subnet.eks-subnet-priv[*].id

  scaling_config {
    desired_size = 1
    max_size     = 1
    min_size     = 1
  }

  # Ensure that IAM Role permissions are created before and deleted after EKS Node Group handling.
  # Otherwise, EKS will not be able to properly delete EC2 Instances and Elastic Network Interfaces.
  depends_on = [
    aws_iam_role_policy_attachment.AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.AmazonEC2ContainerRegistryReadOnly,
  ]
  
  ami_type = "AL2_x86_64"
  disk_size = 20
  instance_types = ["t3.medium"]
  version  = "1.14"

  remote_access {
    ec2_ssh_key = aws_key_pair.ssh.key_name
    source_security_group_ids = [aws_security_group.kube-cluster.id]
  }
}

resource "aws_key_pair" "ssh" {
  key_name   = "centos8"
  public_key = file("~/.ssh/id_rsa.pub")
}

resource "aws_security_group" "kube-cluster" {
  name        = "firewall"
  description = "Enable communication between the control plane and the worker nodes"
  vpc_id      = aws_vpc.eks-vpc.id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["192.168.1.0/27"]
  }

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
    #prefix_list_ids = [aws_vpc_endpoint.eks.id]
  }
}

#resource "aws_vpc_endpoint" "eks" {
#  vpc_id       = aws_vpc.eks-vpc.id
#  service_name = "com.amazonaws.us-east-2.s3"
#}

resource "aws_internet_gateway" "default" {
  vpc_id      = aws_vpc.eks-vpc.id
}

resource "aws_route_table" "lonely-road" {
  vpc_id      = aws_vpc.eks-vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.default.id
  }
}

resource "aws_route_table_association" "subnet-association" {
  count = 2
  subnet_id      = aws_subnet.eks-subnet-priv[count.index].id
  route_table_id = aws_route_table.lonely-road.id
}

