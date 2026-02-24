#!/bin/bash
# ============================================================
# egress-filter.sh -- Filtragem de egress para OpenClaw
#
# IMPORTANTE - COMPATIBILIDADE macOS:
#   No Docker Desktop for Mac, os containers rodam dentro de uma
#   VM Linux (LinuxKit). iptables NAO esta disponivel no macOS host.
#
#   Este script deve ser executado DENTRO da VM do Docker Desktop:
#     docker run --rm --privileged --pid=host alpine:3 nsenter -t 1 -m -u -n -i -- sh -c "$(cat security/egress-filter.sh)"
#
#   Em Linux nativo, execute diretamente com: sudo bash security/egress-filter.sh
# ============================================================

set -euo pipefail

# Subnet do Docker bridge para a rede frontend (deve bater com docker-compose.yml)
OPENCLAW_SUBNET="172.30.1.0/24"

# Nome da chain iptables customizada
CHAIN="OPENCLAW_EGRESS"

echo "[*] Configurando filtragem de egress para $OPENCLAW_SUBNET..."
echo "[*] Detectando ambiente..."

# Verifica se iptables esta disponivel
if ! command -v iptables &> /dev/null; then
    echo "[!] iptables nao encontrado."
    echo "[!] Se voce esta no macOS, execute este script dentro da VM do Docker Desktop:"
    echo "    docker run --rm --privileged --pid=host alpine:3 nsenter -t 1 -m -u -n -i -- sh < security/egress-filter.sh"
    exit 1
fi

# Limpa regras existentes
iptables -D FORWARD -s "$OPENCLAW_SUBNET" -j "$CHAIN" 2>/dev/null || true
iptables -F "$CHAIN" 2>/dev/null || true
iptables -X "$CHAIN" 2>/dev/null || true

# Cria a chain
iptables -N "$CHAIN"

# ============================================================
# DESTINOS DE EGRESS PERMITIDOS (allowlist)
# ============================================================

# DNS para DNS interno do Docker (127.0.0.11)
iptables -A "$CHAIN" -p udp --dport 53 -d 127.0.0.11 -j ACCEPT
iptables -A "$CHAIN" -p tcp --dport 53 -d 127.0.0.11 -j ACCEPT

# --- APIs de LLM ---
# HTTPS para API da Anthropic
iptables -A "$CHAIN" -p tcp --dport 443 -d api.anthropic.com -j ACCEPT

# HTTPS para API da OpenAI
iptables -A "$CHAIN" -p tcp --dport 443 -d api.openai.com -j ACCEPT

# --- Canais de Mensageria ---
# WhatsApp (Meta)
iptables -A "$CHAIN" -p tcp --dport 443 -d web.whatsapp.com -j ACCEPT
iptables -A "$CHAIN" -p tcp --dport 443 -d mmg.whatsapp.net -j ACCEPT

# Telegram
iptables -A "$CHAIN" -p tcp --dport 443 -d api.telegram.org -j ACCEPT

# Discord
iptables -A "$CHAIN" -p tcp --dport 443 -d discord.com -j ACCEPT
iptables -A "$CHAIN" -p tcp --dport 443 -d gateway.discord.gg -j ACCEPT

# Slack
iptables -A "$CHAIN" -p tcp --dport 443 -d slack.com -j ACCEPT
iptables -A "$CHAIN" -p tcp --dport 443 -d api.slack.com -j ACCEPT

# Signal
iptables -A "$CHAIN" -p tcp --dport 443 -d chat.signal.org -j ACCEPT

# --- Tailscale VPN ---
iptables -A "$CHAIN" -p tcp --dport 443 -d controlplane.tailscale.com -j ACCEPT
iptables -A "$CHAIN" -p udp --dport 41641 -j ACCEPT  # Tailscale WireGuard

# Permite conexoes estabelecidas/relacionadas (respostas a requisicoes permitidas)
iptables -A "$CHAIN" -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# ============================================================
# DEFAULT: LOG e DROP tudo o mais
# ============================================================
iptables -A "$CHAIN" -j LOG --log-prefix "OPENCLAW_EGRESS_DENIED: " --log-level 4
iptables -A "$CHAIN" -j DROP

# Insere a chain na chain FORWARD para esta subnet
iptables -I FORWARD -s "$OPENCLAW_SUBNET" -j "$CHAIN"

echo "[+] Filtragem de egress ativa para $OPENCLAW_SUBNET"
echo "[+] Permitido: Anthropic API, OpenAI API, WhatsApp, Telegram, Discord, Slack, Signal, Tailscale, DNS interno"
echo "[+] Todo outro trafego de saida sera DROPADO e LOGADO"
echo ""
echo "[*] Para verificar regras ativas: iptables -L $CHAIN -n -v"
