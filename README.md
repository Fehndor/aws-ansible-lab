# AWS Ansible Lab - Terraform

A Terraform project that provisions an AWX + PostgreSQL lab environment on AWS.

## Architecture

```
                    Internet
                       |
                  [Internet Gateway]
                       |
              ┌────────────────────┐
              │   VPC 10.0.0.0/16  │
              │                    │
              │  Public Subnet     │
              │  10.0.1.0/24       │
              │  ┌──────────────┐  │
              │  │  AWX / Docker│  │◄── SSH (your IP only)
              │  │  t3.medium   │  │◄── HTTP/HTTPS (your IP only)
              │  └──────┬───────┘  │
              │         │          │
              │  [NAT Gateway]     │
              │         │          │
              │  Private Subnet    │
              │  10.0.2.0/24       │
              │  ┌──────────────┐  │
              │  │  PostgreSQL  │  │◄── Port 5432 (AWX only)
              │  │  t3.small    │  │◄── SSH (via AWX jump host)
              │  └──────────────┘  │
              └────────────────────┘
```

## Files Overview

| File | Purpose |
|------|---------|
| `main.tf` | Provider configuration (AWS, region) |
| `variables.tf` | All input variable definitions |
| `networking.tf` | VPC, subnets, IGW, NAT GW, route tables |
| `security_groups.tf` | Security groups for AWX and PostgreSQL |
| `data.tf` | Fetches latest Amazon Linux 2023 AMI automatically |
| `instances.tf` | EC2 instances for AWX and PostgreSQL |
| `awx_userdata.sh` | Bootstrap script: installs Docker, Ansible, writes docker-compose |
| `postgres_userdata.sh` | Bootstrap script: installs and configures PostgreSQL |
| `outputs.tf` | Prints useful info (IPs, SSH commands) after apply |
| `terraform.tfvars.example` | Template for your variable values |
| `.gitignore` | Prevents secrets and state files from being committed |

## Prerequisites

1. [Terraform installed](https://developer.hashicorp.com/terraform/install) (>= 1.5.0)
2. AWS CLI configured with your credentials (`aws configure`)
3. An EC2 Key Pair created in AWS Console (EU-Central-1 region)

## Usage

### Step 1 - Set up your variables

```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` with your values:
- `key_pair_name` - the name of your EC2 Key Pair
- `your_ip_cidr` - run `curl ifconfig.me` and add `/32` (e.g. `1.2.3.4/32`)
- `postgres_password` - choose a strong password

### Step 2 - Initialize Terraform

```bash
terraform init
```

This downloads the AWS provider plugin.

### Step 3 - Preview what will be created

```bash
terraform plan
```

Review the output. It will show every resource that will be created.

### Step 4 - Apply

```bash
terraform apply
```

Type `yes` when prompted. Takes about 2-3 minutes.

### Step 5 - Connect

After apply completes, Terraform prints the outputs. Use the SSH command shown:

```bash
# SSH to AWX instance
ssh -i ~/.ssh/your-key.pem ec2-user@<awx_public_ip>

# SSH to PostgreSQL via AWX as jump host
ssh -i ~/.ssh/your-key.pem -J ec2-user@<awx_public_ip> ec2-user@<postgres_private_ip>
```

### Step 6 - Start AWX

Once SSH'd into the AWX instance:

```bash
# Check bootstrap completed
cat ~/bootstrap_complete.txt

# Start AWX with Docker Compose
cd ~
docker compose up -d

# Check containers are running
docker ps
```

AWX Web UI will be available at: `http://<awx_public_ip>`  
Default credentials: `admin` / `ChangeMe_Admin_2026!`

## Teardown

To destroy all resources (stops AWS billing):

```bash
terraform destroy
```

## Security Notes

- `terraform.tfvars` is in `.gitignore` — never commit it (contains your IP and passwords)
- `*.tfstate` files are also ignored — they can contain sensitive data
- PostgreSQL is in a private subnet and only reachable from the AWX instance
- SSH is restricted to your IP only, not open to the internet
