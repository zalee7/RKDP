#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
work="$(mktemp -d /tmp/rkdp-word-solve-checks.XXXXXX)"
trap 'rm -rf "$work"' EXIT
cp -R RKDP/Resources/WordLists "$work/WordLists"
xcrun swiftc -module-cache-path "$work/modules" \
    RKDP/Models/GameMode.swift RKDP/Views/Shared/AppTheme.swift \
    RKDP/Games/SeededRNG.swift RKDP/Services/WordListService.swift \
    RKDP/Games/Wordle/WordleGame.swift RKDP/ViewModels/WordleViewModel.swift \
    RKDP/Games/Hangman/HangmanGame.swift RKDP/ViewModels/HangmanViewModel.swift \
    RKDP/Games/Anagram/AnagramGame.swift RKDP/Games/WordHunt/WordHuntGame.swift \
    Tests/WordSolveFlowChecks.swift -o "$work/checks"
"$work/checks"
