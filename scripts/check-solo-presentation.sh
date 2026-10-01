#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
work="$(mktemp -d /tmp/rkdp-solo-checks.XXXXXX)"
trap 'rm -rf "$work"' EXIT

# Compile the production presentation types without the Firebase-dependent app.
awk '/^struct SoloResultStat:/ { copying=1 } /^struct GameSession:/ { copying=0 } copying' RKDP/Models/GameSession.swift > "$work/Results.swift"
sed -i '' '1i\
import Foundation\
' "$work/Results.swift"
xcrun swiftc -module-cache-path "$work/modules" \
    RKDP/Models/GameMode.swift RKDP/Views/Shared/AppTheme.swift \
    "$work/Results.swift" RKDP/Models/Rank.swift \
    Tests/SoloPresentationChecks.swift -o "$work/checks"
"$work/checks"
