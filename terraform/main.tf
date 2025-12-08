provider "aws" { 
  region = var.aws_region
}

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = { Name = "hybrid-vpc" }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "main-igw" }
}

# Public Subnet A 
resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_a_cidr
  availability_zone       = "eu-central-1a"
  map_public_ip_on_launch = true
  tags = {
    Name                                       = "public-subnet-a"
    "kubernetes.io/cluster/innovatech-eks"     = "shared"
    "kubernetes.io/role/elb"                   = "1"
  }
}

# Public Subnet B 
resource "aws_subnet" "public_b" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_b_cidr
  availability_zone       = "eu-central-1b"
  map_public_ip_on_launch = true
  tags = {
    Name                                       = "public-subnet-b"
    "kubernetes.io/cluster/innovatech-eks"     = "shared"
    "kubernetes.io/role/elb"                   = "1"
  }
}

# Private Subnet A 
resource "aws_subnet" "private_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_a_cidr
  availability_zone = "eu-central-1a"
  tags = {
    Name                                       = "private-subnet-a"
    "kubernetes.io/cluster/innovatech-eks"     = "shared"
    "kubernetes.io/role/internal-elb"          = "1"
  }
}

# Private Subnet B 
resource "aws_subnet" "private_b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_b_cidr
  availability_zone = "eu-central-1b"
  tags = {
    Name                                       = "private-subnet-b"
    "kubernetes.io/cluster/innovatech-eks"     = "shared"
    "kubernetes.io/role/internal-elb"          = "1"
  }
}

