# Dice Zee

A personal-use, Yatzy-style dice game for 2–4 players, hot-seat on one device.
Built with Flutter for iOS and Android, sideload only — it's not on the App
Store or Play Store.

## Backstory

Inspired by [DiceZee by Kikkerland](https://www.kikkerland.com/), a small
travel dice game my girlfriend picked up at Dussmann in Berlin. We ended up
playing it constantly on that trip, so afterwards I decided to vibe-code a
digital version we could carry on our phones instead of a tin of dice.

## Gameplay

2–4 players take turns in a 15-round match. On each turn a player rolls up to
3 times, holding any dice they want to keep between rolls, then commits the
result to one of their 15 still-open scoring categories. The device passes to
the next player, and the match ends once everyone has filled all 15
categories. Highest total wins; a shared top total is a tie. Finished matches
are saved to local history, and a statistics screen aggregates them.

The 15 categories: ones–sixes, one pair, two pairs, three of a kind, four of a
kind, full house, small straight, large straight, Dice Zee (five of a kind),
and chance. There's no upper-section bonus, no bonus-Yahtzee, no joker rules,
and no single-player/bot mode — it's designed for people in the same room.

Full design specs live under [docs/superpowers/specs](docs/superpowers/specs).

## Tech

- **Flutter / Dart**, targeting iOS + Android only.
- Plain `StatefulWidget` + `setState` for state management — no Provider,
  Riverpod, Bloc, or routing package. Navigation is plain
  `Navigator.push(MaterialPageRoute(...))`.
- Game logic (`lib/models/`) is pure Dart with no `package:flutter` import,
  fully unit-tested and separate from the widgets that render it
  (`lib/widgets/`).
- Persistence is `shared_preferences` only — match history is stored as a
  single JSON blob and statistics are derived from it on read. It's the only
  non-SDK dependency.
- See [CLAUDE.md](CLAUDE.md) for the full project structure and conventions.

## Development notes

This app was built almost entirely by prompting [Claude
Code](https://claude.com/claude-code) — describing the game, the rules, and
the desired UI/UX, and iterating on its output — rather than by hand-writing
or manually reviewing the implementation line by line. It's a personal, casual
project; treat the code accordingly.

## Commands

```bash
flutter pub get          # after changing pubspec.yaml
flutter test             # run all tests
flutter analyze          # static analysis
flutter run              # run on a connected device / emulator
flutter build apk        # Android sideload build
flutter build ios        # iOS build (needs macOS + Xcode)
```
