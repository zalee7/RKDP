#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
work="$(mktemp -d /tmp/rkdp-match-wallet.XXXXXX)"
trap 'rm -rf "$work"' EXIT
# Compile the actual Swift rank policy without its Firebase transaction methods.
cp Tests/MatchWalletPolicyExport.swift "$work/Export.swift"
printf '\nenum RankPolicyExport {\n' >> "$work/Export.swift"
awk '/^    static func rankDelta\(/ { copying=1 } /^    private func finishSessionIfNeeded/ { copying=0 } copying' RKDP/Services/RankingService.swift >> "$work/Export.swift"
awk '/^    private static func adjustedRankBase\(/ { copying=1 } copying' RKDP/Services/RankingService.swift >> "$work/Export.swift"
bash scripts/check-earned-showcase.sh "$work/Export.swift" > "$work/policy.json"
MATCH_POLICY_FIXTURES="$work/policy.json" node --test functions/match-rewards.test.js
