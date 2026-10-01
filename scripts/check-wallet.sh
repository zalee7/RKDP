#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
catalog="$(mktemp /tmp/rkdp-wallet-catalog.XXXXXX)"
trap 'rm -f "$catalog"' EXIT
bash scripts/export-wallet-catalog.sh > "$catalog"
WALLET_CATALOG="$catalog" node --test functions/wallet.test.js
