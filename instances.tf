# -------------------------------------------------------
# EC2 - AWX / Docker Node (Public Subnet)
# This instance runs Docker and hosts AWX as a container
# -------------------------------------------------------
resource "aws_instance" "awx" {
  ami                    = data.aws_ami.amazon_linux_2023.id
  instance_type          = var.awx_instance_type
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.awx.id]
  key_name               = var.key_pair_name

  # Root volume - AWX + Docker images need decent space
  root_block_device {
    volume_size           = 30   # GB
    volume_type           = "gp3"
    delete_on_termination = true

    tags = {
      Name    = "${var.project_name}-awx-root-volume"
      Project = var.project_name
    }
  }

  # templatefile() reads awx_userdata.sh and substitutes the variables
  # The postgres IP is only known after the postgres instance is created
  user_data = templatefile("${path.module}/awx_userdata.sh", {
    postgres_private_ip = aws_instance.postgres.private_ip
    postgres_password   = var.postgres_password
  })

  tags = {
    Name    = "${var.project_name}-awx"
    Role    = "AWX-Docker"
    Project = var.project_name
  }

  # Make sure networking is ready before creating instances
  depends_on = [
    aws_internet_gateway.main,
    aws_instance.postgres
  ]
}

# -------------------------------------------------------
# EC2 - PostgreSQL Node (Private Subnet)
# This instance runs PostgreSQL to back AWX
# -------------------------------------------------------
resource "aws_instance" "postgres" {
  ami                    = data.aws_ami.amazon_linux_2023.id
  instance_type          = var.postgres_instance_type
  subnet_id              = aws_subnet.private.id
  vpc_security_group_ids = [aws_security_group.postgres.id]
  key_name               = var.key_pair_name

  # Root volume
  root_block_device {
    volume_size           = 30   # GB - plenty for a lab database
    volume_type           = "gp3"
    delete_on_termination = true

    tags = {
      Name    = "${var.project_name}-postgres-root-volume"
      Project = var.project_name
    }
  }

  # Bootstrap PostgreSQL on first boot
  user_data = templatefile("${path.module}/postgres_userdata.sh", {
    postgres_password = var.postgres_password
  })

  tags = {
    Name    = "${var.project_name}-postgres"
    Role    = "PostgreSQL"
    Project = var.project_name
  }

  depends_on = [aws_nat_gateway.main]
}
