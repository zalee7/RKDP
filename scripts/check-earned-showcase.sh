#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
work="$(mktemp -d /tmp/rkdp-earned-checks.XXXXXX)"
trap 'rm -rf "$work"' EXIT
awk '/^enum SessionStatus:/ { copying=1 } /^struct PostMatchRewardSnapshot/ { copying=0 } /^struct MatchPlayer:/ { copying=1 } copying' RKDP/Models/GameSession.swift > "$work/Results.swift"
sed -i '' '1i\
import Foundation\
' "$work/Results.swift"
awk '/^struct MatchResolution/ { copying=1 } copying' RKDP/ViewModels/MultiplayerViewModel.swift > "$work/Resolver.swift"
printf 'import Foundation\nenum PartyScoring {\n' > "$work/PartyScoring.swift"
awk '/^    static func compare\(/ { copying=1 } /^    private static func winnerReason/ { copying=0 } copying' RKDP/Models/SocialModels.swift >> "$work/PartyScoring.swift"
printf '}\n' >> "$work/PartyScoring.swift"
xcrun swiftc -module-cache-path "$work/modules" \
    RKDP/Models/GameMode.swift RKDP/Views/Shared/AppTheme.swift \
    RKDP/Models/Rank.swift RKDP/Models/Cosmetics.swift RKDP/Models/RankedAccess.swift \
    RKDP/Models/CoinEconomy.swift RKDP/Models/User.swift "$work/Results.swift" "$work/Resolver.swift" "$work/PartyScoring.swift" \
    "${1:-Tests/EarnedShowcaseChecks.swift}" -o "$work/checks"
"$work/checks"
