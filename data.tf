# -------------------------------------------------------
# AMI DATA SOURCE
# Automatically fetches the latest Amazon Linux 2023 AMI
# for the selected region. This way the code stays up to
# date without hardcoding an AMI ID.
# -------------------------------------------------------
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
} 

