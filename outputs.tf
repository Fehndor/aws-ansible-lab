# -------------------------------------------------------
# OUTPUTS
# These values are printed after 'terraform apply' completes
# -------------------------------------------------------

output "awx_public_ip" {
  description = "Public IP of the AWX EC2 - use this to SSH in and access the AWX Web UI"
  value       = aws_instance.awx.public_ip
}

output "awx_public_dns" {
  description = "Public DNS name of the AWX EC2"
  value       = aws_instance.awx.public_dns
}

output "awx_web_ui_url" {
  description = "URL to access AWX Web UI (may take 5-10 minutes after apply for Docker to start)"
  value       = "http://${aws_instance.awx.public_dns}:8080"
}

output "postgres_private_ip" {
  description = "Private IP of the PostgreSQL EC2 - only reachable from within the VPC"
  value       = aws_instance.postgres.private_ip
}

output "ssh_command_awx" {
  description = "SSH command to connect to the AWX instance"
  value       = "ssh -i ~/.ssh/${var.key_pair_name}.pem ec2-user@${aws_instance.awx.public_ip}"
}

output "ssh_command_postgres_via_awx" {
  description = "SSH to PostgreSQL via AWX as a jump host (ProxyJump)"
  value       = "ssh -i ~/.ssh/${var.key_pair_name}.pem -J ec2-user@${aws_instance.awx.public_ip} ec2-user@${aws_instance.postgres.private_ip}"
}

output "vpc_id" {
  description = "ID of the created VPC"
  value       = aws_vpc.main.id
}

output "nat_gateway_public_ip" {
  description = "Public IP of the NAT Gateway (private subnet traffic exits through this)"
  value       = aws_eip.nat.public_ip
}
