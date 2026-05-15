# RKDP — Ranked Puzzle Arena

A multiplayer iOS puzzle game with coin wagering, per-mode leaderboards, and a cosmetics shop.

## Game Modes
| Mode | Description |
|------|-------------|
| **Sudoku** | Classic 9×9 number placement, 4 difficulties |
| **Minesweeper** | Mine-avoidance grid, scales from 9×9 to 20×30 |
| **Kakuro** | Number crossword — runs must sum to clue with no repeats |
| **KenKen** | Arithmetic grid — cages must hit their +/−/×/÷ target |

## Ranking System
Bronze → Silver → Gold → Platinum → Diamond → Master  
Every mode has an independent rank. Points are awarded/deducted after each ranked match, scaled by difficulty and time.

## Coin Wagering
- Each ranked match requires both players to stake coins.
- Available wager tiers scale with your rank tier (higher rank = higher stakes).
- Winner takes the full pot; tie returns wagers.
- Starting balance: **500 coins**.

## Cosmetic Shop
Spend coins on board themes, avatars, number fonts, and cell border styles. All cosmetic, no pay-to-win.

## Tech Stack
- **Swift / SwiftUI** (iOS 17+)
- **Firebase** — Auth, Firestore (users/rankings), Realtime Database (live match sync)
- **XcodeGen** — project file generated from `project.yml`

## Getting Started

### Prerequisites
- Xcode 15+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen): `brew install xcodegen`
- A Firebase project with iOS app configured

### Setup
```bash
# 1. Clone the repo
git clone https://github.com/zalee7/rkdp.git
cd rkdp

# 2. Add your Firebase config
# Replace RKDP/SupportingFiles/GoogleService-Info.plist with the one
# downloaded from your Firebase console.

# 3. Generate the Xcode project
xcodegen generate

# 4. Open in Xcode
open RKDP.xcodeproj
```

### Firebase Setup
1. Create a project at [firebase.google.com](https://firebase.google.com)
2. Enable **Authentication** (Email/Password + Sign in with Apple)
3. Enable **Cloud Firestore** — start in test mode
4. Enable **Realtime Database**
5. Download `GoogleService-Info.plist` and replace the placeholder in `RKDP/SupportingFiles/`

### Firestore Security Rules (recommended)
```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{uid} {
      allow read: if request.auth != null;
      allow write: if request.auth.uid == uid;
    }
    match /leaderboards/{mode}/entries/{uid} {
      allow read: if request.auth != null;
      allow write: if request.auth.uid == uid;
    }
    match /sessions/{sessionID} {
      allow read, write: if request.auth != null;
    }
    match /matchmaking/{queue}/queue/{uid} {
      allow read, write: if request.auth.uid == uid;
    }
  }
}
```

## Project Structure
```
RKDP/
├── App/                    # Entry point, root view, tab navigation
├── Models/                 # Data types (User, Rank, GameMode, Wager, Cosmetics, …)
├── Games/
│   ├── Sudoku/             # Board, Generator, Solver
│   ├── Minesweeper/        # Board + mine placement
│   ├── Kakuro/             # Board + layout-based generator
│   └── KenKen/             # Board + Latin-square generator
├── Services/               # Firebase wrappers (Auth, Firestore, RealtimeDB, Ranking)
├── ViewModels/             # ObservableObject controllers per feature
├── Views/
│   ├── Auth/               # Login, Sign Up
│   ├── Home/               # Mode picker, difficulty/wager flow
│   ├── Games/              # Puzzle UIs (Sudoku, Minesweeper, Kakuro, KenKen)
│   ├── Rankings/           # Leaderboard
│   ├── Multiplayer/        # Matchmaking + live match
│   ├── Profile/            # Stats, ranks, shop
│   └── Shared/             # TimerView, NumberPadView, RankBadgeView, …
└── SupportingFiles/        # Info.plist, GoogleService-Info.plist
```
