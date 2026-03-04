variable "aws_region" {
  description = "AWS region to deploy resources in"
  type        = string
  default     = "eu-central-1"
}

variable "project_name" {
  description = "A name prefix for all resources, to keep things organized"
  type        = string
  default     = "ansible-lab"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR block for the public subnet (AWX lives here)"
  type        = string
  default     = "10.0.1.0/24"
}

variable "private_subnet_cidr" {
  description = "CIDR block for the private subnet (PostgreSQL lives here)"
  type        = string
  default     = "10.0.2.0/24"
}

variable "availability_zone" {
  description = "Availability zone to use for both subnets"
  type        = string
  default     = "eu-central-1a"
}

variable "awx_instance_type" {
  description = "EC2 instance type for the AWX/Docker node"
  type        = string
  default     = "t3.medium"
}

variable "postgres_instance_type" {
  description = "EC2 instance type for the PostgreSQL node"
  type        = string
  default     = "t3.small"
}

variable "key_pair_name" {
  description = "Name of an existing EC2 Key Pair for SSH access. You must create this in the AWS console first."
  type        = string
  # No default - you must provide this when running terraform apply
}

variable "your_ip_cidr" {
  description = "Your public IP in CIDR format (e.g. 1.2.3.4/32) - used to restrict SSH access to only you"
  type        = string
  # Example: run 'curl ifconfig.me' to find your IP, then add /32
}

variable "postgres_password" {
  description = "Password for the PostgreSQL AWX database user"
  type        = string
  sensitive   = true
  default     = "ChangeMe_AWX_2026!"
}
