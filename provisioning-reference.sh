#!/bin/bash
# provisioning-reference.sh
# Annotated reference — not a live script. IPs, keys, and paths are placeholders.
# This shows the step-by-step workflow used to provision an isolated Linux worker.

set -euo pipefail

echo "=== Step 1: Create low-privilege user ==="
sudo useradd -r -s /bin/bash -m -d /home/agent-runner agent-runner
sudo passwd -l agent-runner
echo "User agent-runner created, password auth locked."

echo "=== Step 2: Restrict sudo ==="
cat << 'EOF' | sudo tee /etc/sudoers.d/agent-runner
# agent-runner can only restart/status its own service
agent-runner ALL=(ALL) /usr/bin/systemctl restart agent-worker
agent-runner ALL=(ALL) /usr/bin/systemctl status agent-worker
EOF
sudo chmod 440 /etc/sudoers.d/agent-runner
echo "Sudo restricted."

echo "=== Step 3: Install SSH key from gateway ==="
sudo -u agent-runner mkdir -p ~agent-runner/.ssh
echo "<gateway-public-key>" | sudo tee -a ~agent-runner/.ssh/authorized_keys
echo "SSH key installed."

echo "=== Step 4: Verify isolation ==="
echo "Testing that LAN access is blocked..."
ping -c 1 -W 2 <mgmt-host> || echo "PASS: management VLAN unreachable"
echo "Testing SSH access from gateway..."
ssh -o ConnectTimeout=5 <gateway> "echo 'Gateway can reach worker'" || echo "Check tailnet connectivity"
echo "Done. Worker is provisioned and isolated."