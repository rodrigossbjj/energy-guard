#!/usr/bin/env bash
set -e

# Carrega ambiente ESP-IDF se ainda não estiver ativo na sessão
if [ -z "$IDF_PATH" ]; then
    source ~/.espressif/v6.1/esp-idf/export.sh > /dev/null 2>&1
fi

PORT="${1:-/dev/ttyUSB0}"

echo "🚀 Compilando, gravando e abrindo o monitor serial no ESP32 ($PORT)..."
idf.py -p "$PORT" -b 115200 flash monitor
