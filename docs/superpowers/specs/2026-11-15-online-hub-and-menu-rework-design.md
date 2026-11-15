# Dice Zee — Online hub and main-menu rework

**Date:** 2026-11-15
**Builds on:** [online friend games](2026-10-28-online-friend-games-design.md),
[local player profiles](2026-09-10-local-player-profiles-design.md)

## Intent
Online play is buried: challenging a friend is Account → Friends → Challenge,
and seeing the invite or match is Account → Online games. Make online a
first-class menu entry where you can see matches, start one and manage
friends in one place. Drop the manual local-player system it no longer needs.

## Goals
- Main menu: **Play · Online · Statistics · Account** (Players removed).
- **Online hub** (opened from the menu) holds the matches list (invites,
  active, waiting, finished) plus a **New game** action: pick a friend, pick a
  mode, challenge — without leaving the hub. A Friends action opens
  `FriendsScreen` (requests, add by code).
- Signed out → the hub shows a short "Sign in to play online" prompt that opens
  Account.
- Account page keeps sign-in/out and the friend code; its Friends and Online
  games buttons go away.
- Offline seats are "Player 1", "Player 2", … (existing `SeatPalette.label`).
  When signed in, seat 1 plays as the account.
- Statistics: "Everyone" plus one row for the signed-in account (if any games
  were played as it). No manual per-player rows.

## Non-goals / anti-goals
- No online-match preview or "your turn" text on the main menu.
- No new packages, no push notifications.
- No change to online game rules, Firestore layout or rules.

## Approaches
1. **Hub screen behind one Online button** (chosen): reuses
   `OnlineMatchesScreen` as the hub, adds New game + Friends actions. Smallest
   change; menu stays free of Firebase until tapped.
2. Put the matches list on the main menu: rejected by the user.
3. Bottom-nav shell (Play / Online / Stats / Account): bigger restructure than
   asked for.

## Removal of local players
- Delete `PlayersScreen`, `PlayerSelectScreen`, their tests, and
  `PlayerStorage.addProfile/renameProfile/deleteProfile/replaceProfiles`.
- Keep the account profile (`ensureAccountProfile`/`removeAccountProfile`), so
  games played while signed in are attributed to it; guests have
  `profileId == null`. Old history entries with other profile ids stay valid
  and count only under "Everyone".
- Stop syncing the `players` list to the cloud (`CloudStore.loadPlayers/
  savePlayers`, `SyncService` players branch); games sync is unchanged.
- `PlayMenuScreen` no longer branches on profile count: it builds the lineup
  `[account profile or null, null, …]` and starts the game.

## Calls made by me (not agreed in conversation)
- No unread/"your turn" badge on the Online button (would need a Firestore
  stream on the menu); easy to add later.
- "Statistics → account row" reuses the existing per-profile stats screen.
- Friend picker lists accepted friends only; with none, it points to Friends.

## Left to the builder
Layout details of the hub (FAB vs app-bar action), widget keys, test split.
Update CLAUDE.md structure/persistence notes after the change.
