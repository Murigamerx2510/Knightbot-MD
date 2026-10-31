#!/usr/bin/env bash
# Roda o jogo inteiro dentro de um simulador do Roblox (Luau de verdade + API oficial do Roblox).
# Requisitos: Node.js 18+, Python 3 e internet na primeira vez.
set -e
cd "$(dirname "$0")"
[ -d node_modules/luau-web ] || npm install --no-audit --no-fund
[ -f Full-API-Dump.json ] || curl -sSL -o Full-API-Dump.json \
  https://raw.githubusercontent.com/MaximumADHD/Roblox-Client-Tracker/roblox/Full-API-Dump.json
python3 gen_api.py Full-API-Dump.json api_data.luau
node run.mjs ../../src
