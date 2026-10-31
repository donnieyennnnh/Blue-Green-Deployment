#!/usr/bin/env bash
# generate-inventory.sh — read the current EC2 IP from Terraform state and
# write ansible/inventory.ini. Run from the ansible/ directory inside WSL.

set -euo pipefail

TF_DIR="$(cd "$(dirname "$0")/../terraform" && pwd)"
IP=$(cd "$TF_DIR" && terraform output -raw ec2_public_ip)

cat > inventory.ini <<EOF
[app]
ec2 ansible_host=$IP
EOF

echo "Wrote inventory.ini → ec2 = $IP"
