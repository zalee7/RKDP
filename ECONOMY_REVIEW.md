# Puzzle Party Economy Review

September 27, 2026. Source-code review and arithmetic audit, not live revenue or player-behavior data. No economy values, purchases, account balances, or deployed services were changed.

## September 29 Solo Reward Foundation (Disabled, Not Deployed)

Follow-up: the first shared-wallet slice now joins solo payouts, shop daily claims and direct cosmetic purchase/equipping behind server callables and one ledger. Reviewed-snapshot migration, client purchase grant-before-finish and pending-delivery recovery are implemented locally. Remaining online/Daily rewards and server Apple verification still block activation. See `SOLO_REWARDS_ROLLOUT.md` for current details; no reward amounts, catalog prices, production balances or deployed rules were changed. Rules compilation passed a dry run only.

The approved small solo payouts are implemented in local client/server policy code, with completion evidence for all eight games, server-issued puzzle attempts, transaction receipts, and pending-claim recovery. They are **not active in the app or deployed to Firebase**. The client rollout switch is off; the backend additionally requires two private rollout flags and a migrated server wallet. Do not turn those gates on yet.

The wallet audit found existing client-written ranked/casual rewards, daily progression, purchases, and cosmetic spending. Migrating only solo balances would break or race those paths. Their shared-wallet migration remains unfinished; see `SOLO_REWARDS_ROLLOUT.md` for the exact scope, test status, and activation checklist. Existing users retain their current reward behavior in this build.

Approved per-successful-fresh-puzzle payouts, Easy / Medium / Hard / Expert:

| Game | Coins |
| --- | --- |
| Color Link | 3 / 4 / 5 / 7 |
| Word Guess, Lava Rescue | 4 / 5 / 7 / 9 |
| Anagrams, Word Hunt | 4 / 5 / 6 / 8 |
| Minesweeper | 4 / 6 / 9 / 12 |
| Solitaire | 5 / 7 / 10 / 14 |
| Sudoku | 5 / 8 / 12 / 18 |

Daily play remains +25 once per UTC day across modes. Legitimate failed final attempts get no base puzzle coins. Timed games must finish their full round and have a positive score for a base payout. Starting/backing out gets nothing; previously issued puzzle identities cannot earn again. These protections prevent duplicate/replay grants, not all automation or cheating.

Next achievement direction: a dedicated area with Ready to Claim notifications and one-time Claim actions. Badge rewards remain prestige only; their relationship to achievements is still to be designed. No achievement grants or UI were added in this pass.

## September 28 Ranked Rewards Update (Current)

- Ranked wagers are replaced by match rewards: wins pay Bronze 20 / Silver 30 / Gold 40 / Platinum 50 / Diamond 60 / Master 75, based on the player's rank at match start. Completed human losses pay 5; draws pay 10. No human ranked daily coin cap.
- Ranked entry and rematches require access/tickets as before, but no coins. No coin deductions for losses, forfeits, or canceling the match-found screen.
- New sessions write zero legacy wager values. Updated clients also ignore legacy wagers when settling an unapplied result. Already-applied historical payouts are not replayed or refunded. All clients should update together; old builds still contain old settlement logic.
- Quitters earn zero. Synthetic forfeit auto-wins earn zero; an already submitted successful final attempt can still earn its win reward. Normal first-finisher races award the losing participant 5 even when the race ends before their submission.
- Training bots remain win-reward-only, with the existing three rewarded wins per day across games. No bot loss/draw coins. Human rewards do not touch the casual/ad caps.
- Settlement reads the saved session, retains the existing per-user applied-outcome guard, and atomically records the coin payout on the session with the user balance. Result reopens show the recorded payout rather than old wager math.
- Lobby, rank guide, shop, signup, and ranked-pass copy now describe rewards instead of wagers. Coin packs, pass prices, rank scoring, daily grants, cosmetics, and dormant tournament fees are unchanged.
- Next: trusted wallet/purchase delivery and remaining reward loopholes. Client-side rules are still not an anti-cheat boundary. Stake reservation is no longer needed for new zero-stake ranked matches; audit findings about the old wager model remain historical below.

## Earlier September 28 Wager Update (Superseded)

- Implemented fixed ranked stakes: Bronze 35, Silver 60, Gold 100, Platinum 150, Diamond 225, Master 300. Ranked entry and the How to Play guide share this table.
- Keep automatic rank-based wagers and the existing queues. Do not add selectable stakes or an optional-wager ranked queue: splitting players would increase wait times.
- Rank scoring, pass prices, coin packs, daily sources, cosmetic prices, and hidden tournament fees are unchanged.
- Existing sessions (and their rematches) retain their recorded wagers; this is not a retroactive balance or settlement migration. Older app versions must update to use the new table.
- Next priority: close reward loopholes and purchase-delivery gaps. The authority, reservation, eligibility, and recovery issues below are still open; lowering stakes does not fix them.

The remainder is the original September 27 audit. Its "current" wager column refers to the old build; its proposed launch column is now implemented.

## Verdict

The cosmetic pricing, coin-pack ladder, and modest achievement budget can work together. The current high-rank wager curve cannot comfortably coexist with them: losing one Master match costs more than the entire 6,000-coin pack and more than the most expensive launch cosmetic. Ranked access is also a separate purchase/entry gate, so coin shortages can block someone who already bought permanent access.

Prioritize reliable wallet settlement and a much flatter wager curve before adding coin achievements. Do not reduce ordinary free rewards or inflate coin packs to compensate for punitive stakes.

## Scope And Confidence

- Checked coin models, wager tables, ranked/casual result settlement, Daily submissions, bot rewards, direct cosmetic purchases, StoreKit purchase flow, rewarded-ad service, shop visibility, and repository security rules.
- Compiled the actual local catalog/economy models to calculate counts, prices, and conversion comparisons. These are not estimates from old conversation messages.
- Dollar prices below are current fallback/display prices in the repository. StoreKit uses localized App Store prices when products load. App Store Connect product configuration and actual live prices were not inspected.
- Firestore rules findings concern the checked-in rules configured by `firebase.json`; deployed rules were not fetched. The backend functions checked here send notifications, not authoritative wallet settlement.
- No live purchase, real ad, account mutation, or simultaneous two-client payout test was performed.

## 1. Current Coin Sources

| Source | Amount | Limit / behavior |
| --- | ---: | --- |
| New account | 500 | Once |
| Shop daily claim | 50 | Once per UTC day |
| Daily play bonus | 25 | Once per UTC day after a recorded attempt |
| Casual victory | 15 | Shares 90-coin daily casual cap |
| Other casual result | 5 | Includes the non-win outcome path; forfeits need eligibility review |
| All Daily challenges | 50 | Once per day after entries exist for all eight games |
| Rewarded coin ad | 75 | Intended cap 2/day, shared by shop and post-game |
| Bronze training-bot win | 35 normally | Current Bronze wager, at most 3 rewarded wins/day across games |
| Human ranked victory | Opponent's stake | Transfer from opponent when both settlements complete, not fresh global issuance |
| Proposed achievements | 1,450 total | Not implemented; finite lifetime budget, not daily income |

Solo, friend, and party play do not currently give a recurring base coin payment for every victory. They can contribute the once-daily play bonus. Badge tiers do not pay coins.

The Daily bonus currently checks submitted entries, not successful clears. Copy says "Clear every mode," so either change it to "Submit all eight challenges" or deliberately change eligibility. Do not model this as eight successful wins without changing the code.

### Illustrative earning profiles

These assume rewards are claimed and eligible, exclude ranked transfers, purchases, achievements, and spending, and are not forecasts of actual users.

| Pattern | Coins/day | Coins/30 days |
| --- | ---: | ---: |
| Claim + one real game | 75 | 2,250 |
| Above + four casual games, two wins/two losses | 115 | 3,450 |
| Claim + play + full casual cap + eight Daily entries | 215 | 6,450 |
| Same maximum plus two intended rewarded ads | 365 | 10,950 |

Three eligible Bronze bot victories can add another 105/day while a player remains eligible and has entries. This is conditional onboarding issuance, not income to promise every player. Bot losses remove the wager. Human ranked outcomes can increase or decrease an individual's totals substantially.

**Release caveats:** rewarded ads are not integrated: DEBUG waits briefly, while release throws `adNetworkNotConfigured`. Also, the checked-in Firestore rules have no `dailyChallenges` match; if those exact rules are deployed, Daily access is denied and its 50-coin bonus cannot be relied on. Treat 215/365 as configured-path scenarios pending those release fixes.

## 2. Wagers: The Main Balance Problem

For equal stakes, a ranked win adds the stake, a loss subtracts it, and a draw changes no coins. There is no extra base ranked coin reward. Stakes are checked before entering, not debited/reserved up front in the normal matchmaking path.

| Rank | Current stake | Proposed launch stake | Days of basic 75/day to replace one current loss |
| --- | ---: | ---: | ---: |
| Bronze | 35 | 35 | 0.47 |
| Silver | 100 | 60 | 1.33 |
| Gold | 300 | 100 | 4 |
| Platinum | 900 | 150 | 12 |
| Diamond | 2,500 | 225 | 33.33 |
| Master | 7,500 | 300 | 100 |

The proposed column is a design recommendation for playtesting, not an implemented or empirically optimized economy.

- Starting 500 coins cover 14 uninterrupted Bronze losses, but do not cover even one Platinum stake.
- A 1,000-coin pack covers 28 Bronze losses, one Platinum loss, or no Diamond/Master entry from an empty wallet.
- A 13,500-coin pack covers just one uninterrupted Master loss before falling below the next 7,500 entry requirement.
- With the proposed 300 Master stake, 1,000 coins cover three uninterrupted losses, and a basic 75/day replaces one loss in four days. This is still a meaningful loss; it is not a guarantee of comfortable unlimited play.
- A wager is principally a transfer, not an economy-wide coin sink. Skilled winners accumulate other players' coins; losing players bear the refill pressure. Cosmetics are the principal active non-transfer sink.
- At a 50% decisive-match win rate and equal stakes, expected wager earnings are zero before other rewards, but volatility can still empty a finite wallet. At 40%, expected net is -0.2 times the wager per game: over ten matches, -15,000 at current Master versus -600 at the proposed Master stake.
- Rank points rise on average even at 50% wins against equal divisions (+30/-15 before each game's fixed multiplier). That can move an otherwise break-even coin player into much higher required stakes. Rank and bankroll do not naturally rise together.
- Fixed online presets still scale rank progression internally: Color Link +120/-60, medium-preset games generally +45/-22, and Solitaire/Word Guess/Word Hunt +30/-15 against an equal division. Do not silently change these in an economy patch, but account for different promotion speeds.

### Ranked access decision

Current fallback prices are $2.99 per mode and $9.99 all modes forever, plus one free entry per mode/day. Intended ranked ads grant one ticket per mode/day, four total. Tickets/access do not cover the coin stake.

Keep those pass prices for the first test. However, a "forever" pass should not feel unusable because the same player is then coin-blocked. The store does mention entry-only access, but the combined experience still needs testing.

Near-term: reduce stakes and clearly show maximum possible coin loss before confirmation. Longer-term, strongly consider a coin-free ranked route with wagering optional. Optional wagering needs explicit consent, matched stake rules, liquidity/queue planning, and settlement design; it is not just a toggle that can be added safely during this audit. A new pity/refill subsidy would create another faucet and must be budgeted before introduction.

## 3. Coin Packs

| Pack | Coins | Repository fallback price | Coins per dollar | Bonus value vs smallest pack |
| --- | ---: | ---: | ---: | ---: |
| Small | 1,000 | $0.99 | 1,010 | Baseline |
| Medium | 3,300 | $2.99 | 1,104 | About 9% |
| Large | 6,000 | $4.99 | 1,202 | About 19% |
| Mega | 13,500 | $9.99 | 1,351 | About 34% |

Recommendation: keep this ladder initially. It offers sensible increasing value and useful purchasing power for cosmetics. Do not make packs larger merely to support the existing Master wager. These comparisons concern purchase quantities, not cash-out value; coins cannot be redeemed for money.

Revenue will depend on conversion, cosmetic desirability, retention, and repeat content. None of those can be validated from source code. This review is not a revenue forecast.

## 4. Cosmetics And Actual Spending Power

Current paid launch-visible catalog, excluding hidden avatar items and legacy categories:

| Category | Paid items | Price range | Cost of all items |
| --- | ---: | ---: | ---: |
| Titles | 52 | 250-4,000 | 56,050 |
| Board/background themes | 6 | 200-3,200 | 8,200 |
| Tile themes | 8 | 550-2,600 | 11,200 |
| Solitaire card themes | 4 | 800-2,800 | 6,300 |
| Heads | 11 | 450-4,000 | 19,600 |
| Expressions | 8 | 450-1,900 | 10,150 |
| Bodies | 9 | 900-4,200 | 20,400 |
| Auras | 8 | 900-4,000 | 16,800 |
| Total | 106 | 200-4,200 | 148,700 |

Median item price is 1,200. Items rotate; catalog value does not imply everything is purchasable on the same day or equally desirable. Titles are nearly half the item count, so do not mistake count for strong visual-cosmetic demand.

- Common items in this selection cost 200-450; Rare 500-1,100; Epic 1,200-2,400; Legendary 2,500-4,200.
- At 75 coins/day, a median item takes 16 days from zero; a 4,200 item takes 56 days. At the illustrative 115/day, those take about 10.4 and 36.5 days. These exclude starting coins and achievements.
- With the intended fully engaged 365/day, those take about 3.3 and 11.5 days. That user must complete all eight Dailies, reach the casual cap, claim rewards, and watch both ads; it is not ordinary casual income.
- The 3,300 pack buys two median-price items with change, or many individual Legendary items. The 13,500 pack buys three top-priced 4,200 items with 900 left. That is a reasonable paid acceleration if the items feel desirable.
- Keep prices for now. Polish the strongest visual items before raising prices or filling the catalog with more similar paid titles.
- Some paid titles imply earned status, including Party Champion, Grand Master, and Zero Error. Differentiate aspirational shop titles from verified earned achievements in names/descriptions; avoid selling wording that falsely reads as proof of a feat.
- Rarity is currently inferred from price. Future price discounts/rebalancing should not silently change an item's perceived rarity; separate an explicit rarity from pricing before adding sale mechanics.

## 5. Achievements Fit The Economy

Keep the proposed 1,450-coin lifetime achievement budget, paid once per achievement. It is around one median item plus change, about 19.3 basic earning days, and under 1% of the entire current paid catalog's cost.

Starting coins plus every proposed achievement total 1,950, before ongoing play rewards. That does not hand a new user the entire shop or even the most expensive Legendary cosmetic. The entire achievement set also requires significant play across all eight games; it should not be described as a day-one grant.

Badge tiers remain prestige only: no repeat coin payouts, no rank boosts, no wager multipliers. A shared run can satisfy multiple distinct once-only achievements if explicitly allowed. Maintain separate reward receipts so retrying settlement cannot mint coins twice.

Do not cut this budget to address high-rank wagering. It would remove motivating small accomplishments without solving the bankroll problem.

## 6. Release-Blocking Implementation Findings

### P1: Wallet and result authority is still client-side

`firestore.rules:12` allows users to write their entire own user document, including coins, purchase markers, caps, and inventory. `firestore.rules:22` allows any signed-in user to write sessions. `FirestoreService.swift:344` grants coin packs from client-supplied product/transaction IDs with only per-user deduplication. StoreKit does verify the transaction on the honest client, but there is no server-side proof boundary for the database write.

If these repository rules are deployed, edited clients can bypass the whole economy. Before launch, move grants, purchases, spending, and result payouts to trusted server operations; protect balance/result fields; bind verified purchases globally to the credited account; use server time for daily caps; and test access rules. Do not regard client transactions alone as anti-cheat.

### P1: StoreKit transaction finishes before coins are delivered

`CoinPackStoreKitService.swift:42` calls `finish()` before `ShopViewModel.purchaseCoinPack` writes coins. A network/write failure can leave a completed purchase without its coins. No `Transaction.updates`/unfinished-transaction recovery handling was found in the app.

Verify purchase, durably grant it idempotently, then finish. Handle pending purchases, app restarts, account binding, refunds/revocations, and retry reconciliation. Apple's [Transaction.finish documentation](https://developer.apple.com/documentation/storekit/transaction/finish()) specifies finishing after delivering the purchased content or service.

### P1: Stakes are not reserved; both players are settled separately

`MultiplayerViewModel.startSearch` checks a local balance. The normal `FirestoreService.createAndNotify` path creates the session without reserving either stake. `RankingService.swift:167` later adds/subtracts coins for one user at a time, with no nonnegative balance guard. Spending from another device or overlapping activity can leave insufficient funds; independent settlement can credit a winner before the loser is processed.

Reserve equal stakes against fresh balances in a server transaction, store the session's escrow once, then resolve the pot once. Refund reserved amounts for a legitimate cancellation/draw, according to an explicit policy. Do not patch this only with `max(0, coins)`: that would erase losses while keeping winner rewards and create currency.

### P1: Rewarded ads are not production-ready

`RewardedAdService.swift:17` is a DEBUG delay/release error, not an ad SDK. No real ad revenue or release-mode 150/day ad faucet exists yet. Integrate rewarded-only ads and verify rewarded completion before issuing server-side grants. Never treat a simulated callback as production verification.

### P1/P2: Daily access and eligibility mismatch

The repository rules do not grant access to `dailyChallenges`, despite the service using it. Verify deployed behavior before counting its reward. The service also awards the all-mode bonus for submitted entries, while UI says "clear." Choose and consistently explain one definition. I favor valid completed attempts for the daily attendance bonus, with successful solves rewarded by achievements separately.

### P2: Remaining economy cleanup

- Casual settlement requests the 5-coin non-win reward without excluding abandoned/forfeit paths. Validate real-attempt eligibility before payout; don't incentivize rapid quitting.
- `abortMatchFound` removes one coin via an unguarded increment request. Document or remove this small cancellation sink, and prevent repeat charges for the same cancellation.
- Bot wins currently issue new coins, unlike human ranked transfers. Keep the cross-mode daily cap and report bot issuance separately.
- Legacy rematches reuse original stake amounts even if ranks changed. Validate and show the agreed session stake explicitly; don't assume every rematch uses the new rank tier.
- Tournaments remain hidden and cosmetic packs are disabled. Their legacy costs/refunds are not part of the active loop. Hidden tournament math would remove 10% of entry pool before payout if re-enabled; reassess it then.
- Shop footer still mentions tournament entries even though the entry point is hidden. Keep monetization copy aligned with shipped features.

## 7. Recommended Sequence

1. Fix wallet authority, StoreKit delivery/recovery, stake reservation, and two-player settlement. Confirm Daily rules and real ad integration separately.
2. Approve and test the flatter 35 / 60 / 100 / 150 / 225 / 300 wager ladder. Keep rank points, pass prices, coin packs, and daily sources unchanged during that isolated balance test.
3. Settle the paid-access/coin-blocking experience before release. Prefer a non-punitive route to keep competing, not selling emergency coin refills after losses.
4. Add game achievements under the 1,450 lifetime ceiling only after secure, idempotent grants exist. Keep badge tiers unpaid.
5. Measure per-rank wallet distributions, failure-to-enter rates, coins minted/burned/transferred by source, time to first desired cosmetic, purchase delivery failures, and repeat spending. Separate testers/bots from real players.
6. Tune with observed retention and spending, not speculative revenue targets. Review frequent low-wallet players as a retention problem, not automatically a conversion opportunity.

## Acceptance Checks

- No double credit from replays, callback retries, relogging, two devices, or reused purchase receipts.
- No negative balances; no spending reserved stakes; both sides of a match reconcile even when one player never reopens the app.
- Ledger conserves human wager coins across settlement; coins enter only through approved grants/purchases and leave only through approved sinks.
- Verified purchase delivery survives disconnection before/after grant and before/after StoreKit finish.
- Daily/ad/casual/bot caps use server-authoritative time and do not reset from client clock changes.
- No forced ads. Every optional ad grants exactly the advertised reward after verified completion.
- One-time achievements cannot become repeat faucets; actual currency totals match the disclosed reward receipt.
- Correct active-feature copy and localized StoreKit prices; no claims of cash-out value.

## Store Policy Note

Keep coins non-redeemable and avoid real-world prizes. Do not add purchased-coin expiry or an automatic season wipe of purchased currency. Apple's [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/) prohibit expiration of purchased in-game currency and prohibit IAP currency for real-money gaming. Virtual wagering still warrants a specific policy/age-rating review; this source audit is not legal clearance or a guarantee of App Review approval.
