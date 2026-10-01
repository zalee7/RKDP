#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
catalog="$(mktemp /tmp/rkdp-apple-products.XXXXXX)"
trap 'rm -f "$catalog"' EXIT
bash scripts/check-earned-showcase.sh Tests/AppleProductCatalogExport.swift > "$catalog"
APPLE_PRODUCT_CATALOG="$catalog" node --test functions/apple-purchases.test.js
