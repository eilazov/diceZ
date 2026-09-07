# Fix: The scrolling game screen and statistics list show no scrollbar

> Follow the steps in order. Run every check. If anything in "STOP if"
> happens, stop and report instead of improvising.

- **Link**: https://flutterpro.design/details/md/scrollbars
- **Needs new dependency**: none

## Why

On the game screen the whole column scrolls (dice, controls, and the 16-row
score table), and the Statistics screen is a plain list. On mobile Flutter draws
no scrollbar by default, so the player has no sense of how far down the content
goes or where they are in it. Enabling a scrollbar app-wide gives both screens
(and anything added later) a thumb that shows position and length.

## Where

Two vertical scrollables, neither wrapped in `Scrollbar`, and `MaterialApp` has
no `scrollBehavior`:

```dart
// lib/widgets/game_screen.dart:120 — current
      body: SingleChildScrollView(
```

```dart
// lib/widgets/statistics_screen.dart:51 — current
    return ListView(
```

```dart
// lib/main.dart:13-28 — current
    return MaterialApp(
      title: 'Dice Zee',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: seed),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: seed,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const MainMenuScreen(),
    );
```

## The fix

Use the article's app-wide approach: a `MaterialScrollBehavior` subclass whose
`buildScrollbar` always wraps the child in a `Scrollbar`, set on `MaterialApp`.
One new file, one line added to `MaterialApp`. This covers both current
scrollables and any future ones, and does not clash with the automatic desktop
scrollbar (it replaces that behaviour).

New file — `lib/scroll_behavior.dart`:

```dart
// lib/scroll_behavior.dart — target (new file)
import 'package:flutter/material.dart';

/// Shows a scrollbar on every scrollable, on every platform (mobile included).
class AlwaysScrollbarBehavior extends MaterialScrollBehavior {
  const AlwaysScrollbarBehavior();

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return Scrollbar(controller: details.controller, child: child);
  }
}
```

`lib/main.dart` — set it on `MaterialApp`:

```dart
// lib/main.dart — target
    return MaterialApp(
      title: 'Dice Zee',
      debugShowCheckedModeBanner: false,
      scrollBehavior: const AlwaysScrollbarBehavior(),
      theme: ThemeData(
```

## Steps

1. Create `lib/scroll_behavior.dart` with the exact contents above.
2. In `lib/main.dart`, add `import 'scroll_behavior.dart';` after
   `import 'widgets/main_menu.dart';` (keep the relative imports together).
3. In `lib/main.dart`, add the line
   `      scrollBehavior: const AlwaysScrollbarBehavior(),` to the `MaterialApp`
   argument list, immediately after `debugShowCheckedModeBanner: false,`.

## Check it

- `dart analyze` exits clean.
- `test -f lib/scroll_behavior.dart` succeeds.
- `grep -c "AlwaysScrollbarBehavior" lib/main.dart` → `2` (import + usage).
- `grep -c "scrollBehavior:" lib/main.dart` → `1`.
- Run the app, open Statistics after playing a game, and scroll: a scrollbar
  thumb appears on the right. Same on the game screen while a match is in
  progress.
- `flutter test` still passes.

## Don't touch

- Do not wrap the individual `SingleChildScrollView` / `ListView` in `Scrollbar`
  as well — combining a manual `Scrollbar` with the app-wide one makes both
  misbehave. The app-wide behaviour is the whole fix.
- Do not change the `Table` in `score_table.dart` — it is not a scrollable.
- No new dependencies.

## STOP if

- `MaterialApp(...)` in `lib/main.dart` doesn't match the quoted excerpt, or it
  already sets `scrollBehavior:`.
- A check fails twice.

## When you're done

Scroll the Statistics list or the game screen: a scrollbar now rides the right
edge showing how much content is left. The behaviour class is
`lib/scroll_behavior.dart`, wired in `lib/main.dart`.
