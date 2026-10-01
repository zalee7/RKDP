#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
work="$(mktemp -d /tmp/rkdp-word-hunt-checks.XXXXXX)"
trap 'rm -rf "$work"' EXIT
xcrun swiftc -module-cache-path "$work/modules" \
    RKDP/Games/WordHunt/WordHuntGame.swift \
    RKDP/ViewModels/WordHuntViewModel.swift \
    RKDP/Games/Anagram/AnagramGame.swift \
    RKDP/ViewModels/AnagramViewModel.swift \
    Tests/WordGameInputChecks.swift -o "$work/checks"
"$work/checks"
