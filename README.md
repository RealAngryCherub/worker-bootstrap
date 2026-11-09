# Worker Bootstrap — Isolated Linux Automation Nodes

Reference documentation for provisioning isolated Linux workers that connect to a self-hosted AI gateway (Hermes or similar) via SOCKS5 proxies. These are the patterns used in my home-lab multi-agent orchestration setup.

> **Note:** This is not a turnkey install script. It's a reference guide explaining the isolation strategy — credential paths, IPs, and secrets are replaced with placeholders.

## Isolation Strategy

Each worker operates under three layers of isolation:

1. **OS User Isolation** — dedicated low-privilege system account
2. **Network Isolation** — segregated VLAN with no LAN access
3. **Traffic Mediation** — all outbound communication goes through a SOCKS5 proxy

## Provisioning Steps

### 1. Create the worker user

```bash
sudo useradd -r -s /bin/bash -m -d /home/agent-runner agent-runner
sudo passwd -l agent-runner   # lock password auth — SSH key only
```

### 2. Restrict sudo

Create `/etc/sudoers.d/agent-runner`:

```
agent-runner ALL=(ALL) /usr/bin/systemctl restart agent-worker
agent-runner ALL=(ALL) /usr/bin/systemctl status agent-worker
# Everything else requires explicit sudo from the admin account
```

The worker can restart its own service but cannot escalate privileges.

### 3. SSH key-only access (from gateway)

```bash
sudo -u agent-runner mkdir -p ~agent-runner/.ssh
# Copy the gateway's public key into authorized_keys
echo "<gateway-public-key>" | sudo tee -a ~agent-runner/.ssh/authorized_keys
```

### 4. Assign to agent VLAN

On pfSense, assign the worker's MAC address a static IP in VLAN 50 and configure the firewall to allow outbound traffic only through the SOCKS5 proxy port on the gateway.

### 5. Route all traffic through SOCKS5

On the worker, configure proxychains or a systemd service:

```ini
# /etc/proxychains4.conf
strict_chain
proxy_dns
[ProxyList]
socks5  <gateway-tailnet-ip> 1080
```

Or use environment-level proxy variables for specific applications.

## VLAN 50 Firewall Rules (pfSense)

| Direction | Allowed | Denied                  |
|-----------|---------|-------------------------|
| Outbound  | SOCKS5 proxy port (1080) to gateway | All other LAN destinations |
| Inbound   | SSH from gateway only   | All other inbound         |
| Inter-VLAN| Nothing                | Any VLAN 10/20/30/40/80  |

## Verification

Check the worker is properly isolated:

```bash
# From the worker — should fail (no LAN access)
ping <management-host>
curl http://<server-ip>

# From the worker — should succeed (egress via proxy)
curl --proxy socks5://<gateway>:1080 https://check.torproject.org
```

## Related

- Full topology diagrams and configs in the [Notion Portfolio](https://app.notion.com/p/Zachary-Drouilhet-IT-Infrastructure-Engineering-Portfolio-018e60e7ab544c2180f6348c6df99b9d?source=copy_link)
- Multi-agent orchestration section in the portfolio covers how the gateway coordinates these nodes