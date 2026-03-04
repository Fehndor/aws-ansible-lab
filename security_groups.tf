# -------------------------------------------------------
# SECURITY GROUP - AWX / Docker EC2 (Public)
# Controls inbound and outbound traffic for the AWX node
# -------------------------------------------------------
resource "aws_security_group" "awx" {
  name        = "${var.project_name}-awx-sg"
  description = "Security group for AWX/Docker EC2 in public subnet"
  vpc_id      = aws_vpc.main.id

  # SSH access - only from YOUR IP address, not the whole internet
  ingress {
    description = "SSH from your IP only"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.your_ip_cidr]
  }

  # AWX Web UI - HTTP (port 80) from your IP
  ingress {
    description = "AWX Web UI HTTP from your IP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [var.your_ip_cidr]
  }

  # AWX Web UI - HTTPS (port 443) from your IP
  ingress {
    description = "AWX Web UI HTTPS from your IP"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.your_ip_cidr]
  }

  # AWX via K3s NodePort - fallback direct access
  ingress {
    description = "AWX NodePort from your IP"
    from_port   = 30080
    to_port     = 30080
    protocol    = "tcp"
    cidr_blocks = [var.your_ip_cidr]
  }
  
  #tmp port forward
  ingress {
    description = "AWX temp port-forward"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = [var.your_ip_cidr]
  }

  # All outbound traffic allowed (needed for Docker pulls, AWS API calls, etc.)
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "${var.project_name}-awx-sg"
    Project = var.project_name
  }
}

# -------------------------------------------------------
# SECURITY GROUP - PostgreSQL EC2 (Private)
# Only accepts connections from the AWX security group
# This is the key security principle: DB not exposed to internet
# -------------------------------------------------------
resource "aws_security_group" "postgres" {
  name        = "${var.project_name}-postgres-sg"
  description = "Security group for PostgreSQL EC2 in private subnet"
  vpc_id      = aws_vpc.main.id

  # PostgreSQL port - only from the AWX security group
  # This means: only the AWX EC2 can talk to the database
  ingress {
    description     = "PostgreSQL from AWX security group only"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.awx.id]
  }

  # SSH from AWX only - useful if you need to troubleshoot the DB server
  # by first SSH-ing into AWX, then from there SSH-ing into Postgres (jump host pattern)
  ingress {
    description     = "SSH via AWX jump host"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.awx.id]
  }

  # All outbound allowed (for yum updates through NAT gateway)
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "${var.project_name}-postgres-sg"
    Project = var.project_name
  }
}
