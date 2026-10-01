#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
catalog="$(mktemp /tmp/rkdp-solo-proof.XXXXXX)"
trap 'rm -f "$catalog"' EXIT
bash scripts/export-solo-reward-catalog.sh 2 --test-proofs > "$catalog"
SOLO_REWARD_CATALOG="$catalog" node --test functions/solo-rewards.test.js
