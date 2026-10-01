#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
work="$(mktemp -d /tmp/rkdp-solo-catalog.XXXXXX)"
trap 'rm -rf "$work"' EXIT
cp -R RKDP/Resources/WordLists "$work/WordLists"
xcrun swiftc -module-cache-path "$work/modules" \
    RKDP/Models/GameMode.swift RKDP/Views/Shared/AppTheme.swift RKDP/Games/SeededRNG.swift \
    RKDP/Services/WordListService.swift RKDP/Games/Wordle/WordleGame.swift \
    RKDP/Games/Hangman/HangmanGame.swift RKDP/Games/Anagram/AnagramGame.swift \
    RKDP/Games/WordHunt/WordHuntGame.swift RKDP/Games/Sudoku/SudokuSolver.swift \
    RKDP/Games/Sudoku/SudokuGenerator.swift RKDP/Games/Minesweeper/MinesweeperBoard.swift \
    RKDP/Games/Kakuro/KakuroBoard.swift RKDP/Games/Kakuro/KakuroGenerator.swift \
    Tests/SoloRewardCatalogExport.swift -o "$work/export"
"$work/export" "${1:-4}" "${@:2}"
