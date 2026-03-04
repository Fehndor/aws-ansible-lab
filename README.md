# AWS Ansible Lab — AWX on K3s with Terraform

A fully automated AWS lab environment for learning and practising Ansible automation using AWX (the open source version of Ansible Tower), deployed on lightweight Kubernetes (K3s), provisioned entirely with Terraform. 

This project was built as a learning lab and GitHub portfolio piece for cloud engineering. Everything is automated — a single `terraform apply` creates the full environment from scratch with zero manual steps.

---

## What This Builds

```
                    Internet
                       |
                  [Internet Gateway]
                       |
              ┌────────────────────────┐
              │     VPC 10.0.0.0/16    │
              │                        │
              │   Public Subnet        │
              │   10.0.1.0/24          │
              │   ┌────────────────┐   │
              │   │  AWX / K3s     │   │◄── SSH (your IP only)
              │   │  t3.medium     │   │◄── HTTP port 8080 (your IP only)
              │   └───────┬────────┘   │
              │           │            │
              │   [NAT Gateway]        │
              │           │            │
              │   Private Subnet       │
              │   10.0.2.0/24          │
              │   ┌────────────────┐   │
              │   │  PostgreSQL    │   │◄── Port 5432 (AWX only)
              │   │  t3.small      │   │◄── SSH (via jump host only)
              │   └────────────────┘   │
              └────────────────────────┘
```

**AWX EC2** (public subnet, t3.medium):
- K3s — lightweight single-node Kubernetes
- Helm — Kubernetes package manager
- AWX Operator — manages the AWX deployment
- AWX — web UI for running and scheduling Ansible playbooks
- Ansible CLI — for direct command-line use

**PostgreSQL EC2** (private subnet, t3.small):
- PostgreSQL 15 — backs the AWX application database
- Only reachable from the AWX instance, not from the internet

---

## File Structure

```
aws-ansible-lab/
├── main.tf                  # Provider config (AWS, region)
├── variables.tf             # All input variable definitions
├── networking.tf            # VPC, subnets, IGW, NAT GW, route tables
├── security_groups.tf       # Firewall rules for AWX and PostgreSQL
├── data.tf                  # Auto-fetches latest Amazon Linux 2023 AMI
├── instances.tf             # EC2 instance definitions
├── awx_userdata.sh          # Bootstrap script for AWX EC2
├── postgres_userdata.sh     # Bootstrap script for PostgreSQL EC2
├── outputs.tf               # Prints IPs, URLs, SSH commands after apply
├── terraform.tfvars.example # Template for your variables
├── .gitignore               # Prevents secrets/state files being committed
└── README.md                # This file
```

---

## Design Decisions and Trade-offs

Understanding *why* things are built a certain way is just as important as building them. Here's the reasoning behind the key choices.

### Why Two EC2 Instances Instead of One?

AWX and PostgreSQL are separated onto different instances for two reasons. First, **security** — the database is in a private subnet with no public IP, so even if someone compromised the AWX server they would still need to pivot through it to reach the database. Second, **separation of concerns** — in real environments databases and application servers are always separate, and this lab reflects that.

**Trade-off:** Two instances cost more than one. For an always-on lab this adds ~$17/month. The recommended approach (see Cost section) is to destroy and recreate the lab per session, making the extra cost negligible.

### Why K3s Instead of Plain Docker?

The original design used Docker Compose to run AWX. This failed because AWX no longer publishes a standalone Docker image — modern AWX is deployed via the AWX Operator, which requires Kubernetes.

K3s is the right tool here because it is a fully certified, lightweight Kubernetes distribution that runs comfortably on a single t3.medium. It is how AWX is actually deployed in the real world today. Running AWX on K3s is more relevant experience than running an old Docker image.

**Trade-off:** K3s adds complexity and bootstrap time (~8-10 minutes vs ~2 minutes for plain Docker). It also uses more RAM, making t3.medium the minimum viable instance size. The upside is that you learn real Kubernetes concepts — pods, namespaces, operators, Helm charts, kubectl — which are all valuable for cloud engineering roles.

### Why Not Use RDS for PostgreSQL?

AWS RDS (managed PostgreSQL) would be simpler to operate and more production-like. We chose an EC2-hosted PostgreSQL instead for two reasons. First, **cost** — RDS starts at ~$15-25/month even for the smallest instance, and unlike EC2 it cannot be "stopped" for free in the same destroy/recreate pattern. Second, **learning** — manually installing and configuring PostgreSQL, editing `pg_hba.conf`, and configuring `listen_addresses` teaches you things that RDS abstracts away. For a learning lab, the manual approach is more valuable.

### Why Not Use an Elastic IP for AWX?

Elastic IPs are free while attached to a running instance, but because we destroy and recreate the lab per session the public IP changes every time. This is intentional — the `terraform output` command always prints the current DNS name and IP after apply, and the DNS name is more reliable than the IP for browser access anyway (we discovered during testing that some networks block direct IP access but allow DNS-based access).

### Why a NAT Gateway?

The PostgreSQL instance is in a private subnet with no direct internet access. However, it still needs to reach the internet during bootstrap to download PostgreSQL packages from the Amazon Linux repositories. The NAT Gateway allows outbound traffic from private subnets while preventing any inbound connections from the internet.

**Trade-off:** The NAT Gateway is the **most expensive component** at ~$0.052/hour **(~$38/month if always on).** This makes the destroy/recreate approach even more important — when you run `terraform destroy` the NAT Gateway is deleted and billing stops immediately.

### Why Amazon Linux 2023 Instead of Ubuntu?

Amazon Linux 2023 is AWS's own Linux distribution, optimized for EC2. It starts faster, integrates better with AWS services, and is what you'll encounter in many AWS-native environments. It does have some quirks compared to Ubuntu — notably it ships with `curl-minimal` instead of full `curl`, which caused package conflicts we had to work around with `--allowerasing`. Learning to deal with these quirks is valuable real-world experience.

---

## Prerequisites

1. **Terraform** >= 1.5.0 installed ([download](https://developer.hashicorp.com/terraform/install))
2. **AWS CLI** configured (`aws configure`) with an IAM user that has EC2 and VPC permissions
3. **EC2 Key Pair** created in the AWS Console (eu-central-1 region)
4. **WSL2** (if on Windows) — all commands run inside WSL Ubuntu

### Windows Users — WSL Setup

If you're on Windows, use WSL2 with Ubuntu. Run the included `setup_wsl.sh` script to install Terraform, AWS CLI, and all required tools:

```bash
chmod +x setup_wsl.sh
./setup_wsl.sh
```

Keep your project files inside the WSL filesystem (`~/projects/`) rather than on the Windows drive (`/mnt/c/`). Terraform and file permissions behave unpredictably across the WSL/Windows boundary.

---

## Usage

### Step 1 — Configure Variables

```bash
cp terraform.tfvars.example terraform.tfvars
nano terraform.tfvars
```

Fill in:
- `key_pair_name` — name of your EC2 Key Pair (create in AWS Console → EC2 → Key Pairs)
- `your_ip_cidr` — run `curl ifconfig.me` and append `/32` (e.g. `1.2.3.4/32`)
- `postgres_password` — choose a strong password

### Step 2 — Initialize and Deploy

```bash
terraform init
terraform plan    # Preview what will be created
terraform apply   # Create everything (~10-12 minutes total)
```

After apply completes, Terraform prints the outputs:

```
awx_public_dns    = "ec2-X-X-X-X.eu-central-1.compute.amazonaws.com"
awx_web_ui_url    = "http://ec2-X-X-X-X.eu-central-1.compute.amazonaws.com:8080"
ssh_command_awx   = "ssh -i ~/.ssh/your-key.pem ec2-user@X.X.X.X"
postgres_private_ip = "10.0.2.X"
```

### Step 3 — Wait for AWX to Initialize

AWX takes 8-12 minutes after bootstrap to pull container images and run database migrations. SSH in and monitor progress:

```bash
ssh -i ~/.ssh/your-key.pem ec2-user@<awx_public_ip>
~/check_awx.sh
```

Wait until all pods show `Running` or `Completed`:

```
NAME                                               READY   STATUS      
awx-migration-X                                    0/1     Completed   
awx-operator-controller-manager-X                 2/2     Running     
awx-task-X                                         4/4     Running     
awx-web-X                                          3/3     Running     
```

### Step 4 — Access AWX Web UI

Open in browser (use the DNS name, not the IP directly):

```
http://ec2-X-X-X-X.eu-central-1.compute.amazonaws.com:8080
```

Retrieve the admin password:

```bash
kubectl get secret awx-admin-password -n awx -o jsonpath='{.data.password}' | base64 --decode && echo
```

Login with username `admin` and the password above.

### Step 5 — Keep the Port-Forward Running

AWX is exposed via `kubectl port-forward`. This process must be running for the web UI to be accessible:

```bash
kubectl port-forward svc/awx-service -n awx 8080:80 --address 0.0.0.0 &
```

This runs in the background. If you disconnect from SSH it will stop. Reconnect and rerun this command if the UI becomes unreachable.

> **Note for the future:** A production-ready improvement would be to run this as a systemd service so it survives SSH disconnects and reboots automatically.

---

## Connecting to PostgreSQL

PostgreSQL is in a private subnet and has no public IP. Access it via the AWX instance as a jump host:

```bash
ssh -i ~/.ssh/your-key.pem \
  -o ProxyCommand="ssh -i ~/.ssh/your-key.pem -W %h:%p ec2-user@<awx_public_ip>" \
  ec2-user@<postgres_private_ip>
```

The simpler `-J` jump host syntax (`ssh -J`) requires SSH agent forwarding to be configured. The `ProxyCommand` approach above works reliably without extra setup.

Once connected, verify AWX is using the database:

```bash
sudo systemctl status postgresql
```

You should see active connections from the AWX IP in the process list — this confirms the full stack is working end to end.

---

## Cost Management

### Cost Breakdown (eu-central-1, Frankfurt)

| Resource | Hourly | Monthly (24/7) |
|---|---|---|
| AWX EC2 (t3.medium) | ~$0.048 | ~$35 |
| PostgreSQL EC2 (t3.small) | ~$0.024 | ~$17 |
| NAT Gateway | ~$0.052 | ~$38 |
| EBS volumes (~60GB gp3) | — | ~$5 |
| **Total if always on** | | **~$95/month** |

### Recommended: Destroy Per Session

For a study lab used a few hours per day, destroy the environment when done and recreate it next session:

```bash
terraform destroy   # When done for the day
terraform apply     # Next time you want to use it
```

At 2 hours/day, 5 days/week (~40 hours/month) the cost drops to approximately **$8-10/month**.

The NAT Gateway is the main driver — it charges $0.052/hour regardless of traffic. Destroying it between sessions is the biggest cost saving.

> **Important:** `terraform destroy` deletes everything including any data inside the instances. Keep your Ansible playbooks and work in Git, not inside the EC2.

---

## Troubleshooting

### Bootstrap script didn't run
Check the cloud-init logs:
```bash
sudo cat /var/log/cloud-init-output.log
```
This shows the full output of the bootstrap script and any errors. It is the first place to look for any EC2 user_data issues.

### AWX web UI not loading
1. Check all pods are Running: `~/check_awx.sh`
2. Check port-forward is running: `ps aux | grep kubectl`
3. Restart port-forward if needed: `kubectl port-forward svc/awx-service -n awx 8080:80 --address 0.0.0.0 &`
4. Use the DNS name in your browser, not the raw IP — some networks handle these differently
5. Verify your IP hasn't changed: compare `curl ifconfig.me` (from your machine) against `your_ip_cidr` in `terraform.tfvars`

### curl-minimal conflict on Amazon Linux 2023
Amazon Linux 2023 ships with `curl-minimal` which conflicts with full `curl`. Always use `--allowerasing` when installing curl:
```bash
dnf install -y --allowerasing curl
```

### Terraform templatefile ${ } variable errors
Terraform's `templatefile()` function interprets `${}` as its own variables. Any shell variables in bootstrap scripts must use double dollar signs: `$${MY_VAR}` instead of `${MY_VAR}`.

### SSH permission denied on .pem file
```bash
chmod 400 ~/.ssh/your-key.pem
```
SSH refuses to use key files that are readable by other users.

### terraform destroy shows "No objects need to be destroyed"
You are running the command from the wrong directory. Always run Terraform commands from the project folder:
```bash
cd ~/projects/ansible-lab
terraform destroy
```

---

## Common Pitfalls Encountered During Development

This section is intentionally included to help others avoid the same issues.

| Issue | Cause | Fix |
|---|---|---|
| ECS-optimized AMI selected | AMI filter `al2023-ami-*` matched ECS variant | Tighten filter to `al2023-ami-2023*` |
| Bootstrap script exits early | `set -e` causes exit on any error | Use `set +e` for non-critical steps or remove it for lab scripts |
| `docker-compose-plugin` not found | Package name differs on AL2023 | Install standalone binary via curl instead |
| AWX Docker image not found | `ansible/awx:latest` no longer published | Use K3s + AWX Operator instead |
| AWX Helm repo 404 | Repo moved to new URL | Use `https://ansible-community.github.io/awx-operator-helm/` |
| `iptables: command not found` | iptables not pre-installed on AL2023 | `dnf install -y iptables iptables-services` before using iptables |
| NodePort not accessible | K3s NodePort doesn't bind to host interface as expected | Use `kubectl port-forward` instead |
| Browser can't reach IP directly | Some networks/ISPs block direct IP access | Use the EC2 DNS name instead of the IP |
| Jump host SSH fails with `-J` | SSH agent not configured for key forwarding | Use `ProxyCommand` with explicit `-i` flag for both hops |

---

## Security Notes

- `terraform.tfvars` is in `.gitignore` — never commit it (contains your IP and passwords)
- `*.tfstate` files are also ignored — they can contain sensitive data in plaintext
- SSH is restricted to your IP only — not open to the internet
- PostgreSQL is in a private subnet and only accepts connections from the AWX security group
- The AWX admin password is auto-generated by the operator — retrieve it with kubectl as shown above
- Change the `SECRET_KEY` value in production deployments

---

## What to Build Next

Once the lab is running, here are suggested next steps for building your Ansible portfolio:

1. **Write your first playbook** — automate the installation of a web server (nginx/apache) on a new EC2 instance
2. **Add inventory** — define your EC2 instances as AWX inventory and run playbooks through the UI
3. **Use roles** — refactor playbooks into reusable Ansible roles
4. **Add credentials** — store SSH keys in AWX's credential vault
5. **Build a workflow** — chain multiple playbooks together in an AWX workflow template
6. **Infrastructure playbooks** — write Ansible to configure the PostgreSQL server itself, replacing the bash bootstrap script

Each of these is a concrete GitHub commit that demonstrates real cloud automation skills.
