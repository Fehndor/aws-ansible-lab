#!/bin/bash
set -e

# -------------------------------------------------------
# PostgreSQL EC2 Bootstrap Script
# Runs on first boot as root via EC2 user_data
# -------------------------------------------------------

# Update all packages
dnf update -y

# Install PostgreSQL 15 server
dnf install -y postgresql15 postgresql15-server

# Initialize the database cluster
postgresql-setup --initdb

# Start PostgreSQL and enable on reboot
systemctl start postgresql
systemctl enable postgresql

# -------------------------------------------------------
# Configure PostgreSQL
# Create the AWX database and user
# -------------------------------------------------------

# Switch to postgres system user and run SQL commands
sudo -u postgres psql << 'SQLEOF'
-- Create the AWX database user
CREATE USER awx WITH PASSWORD '${postgres_password}';

-- Create the AWX database
CREATE DATABASE awx OWNER awx;

-- Grant all privileges on the awx database to awx user
GRANT ALL PRIVILEGES ON DATABASE awx TO awx;

-- Exit psql
\q
SQLEOF

# -------------------------------------------------------
# Configure pg_hba.conf to allow connections from the VPC
# (10.0.0.0/16 is the VPC CIDR defined in variables.tf)
# Without this, PostgreSQL would reject remote connections
# even if the security group allows the traffic
# -------------------------------------------------------

PG_HBA="/var/lib/pgsql/data/pg_hba.conf"

# Allow md5 (password) authentication from the entire VPC CIDR
echo "host    awx             awx             10.0.0.0/16             md5" >> $PG_HBA

# -------------------------------------------------------
# Configure postgresql.conf to listen on all interfaces
# By default PostgreSQL only listens on localhost (127.0.0.1)
# We need it to listen on the private IP so AWX can connect
# -------------------------------------------------------

PG_CONF="/var/lib/pgsql/data/postgresql.conf"
sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/" $PG_CONF

# Restart PostgreSQL to apply configuration changes
systemctl restart postgresql

# Write a status file to confirm bootstrap ran
echo "PostgreSQL bootstrap completed at $(date)" > /root/bootstrap_complete.txt
