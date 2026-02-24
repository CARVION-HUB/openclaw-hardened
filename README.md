# OpenClaw Hardened

Production-ready Docker deployment of [OpenClaw](https://openclaw.ai) with maximum security hardening. Treats the AI agent as a **hostile microservice** — isolated, resource-limited, and monitored.

OpenClaw is a self-hosted gateway that connects chat apps (WhatsApp, Telegram, Discord, Slack, Signal, iMessage) to AI coding agents. This repo wraps it with enterprise-grade security layers.

## Security Architecture

```
                    Internet
                       │
              ┌────────▼────────┐
              │   Tailscale VPN │  Zero-trust mesh
              │   (userspace)   │
              └────────┬────────┘
                       │
              ┌────────▼────────┐
              │      Caddy      │  TLS 1.2+ / HSTS / Rate limit
              │  Reverse Proxy  │  Security headers / CSP
              └────────┬────────┘
                       │ :18789
              ┌────────▼────────┐
              │    OpenClaw     │  read-only FS / cap_drop ALL
              │    Gateway      │  seccomp allowlist / no-new-privs
              │                 │  CPU 2.0 / RAM 2G / PIDs 256
              └────────┬────────┘
                       │
              ┌────────▼────────┐
              │   Prometheus +  │  Anomaly detection
              │   Alertmanager  │  CPU/RAM/Network/PID alerts
              └─────────────────┘
```

### 4 Layers of Defense

| Layer | What | How |
|---|---|---|
| **Sandboxing** | Filesystem read-only, capabilities dropped, seccomp allowlist | Container cannot write to disk, escalate privileges, or use dangerous syscalls |
| **Network Shield** | Zero published ports, Tailscale VPN, Caddy reverse proxy | No direct internet exposure; egress filtered to API + messaging domains only |
| **Secrets Management** | `.env` never committed, tokens auto-generated, billing hard caps | API keys isolated; gateway token generated with `openssl rand` |
| **Monitoring** | Prometheus + Alertmanager with anomaly rules | Detects crypto mining, fork bombs, data exfiltration, OOM, excessive restarts |

## Quick Start

### Prerequisites

- macOS with [Docker Desktop](https://www.docker.com/products/docker-desktop/) installed
- Git

### Automated Setup

```bash
git clone https://github.com/CARVION-HUB/openclaw-hardened.git
cd openclaw-hardened
bash setup.sh
```

The script will:
1. Clone the official [OpenClaw](https://github.com/openclaw/openclaw) repository
2. Build the Docker image
3. Generate a secure gateway token
4. Run the interactive onboarding wizard
5. Start the hardened stack

### Access

```bash
# Control UI (dev mode with override)
open http://localhost:18789/

# Connect WhatsApp
docker compose --profile cli run --rm openclaw-cli channels login

# Connect Telegram
docker compose --profile cli run --rm openclaw-cli channels add --channel telegram --token "<BOT_TOKEN>"

# Connect Discord
docker compose --profile cli run --rm openclaw-cli channels add --channel discord --token "<BOT_TOKEN>"

# View logs
docker compose logs -f openclaw-gateway

# Stop everything
docker compose down
```

## Project Structure

```
openclaw-hardened/
├── docker-compose.yml            # Hardened stack (gateway + caddy + tailscale + monitoring)
├── docker-compose.override.yml   # Dev overrides (localhost ports)
├── .env.example                  # Environment template (API keys, tokens)
├── setup.sh                      # Automated setup script
├── caddy/
│   └── Caddyfile                 # Reverse proxy config (TLS, headers, rate limit)
├── security/
│   ├── seccomp-openclaw.json     # Syscall allowlist for Node.js/V8
│   ├── healthcheck.sh            # Gateway health probe
│   └── egress-filter.sh          # iptables egress allowlist
└── monitoring/
    ├── prometheus.yml             # Metrics collection
    ├── alertmanager.yml           # Alert routing
    └── alerts/
        └── container-alerts.yml   # Anomaly detection rules
```

## Security Details

### Container Hardening

```yaml
# Every container runs with:
read_only: true              # Immutable filesystem
cap_drop: [ALL]              # Zero Linux capabilities
security_opt:
  - no-new-privileges:true   # Cannot escalate
  - seccomp=profile.json     # Syscall allowlist
deploy:
  resources:
    limits:
      cpus: "2.0"            # CPU ceiling
      memory: 2G             # RAM ceiling
      pids: 256              # Fork bomb protection
```

### Egress Filtering

Only these external destinations are allowed:

| Category | Domains |
|---|---|
| LLM APIs | `api.anthropic.com`, `api.openai.com` |
| WhatsApp | `web.whatsapp.com`, `mmg.whatsapp.net` |
| Telegram | `api.telegram.org` |
| Discord | `discord.com`, `gateway.discord.gg` |
| Slack | `slack.com`, `api.slack.com` |
| Signal | `chat.signal.org` |
| VPN | `controlplane.tailscale.com` |

All other outbound traffic is **dropped and logged**.

### Monitoring Alerts

| Alert | Trigger | Severity |
|---|---|---|
| CPU Spike | >150% for 30s | Critical |
| High CPU | >80% for 2min | Warning |
| OOM Risk | >95% memory limit | Critical |
| Network Egress | >5MB/s for 2min | Warning |
| Fork Bomb | >200 processes | Critical |
| Frequent Restarts | >5 in 1 hour | Warning |

## macOS Notes

- **AppArmor**: Not available on macOS (seccomp profiles work fine)
- **Tailscale**: Runs in userspace mode (no `/dev/net/tun` on Docker Desktop)
- **Egress filter**: Must run inside Docker Desktop VM:
  ```bash
  docker run --rm --privileged --pid=host alpine:3 \
    nsenter -t 1 -m -u -n -i -- sh < security/egress-filter.sh
  ```

## License

MIT

---

Built by [CARVION](https://github.com/CARVION-HUB) with security-first principles.
