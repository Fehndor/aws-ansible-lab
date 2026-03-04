# -------------------------------------------------------
# VPC
# The Virtual Private Cloud - your isolated network in AWS
# -------------------------------------------------------
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true   # Needed so EC2 instances can resolve DNS names
  enable_dns_hostnames = true   # Gives EC2 instances DNS names within the VPC

  tags = {
    Name    = "${var.project_name}-vpc"
    Project = var.project_name
  }
}

# -------------------------------------------------------
# PUBLIC SUBNET
# AWX/Docker EC2 lives here. Has a route to the internet.
# -------------------------------------------------------
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidr
  availability_zone       = var.availability_zone
  map_public_ip_on_launch = true  # EC2s launched here automatically get a public IP

  tags = {
    Name    = "${var.project_name}-public-subnet"
    Project = var.project_name
  }
}

# -------------------------------------------------------
# PRIVATE SUBNET
# PostgreSQL EC2 lives here. No direct route to internet.
# -------------------------------------------------------
resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidr
  availability_zone = var.availability_zone
  # Note: map_public_ip_on_launch is false by default - correct for private subnet

  tags = {
    Name    = "${var.project_name}-private-subnet"
    Project = var.project_name
  }
}

# -------------------------------------------------------
# INTERNET GATEWAY
# Attaches to the VPC and allows traffic to/from internet
# for resources in the public subnet
# -------------------------------------------------------
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name    = "${var.project_name}-igw"
    Project = var.project_name
  }
}

# -------------------------------------------------------
# ELASTIC IP for NAT Gateway
# A static public IP address that the NAT gateway uses
# -------------------------------------------------------
resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name    = "${var.project_name}-nat-eip"
    Project = var.project_name
  }

  # Must be created after the internet gateway exists
  depends_on = [aws_internet_gateway.main]
}

# -------------------------------------------------------
# NAT GATEWAY
# Lives in the PUBLIC subnet, but serves the PRIVATE subnet.
# Allows PostgreSQL EC2 to reach the internet (for yum updates,
# package installs etc.) without being reachable FROM the internet.
# -------------------------------------------------------
resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public.id  # NAT GW must be in public subnet

  tags = {
    Name    = "${var.project_name}-nat-gw"
    Project = var.project_name
  }

  depends_on = [aws_internet_gateway.main]
}

# -------------------------------------------------------
# ROUTE TABLE - PUBLIC
# Routes all internet traffic (0.0.0.0/0) through the IGW
# -------------------------------------------------------
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name    = "${var.project_name}-public-rt"
    Project = var.project_name
  }
}

# Associate the public route table with the public subnet
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# -------------------------------------------------------
# ROUTE TABLE - PRIVATE
# Routes internet-bound traffic through the NAT Gateway
# (so private subnet can reach internet, but not vice versa)
# -------------------------------------------------------
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }

  tags = {
    Name    = "${var.project_name}-private-rt"
    Project = var.project_name
  }
}

# Associate the private route table with the private subnet
resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private.id
}
