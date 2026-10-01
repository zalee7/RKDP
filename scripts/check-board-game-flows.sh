#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
work="$(mktemp -d /tmp/rkdp-board-checks.XXXXXX)"
trap 'rm -rf "$work"' EXIT
xcrun swiftc -module-cache-path "$work/modules" \
    RKDP/Models/GameMode.swift RKDP/Views/Shared/AppTheme.swift RKDP/Games/SeededRNG.swift \
    RKDP/Games/Sudoku/SudokuBoard.swift RKDP/Games/Sudoku/SudokuSolver.swift RKDP/Games/Sudoku/SudokuGenerator.swift RKDP/ViewModels/SudokuViewModel.swift \
    RKDP/Games/Minesweeper/MinesweeperBoard.swift RKDP/ViewModels/MinesweeperViewModel.swift \
    RKDP/Games/Kakuro/KakuroBoard.swift RKDP/Games/Kakuro/KakuroGenerator.swift RKDP/ViewModels/KakuroViewModel.swift \
    RKDP/ViewModels/KenKenViewModel.swift Tests/BoardGameFlowChecks.swift -o "$work/checks"
"$work/checks"
