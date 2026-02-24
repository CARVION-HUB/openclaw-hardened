#!/bin/sh
# healthcheck.sh -- Health probe leve para o OpenClaw Gateway
# Retorna 0 (healthy) ou 1 (unhealthy)

set -e

# Verifica se o processo principal Node.js esta rodando
if ! pgrep -f "node.*openclaw" > /dev/null 2>&1; then
    echo "UNHEALTHY: processo principal nao esta rodando"
    exit 1
fi

# Verifica o endpoint HTTP do gateway
if command -v wget > /dev/null 2>&1; then
    wget --no-verbose --tries=1 --spider --timeout=5 http://localhost:18789/ || exit 1
elif command -v curl > /dev/null 2>&1; then
    curl --fail --silent --max-time 5 http://localhost:18789/ > /dev/null || exit 1
fi

exit 0
