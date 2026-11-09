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
# In practice, copy the actual key — never commit it
echo "<gateway-public-key>" | sudo tee -a ~agent-runner/.ssh/authorized_keys
echo "SSH key installed."

echo "=== Step 4: Configure proxychains (SOCKS5) ==="
sudo apt install -y proxychains4
cat << 'EOF' | sudo tee -a /etc/proxychains4.conf
# Proxy list appended below any existing config
[ProxyList]
socks5 <gateway-tailnet-ip> 1080
EOF
echo "SOCKS5 proxy configured."

echo "=== Step 5: Verify isolation ==="
echo "Testing that LAN access is blocked..."
ping -c 1 -W 2 <mgmt-host> || echo "PASS: management VLAN unreachable"
echo "Testing egress via SOCKS5..."
curl --proxy socks5://<gateway>:1080 -s https://check.torproject.org | head -1 || echo "Check proxy config if this fails"

echo "Done. Worker is provisioned and isolated."