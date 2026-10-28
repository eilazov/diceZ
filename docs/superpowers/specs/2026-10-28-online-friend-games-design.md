# Dice Zee — Online games with friends (Phase 3)

**Date:** 2026-10-28
**Builds on:** [accounts and cloud sync](2026-09-30-accounts-and-cloud-sync-design.md), friends (PR #9)

## Goal
Two friends play one match on their own phones, taking turns asynchronously:
challenge a friend, they accept, each plays their turn on their own device and
sees the other's dice live.

## Non-goals
- No anti-cheat: the active player's phone rolls the dice. Server-side rolls
  would need Cloud Functions and a paid plan; accepted for a friends game.
- No push notifications (would need a new package). "Your turn" shows when the
  Online games screen is open.
- Two players only. No forfeit/resume-after-abandon in v1 (a pending invite can
  be declined or withdrawn; an active match runs to the end).

## Data
`liveMatches/{id}`:
```
players: [uidA, uidB]        // seat 0 = challenger
names:   [nameA, nameB]
mode:    'standard'|'extended'
status:  'pending'|'active'|'finished'
state:   DiceGame JSON       // dice, held, rolls, round, seat, score cards
createdAt, finishedAt (ms)
```
Both participants read/write the document; others have no access. Invites are
found with `players array-contains uid`.

## Flow
Friends → **Challenge** (pick mode) → pending match. Invitee sees it under
**Online games** (Account page) → Accept/Decline. Active: `OnlineGameScreen`
renders the shared `ScoreTable`/dice; controls are enabled only on your seat.
Every roll/hold/commit writes the new state. When the match is over, each
device saves a `GameResult` to local history once (deduped by `finishedAt`).

## Code
- `DiceGame.toJson/fromJson`, `ScoreCard.toJson/fromJson`
- `OnlineMatch` model; `OnlineMatchStore` interface (Firestore + in-memory)
- `OnlineMatchService`: challenge / respond / act-on-turn rules
- `OnlineMatchesScreen`, `OnlineGameScreen`; turn header and control deck
  extracted from `GameScreen` into shared widgets.
