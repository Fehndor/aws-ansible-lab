#!/bin/bash
# -------------------------------------------------------
# WSL2 Ubuntu - Cloud Engineering Lab Setup Script
# Installs: Terraform, AWS CLI, and useful tools
# Run this once after setting up WSL2 with Ubuntu
#
# Usage:
#   chmod +x setup_wsl.sh
#   ./setup_wsl.sh
# -------------------------------------------------------

set -e

echo "============================================"
echo " WSL2 Cloud Lab Setup"
echo "============================================"
echo ""

echo "[1/6] Updating system packages..."
sudo apt update && sudo apt upgrade -y

echo "[2/6] Installing common tools..."
sudo apt install -y unzip curl git jq tree

echo "[3/6] Installing Terraform..."
sudo apt install -y gnupg software-properties-common
wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor | sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg > /dev/null
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install -y terraform
terraform version

echo "[4/6] Installing AWS CLI v2..."
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "/tmp/awscliv2.zip"
unzip -q /tmp/awscliv2.zip -d /tmp/
sudo /tmp/aws/install
rm -rf /tmp/awscliv2.zip /tmp/aws/
aws --version

echo "[5/6] Creating project directory structure..."
mkdir -p ~/projects/ansible-lab
mkdir -p ~/projects/ansible-playbooks
mkdir -p ~/.ssh
chmod 700 ~/.ssh
tree ~/projects

echo "[6/6] Enabling Terraform tab completion..."
terraform -install-autocomplete 2>/dev/null || true

echo "============================================"
echo " Setup complete! Next steps:"
echo "============================================"
echo ""
echo " 1. Configure AWS credentials:"
echo "    aws configure"
echo ""
echo " 2. Copy your .pem key into WSL:"
echo "    cp /mnt/c/Users/YourName/Downloads/your-key.pem ~/.ssh/"
echo "    chmod 400 ~/.ssh/your-key.pem"
echo ""
echo " 3. Run: curl ifconfig.me  (to find your IP for terraform.tfvars)"
echo ""