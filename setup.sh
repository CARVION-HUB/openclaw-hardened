#!/bin/bash
# ============================================================
# setup.sh -- Setup automatizado do OpenClaw com seguranca blindada
#
# Este script:
#   1. Clona o repositorio oficial do OpenClaw
#   2. Constroi a imagem Docker
#   3. Gera o token do gateway
#   4. Roda o onboarding interativo
#   5. Sobe o stack blindado
#
# Uso: bash setup.sh
# ============================================================

set -euo pipefail

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
OPENCLAW_SRC_DIR="$SCRIPT_DIR/openclaw-src"
ENV_FILE="$SCRIPT_DIR/.env"

echo -e "${BLUE}============================================================${NC}"
echo -e "${BLUE}  OpenClaw -- Setup Blindado${NC}"
echo -e "${BLUE}============================================================${NC}"
echo ""

# ----------------------------------------------------------
# 1. Verificar pre-requisitos
# ----------------------------------------------------------
echo -e "${YELLOW}[1/6] Verificando pre-requisitos...${NC}"

if ! command -v docker &> /dev/null; then
    echo -e "${RED}[!] Docker nao encontrado. Instale com: brew install --cask docker${NC}"
    exit 1
fi

if ! docker info &> /dev/null 2>&1; then
    echo -e "${RED}[!] Docker daemon nao esta rodando. Abra o Docker Desktop.${NC}"
    exit 1
fi

if ! command -v git &> /dev/null; then
    echo -e "${RED}[!] Git nao encontrado. Instale com: brew install git${NC}"
    exit 1
fi

echo -e "${GREEN}[+] Docker e Git encontrados.${NC}"

# ----------------------------------------------------------
# 2. Clonar repositorio oficial
# ----------------------------------------------------------
echo ""
echo -e "${YELLOW}[2/6] Clonando repositorio oficial do OpenClaw...${NC}"

if [ -d "$OPENCLAW_SRC_DIR" ]; then
    echo -e "${BLUE}[*] Repositorio ja existe em $OPENCLAW_SRC_DIR. Atualizando...${NC}"
    cd "$OPENCLAW_SRC_DIR"
    git pull --ff-only || echo -e "${YELLOW}[!] Nao foi possivel atualizar, usando versao existente.${NC}"
    cd "$SCRIPT_DIR"
else
    git clone https://github.com/openclaw/openclaw.git "$OPENCLAW_SRC_DIR"
fi

echo -e "${GREEN}[+] Repositorio pronto.${NC}"

# ----------------------------------------------------------
# 3. Construir imagem Docker
# ----------------------------------------------------------
echo ""
echo -e "${YELLOW}[3/6] Construindo imagem Docker do OpenClaw...${NC}"
echo -e "${BLUE}[*] Isso pode levar alguns minutos na primeira vez...${NC}"

docker build \
    -t openclaw:local \
    -f "$OPENCLAW_SRC_DIR/Dockerfile" \
    "$OPENCLAW_SRC_DIR/"

echo -e "${GREEN}[+] Imagem openclaw:local construida com sucesso.${NC}"

# ----------------------------------------------------------
# 4. Gerar .env se nao existir
# ----------------------------------------------------------
echo ""
echo -e "${YELLOW}[4/6] Configurando variaveis de ambiente...${NC}"

if [ ! -f "$ENV_FILE" ]; then
    cp "$SCRIPT_DIR/.env.example" "$ENV_FILE"

    # Gerar token do gateway automaticamente
    if command -v openssl &> /dev/null; then
        GATEWAY_TOKEN=$(openssl rand -hex 32)
    elif command -v python3 &> /dev/null; then
        GATEWAY_TOKEN=$(python3 -c "import secrets; print(secrets.token_hex(32))")
    else
        echo -e "${RED}[!] Nao foi possivel gerar token automaticamente. Edite .env manualmente.${NC}"
        GATEWAY_TOKEN="CHANGE_ME_MANUALLY"
    fi

    # Substituir o placeholder do token
    if [[ "$OSTYPE" == "darwin"* ]]; then
        sed -i '' "s/OPENCLAW_GATEWAY_TOKEN=CHANGE_ME_RUN_SETUP_SH/OPENCLAW_GATEWAY_TOKEN=$GATEWAY_TOKEN/" "$ENV_FILE"
    else
        sed -i "s/OPENCLAW_GATEWAY_TOKEN=CHANGE_ME_RUN_SETUP_SH/OPENCLAW_GATEWAY_TOKEN=$GATEWAY_TOKEN/" "$ENV_FILE"
    fi

    echo -e "${GREEN}[+] Arquivo .env criado com token gerado automaticamente.${NC}"
    echo -e "${YELLOW}[!] IMPORTANTE: Edite .env para configurar suas API keys (Anthropic, OpenAI, etc.)${NC}"
else
    echo -e "${BLUE}[*] Arquivo .env ja existe. Usando configuracao existente.${NC}"
fi

# ----------------------------------------------------------
# 5. Rodar onboarding
# ----------------------------------------------------------
echo ""
echo -e "${YELLOW}[5/6] Rodando onboarding do OpenClaw...${NC}"
echo -e "${BLUE}[*] Siga as instrucoes interativas para configurar seu agente.${NC}"
echo ""

docker compose --profile cli run --rm openclaw-cli onboard

echo ""
echo -e "${GREEN}[+] Onboarding concluido.${NC}"

# ----------------------------------------------------------
# 6. Subir o stack
# ----------------------------------------------------------
echo ""
echo -e "${YELLOW}[6/6] Subindo o stack blindado...${NC}"

docker compose up -d

echo ""
echo -e "${GREEN}============================================================${NC}"
echo -e "${GREEN}  OpenClaw esta rodando!${NC}"
echo -e "${GREEN}============================================================${NC}"
echo ""
echo -e "  ${BLUE}Control UI:${NC}  http://localhost:18789/"
echo -e "  ${BLUE}Token:${NC}       Veja em Settings no Control UI"
echo ""
echo -e "  ${YELLOW}Comandos uteis:${NC}"
echo -e "    docker compose logs -f openclaw-gateway  # Ver logs"
echo -e "    docker compose --profile cli run --rm openclaw-cli channels login  # Conectar WhatsApp"
echo -e "    docker compose --profile cli run --rm openclaw-cli channels add --channel telegram --token <TOKEN>  # Telegram"
echo -e "    docker compose --profile cli run --rm openclaw-cli dashboard --no-open  # Dashboard"
echo -e "    docker compose down  # Parar tudo"
echo ""
echo -e "  ${RED}SEGURANCA:${NC}"
echo -e "    - Filesystem: read-only"
echo -e "    - Capabilities: ALL dropped"
echo -e "    - Seccomp: perfil allowlist customizado"
echo -e "    - Rede: zero portas publicas (use Tailscale ou override dev)"
echo -e "    - Recursos: CPU 2.0, RAM 2G, PIDs 256"
echo -e "    - Logs: rotacao automatica (10m x 5)"
echo ""
