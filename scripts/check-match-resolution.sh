#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
work="$(mktemp -d /tmp/rkdp-match-checks.XXXXXX)"
trap 'rm -rf "$work"' EXIT
awk '/^struct MatchPlayerResult:/ { copying=1 } /^struct GameSession:/ { copying=0 } copying' RKDP/Models/GameSession.swift > "$work/Results.swift"
sed -i '' '1i\
import Foundation\
' "$work/Results.swift"
awk '/^struct MatchResolution/ { copying=1 } copying' RKDP/ViewModels/MultiplayerViewModel.swift > "$work/Resolver.swift"
printf 'import Foundation\nenum PartyScoring {\n' > "$work/PartyScoring.swift"
awk '/^    static func compare\(/ { copying=1 } /^    private static func winnerReason/ { copying=0 } copying' RKDP/Models/SocialModels.swift >> "$work/PartyScoring.swift"
printf '}\n' >> "$work/PartyScoring.swift"
xcrun swiftc -module-cache-path "$work/modules" \
    RKDP/Models/GameMode.swift RKDP/Models/Rank.swift RKDP/Views/Shared/AppTheme.swift \
    "$work/Results.swift" "$work/Resolver.swift" "$work/PartyScoring.swift" \
    Tests/MatchResolutionChecks.swift -o "$work/checks"
"$work/checks"
