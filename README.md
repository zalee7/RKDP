# Puzzle Party

Puzzle Party is a SwiftUI iOS puzzle game prototype built around quick solo practice, ranked matches, casual online play, friend challenges, party rooms, hourly tournaments, and cosmetic progression.

The app is currently in active prototype/TestFlight development. Gameplay, economy values, Firestore rules, and shop rotation are still being tuned.

## Current Game Modes

| Mode | Type | Description |
|------|------|-------------|
| **Color Link** | Grid | Connect matching colors with paths that cover the board. |
| **Grid Duel** | Grid | Slide rows and columns to recreate the target color pattern. |
| **Sudoku** | Grid | Classic 9x9 Sudoku with solo and online formats. |
| **Minesweeper** | Grid | Uncover safe cells without triggering a mine. |
| **Wordle** | Word | Same-word race with shared deterministic targets online. |
| **Lava Rescue** | Word | Category-based word rescue game with lava-meter misses. |
| **Word Hunt** | Word | Find valid words in a letter grid before time runs out. |
| **Anagrams** | Word | Build as many valid words as possible from shared letters. |

## Play Formats

- **Solo**: difficulty progression, best solo stats, and practice without coin risk.
- **Ranked**: division-based matchmaking, fixed coin wagers, rank points, ranked W/L, and leaderboards.
- **Casual Online**: random online matches with no rank impact, no wager, and small capped daily coin rewards.
- **Friends / Exhibition**: Play Now live invites and Play Later async challenges.
- **Party Rooms**: join-code rooms for up to 8 players using the same shared puzzle.
- **Hourly Tournaments**: rank-tier events with one shared puzzle attempt and virtual coin prizes.

## Online Fairness

Online sessions are designed around shared puzzle state:

- Grid and board modes use the shared `GameSession.seed`.
- Word/content modes store exact `puzzleData` for target words, letters, categories, or grids.
- Ranked, casual, exhibition, party, bot, rematch, and tournament flows reuse this same deterministic path.

## Ranking And Coins

- Each game mode has its own rank ladder: Bronze, Silver, Gold, Platinum, Diamond, and Master.
- Ranked wagers are fixed by division instead of selected manually.
- Ranked settlement is zero-sum: winner gains the opponent's wager, loser loses their wager, draws do not move coins.
- Casual, exhibition, party, and tournament matches do not affect ranked W/L or rank points.
- Coins are virtual currency used for cosmetics, ranked wagers, and tournament entry. They cannot be cashed out or redeemed for real-world value.

## Cosmetics And Customization

Puzzle Party includes a rotating cosmetic shop and profile customization:

- Name titles
- Board / background themes
- Tile themes
- Puzzle-piece avatar parts: head, face, body, and aura
- Free custom avatar body color via hex input
- Price-based rarity badges: Free, Common, Rare, Epic, and Legendary

All cosmetics are visual only and do not affect matchmaking, rank, rewards, puzzle generation, or gameplay outcomes.

## Social Features

- Username search
- Friend requests
- Friend profile preview
- Play Now invites with ready-up flow
- Play Later async challenges
- Party rooms with join codes and friend invites
- Push notifications for friend/social events through Firebase Cloud Functions and FCM

## Tech Stack

- **Swift / SwiftUI** for the iOS app
- **Firebase Authentication** for accounts
- **Cloud Firestore** for users, sessions, social docs, shop/cosmetic state, tournaments, and leaderboards
- **Realtime Database** for live match ready/result sync
- **Firebase Cloud Messaging** for push notifications
- **Cloud Functions for Firebase** for notification triggers
- **StoreKit** for consumable coin packs and ranked access products
- **Bundled word-list text files** for deterministic offline-safe word content

## Repository Notes

This repo includes the current prototype app source and Firebase configuration files needed for development. Before making a fork or deployment public, review:

- `RKDP/SupportingFiles/GoogleService-Info.plist`
- `firestore.rules`
- `firebase.json`
- `.firebaserc`
- `functions/`

The Firebase iOS API key in `GoogleService-Info.plist` is a client key, not a private server secret, but it should be restricted in Google Cloud Console to the app's iOS bundle ID.

Current bundle ID:

```text
com.rkdp.app
```

## Getting Started

### Prerequisites

- Xcode 15+
- iOS 17+
- A Firebase project with iOS app configured
- Firebase CLI if deploying rules/functions
- Apple Developer account for Push Notifications, Sign in with Apple, StoreKit, and TestFlight distribution

### Setup

```bash
git clone https://github.com/zalee7/RKDP.git
cd RKDP
open RKDP.xcodeproj
```

If you are using your own Firebase project, replace:

```text
RKDP/SupportingFiles/GoogleService-Info.plist
```

with the file downloaded from your Firebase Console.

### Firebase Setup

Enable the Firebase products used by the prototype:

1. Authentication
2. Cloud Firestore
3. Realtime Database
4. Cloud Functions
5. Cloud Messaging

Deploy rules/functions from the repo root when configured:

```bash
firebase deploy --only firestore
firebase deploy --only functions
```

The current Firestore rules live in:

```text
firestore.rules
```

They are still prototype/beta rules and should be tightened before production launch.

## Project Structure

```text
RKDP/
├── App/                    # App entry point, app delegate, root navigation
├── Games/                  # Core game logic by mode
│   ├── ColorLink/
│   ├── Gridlock/           # Public-facing mode name: Grid Duel
│   ├── Hangman/            # Public-facing mode name: Lava Rescue
│   ├── Minesweeper/
│   ├── Sudoku/
│   ├── WordHunt/
│   └── Wordle/
├── Models/                 # Users, sessions, ranks, social models, tournaments, cosmetics
├── Resources/
│   ├── Assets.xcassets/    # App visuals, coin asset, sounds/images
│   └── WordLists/          # Editable bundled word banks
├── Services/               # Firebase, ranking, StoreKit, sound, word-list services
├── ViewModels/             # Observable app state/controllers
├── Views/
│   ├── Auth/
│   ├── Games/
│   ├── Home/
│   ├── Multiplayer/
│   ├── Profile/
│   ├── Rankings/
│   └── Shared/
└── SupportingFiles/        # Info.plist, entitlements, Firebase plist

functions/                  # Firebase Cloud Functions notification triggers
firestore.rules             # Firestore security rules
firebase.json               # Firebase deploy config
```

## Prototype Status

Puzzle Party is not final production software yet. Current focus areas include:

- tightening Firestore rules
- stabilizing Play Now / Play Later / Party flows
- balancing coin economy and cosmetics
- improving UI readability across the light Puzzle Party theme
- expanding word banks and mode breakdowns
- preparing a cleaner public portfolio presentation
