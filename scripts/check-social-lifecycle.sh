#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
catalog="$(mktemp /tmp/rkdp-social-catalog.XXXXXX)"
trap 'rm -f "$catalog"' EXIT
bash scripts/export-solo-reward-catalog.sh 1 --social --test-proofs > "$catalog"
SOCIAL_CATALOG_FIXTURES="$catalog" node --test functions/social-lifecycle.test.js
