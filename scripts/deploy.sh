#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# deploy.sh — Deploy manual a EC2 (emergencia)
#
# Uso:
#   ./scripts/deploy.sh                    # usa defaults
#   DEPLOY_HOST=3.18.206.227 ./scripts/deploy.sh
#
# Requiere: PEM_FILE apuntando a simulador-finances.pem
# =============================================================================

PEM_FILE="${PEM_FILE:-/home/daviuk/Documentos/Estudios/UP/9no Semestre/Finanzas Inter/simulador-finances.pem}"
DEPLOY_HOST="${DEPLOY_HOST:-3.18.206.227}"
DEPLOY_USER="${DEPLOY_USER:-ubuntu}"
DEPLOY_PATH="${DEPLOY_PATH:-/home/ubuntu/apps/simulador-inversiones}"

if [ ! -f "$PEM_FILE" ]; then
    echo "ERROR: PEM_FILE no encontrado: $PEM_FILE"
    echo "Configura: export PEM_FILE=/ruta/al/simulador-finances.pem"
    exit 1
fi

echo "=== Desplegando a $DEPLOY_HOST:$DEPLOY_PATH ==="

ssh -i "$PEM_FILE" -o StrictHostKeyChecking=no \
    "${DEPLOY_USER}@${DEPLOY_HOST}" \
    "cd ${DEPLOY_PATH} && \
     echo '--- git pull ---' && \
     git pull && \
     echo '--- submodules ---' && \
     git submodule update --init --remote && \
     echo '--- docker build ---' && \
     sudo docker compose build --pull frontend backend && \
     echo '--- docker up ---' && \
     sudo docker compose up -d --force-recreate frontend backend && \
     echo '=== DEPLOY COMPLETADO ==="

echo "=== Health check ==="
sleep 3
curl -sS "http://${DEPLOY_HOST}/health" || echo "Health check falló"
