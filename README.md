# Worker Bootstrap — Isolated Linux Automation Nodes

Reference documentation for provisioning isolated Linux workers that connect to a self-hosted AI gateway (Hermes or similar). These are the patterns used in my home-lab multi-agent orchestration setup.

> **Note:** This is not a turnkey install script. It's a reference guide explaining the isolation strategy — credential paths, IPs, and secrets are replaced with placeholders.

## Isolation Strategy

Each worker operates under two layers of isolation:

1. **OS User Isolation** — dedicated low-privilege system account
2. **Network Isolation** — segregated VLAN with no outbound LAN access; the gateway reaches them via SSH over the tailnet

Outbound web traffic (when needed) is handled by the **gateway**, not the workers — it routes select tasks through SOCKS5 proxies and relays the results back. Workers themselves have no direct internet proxy configured.

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
echo "<gateway-public-key>" | sudo tee -a ~agent-runner/.ssh/authorized_keys
```

### 4. Assign to agent VLAN

On pfSense, assign the worker's MAC address a static IP in VLAN 50. Configure the firewall so the worker can be reached by the gateway (SSH from VLAN 10) but cannot initiate connections to any other internal VLAN or the internet directly.

## VLAN 50 Firewall Rules (pfSense)

| Direction | Allowed                               | Denied                        |
|-----------|---------------------------------------|-------------------------------|
| Inbound   | SSH from gateway (VLAN 10)            | All other inbound             |
| Outbound  | None (no default route to WAN or LAN) | All outbound unless explicitly approved |
| Inter-VLAN| Nothing                                | Any VLAN 10/20/30/40/80      |

Any web-based task the worker needs runs through the gateway: the gateway receives the instruction, makes the outbound call over its own SOCKS5 proxies, and returns the result to the worker. This keeps the worker's network surface near zero.

## Planned / Staging

- **Containerized worker runtime** — Migrate worker processes from bare-metal systemd services to Docker/Podman containers with read-only root filesystems and ephemeral /tmp, to further reduce the attack surface of each agent node.
- **Centralized worker health dashboard** — Deploy a lightweight Prometheus + Grafana stack on the management VLAN to track per-worker CPU, memory, SSH session count, and last-seen timestamp, replacing the manual `systemctl status` checks.
- **Local model inference on worker VLAN** — If the GPU node materializes, workers could offload LM calls to the local inference host instead of routing through external API providers, improving latency and cutting credit burn.

## Verification

```bash
# From the gateway — should succeed
ssh agent-runner@<worker-tailnet-ip>

# From the worker — should fail (no LAN outbound)
ping <management-host>
curl http://<server-ip>
```

## Related

- Full topology diagrams and configs in the [Notion Portfolio](https://app.notion.com/p/Zachary-Drouilhet-IT-Infrastructure-Engineering-Portfolio-018e60e7ab544c2180f6348c6df99b9d?source=copy_link)
- Multi-agent orchestration section in the portfolio covers how the gateway coordinates these nodes