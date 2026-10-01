#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
catalog="$(mktemp /tmp/rkdp-match-catalog.XXXXXX)"
trap 'rm -f "$catalog"' EXIT
bash scripts/export-solo-reward-catalog.sh 2 --online --test-proofs > "$catalog"
MATCH_CATALOG_FIXTURES="$catalog" node --test functions/match-lifecycle.test.js
