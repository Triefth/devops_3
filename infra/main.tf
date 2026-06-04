terraform {
  required_providers {
    aws = {
        source = "hashicorp/aws"
        version = "~>5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

# Rol de AWS Academy
data "aws_iam_role" "labrole" {
  name = "LabRole"
}

# ====== 1. REDES (Al estilo del profesor) ======
resource "aws_vpc" "eks_vpc" {
  cidr_block = "10.0.0.0/16"
  tags = { Name = "eks-vpc" }
}

resource "aws_subnet" "eks_subnet_1" {
  vpc_id                  = aws_vpc.eks_vpc.id
  cidr_block              = "10.0.10.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true
  tags = { Name = "eks-subnet-1" }
}

resource "aws_subnet" "eks_subnet_2" {
  vpc_id                  = aws_vpc.eks_vpc.id
  cidr_block              = "10.0.20.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true
  tags = { Name = "eks-subnet-2" }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.eks_vpc.id
  tags = { Name = "eks-igw" }
}

resource "aws_route_table" "rt" {
  vpc_id = aws_vpc.eks_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = { Name = "eks-route-table" }
}

resource "aws_route_table_association" "rta_1" {
  subnet_id      = aws_subnet.eks_subnet_1.id
  route_table_id = aws_route_table.rt.id
}

resource "aws_route_table_association" "rta_2" {
  subnet_id      = aws_subnet.eks_subnet_2.id
  route_table_id = aws_route_table.rt.id
}

# ====== 2. EKS (KUBERNETES) ======
resource "aws_eks_cluster" "eks" {
  name     = "devops3-cluster"
  role_arn = data.aws_iam_role.labrole.arn
  vpc_config {
    subnet_ids = [aws_subnet.eks_subnet_1.id, aws_subnet.eks_subnet_2.id]
  }
}

resource "aws_eks_node_group" "workers" {
  cluster_name    = aws_eks_cluster.eks.name
  node_group_name = "workers"
  node_role_arn   = data.aws_iam_role.labrole.arn
  subnet_ids      = [aws_subnet.eks_subnet_1.id, aws_subnet.eks_subnet_2.id]
  
  scaling_config {
    desired_size = 2
    max_size     = 3
    min_size     = 1
  }
  instance_types = ["t3.medium"]
  capacity_type  = "ON_DEMAND"
}

# ====== 3. REPOSITORIOS ECR (Adaptados a tu proyecto) ======
resource "aws_ecr_repository" "repo_front" {
  name = "devops-frontend"
  image_scanning_configuration { scan_on_push = true }
  force_delete = true
}

resource "aws_ecr_repository" "repo_ventas" {
  name = "devops-back-ventas"
  image_scanning_configuration { scan_on_push = true }
  force_delete = true
}

resource "aws_ecr_repository" "repo_despachos" {
  name = "devops-back-despachos"
  image_scanning_configuration { scan_on_push = true }
  force_delete = true
}

# ====== 4. OUTPUTS ======
output "cluster_name" {
  value = aws_eks_cluster.eks.name
}

output "cluster_endpoint" {
  value = aws_eks_cluster.eks.endpoint
}