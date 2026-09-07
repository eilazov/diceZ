# Fix: At large system font sizes the game screen overflows and breaks

> Follow the steps in order. Run every check. If anything in "STOP if"
> happens, stop and report instead of improvising.

- **Link**: https://flutterpro.design/details/md/text-scale-factor
- **Needs new dependency**: none

## Why

A player who has bumped up their device's text size for readability will see the
game screen break: the "Player N's turn" title, the round/rolls row, and the
5-column score table with its abbreviated labels and preview numbers all grow
until they overflow and clip. The app currently places no ceiling on text
scaling. Clamping it to a maximum of 1.1x app-wide keeps large-text users close
to their preference while keeping the dense screens intact.

## Where

`MaterialApp` has no `builder`, so nothing limits `MediaQuery.textScaler`:

```dart
// lib/main.dart:11-29 — current
  Widget build(BuildContext context) {
    const seed = Colors.indigo;
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
  }
```

## The fix

Add a `builder` to `MaterialApp` that re-provides `MediaQuery` with
`textScaler` clamped to a max scale factor of 1.1, per the article.

```dart
// lib/main.dart — target
    return MaterialApp(
      title: 'Dice Zee',
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        final mediaQueryData = MediaQuery.of(context);
        return MediaQuery(
          data: mediaQueryData.copyWith(
            textScaler: mediaQueryData.textScaler.clamp(maxScaleFactor: 1.1),
          ),
          child: child!,
        );
      },
      theme: ThemeData(
```

## Steps

1. In `lib/main.dart`, inside the `MaterialApp(` argument list, add the
   `builder:` closure shown above immediately after
   `debugShowCheckedModeBanner: false,` and before `theme: ThemeData(`.

## Check it

- `dart analyze` exits clean.
- `grep -c "clamp(maxScaleFactor: 1.1)" lib/main.dart` → `1`.
- `flutter test` still passes.
- Manually confirm the cap works: run the app, set the OS font size to its
  largest, and open a 4-player game — the score table and headers still fit
  (text stops growing at 1.1x) instead of overflowing.

## Don't touch

- Do not set a fixed `textScaler` of 1.0 — that ignores the user's preference
  entirely; the clamp keeps scaling up to 1.1x.
- Do not add per-screen `MediaQuery` overrides; the fix is app-wide in
  `MaterialApp.builder`.
- If `MaterialApp` already has a `builder:` (e.g. from another change), do not
  add a second one — put the `MediaQuery` clamp inside the existing builder,
  wrapping whatever `child` it already returns.

## STOP if

- `MaterialApp(...)` in `lib/main.dart` doesn't match the quoted excerpt and it
  does not already have a `builder:` to merge into.
- A check fails twice.

## When you're done

Set the phone's font size to maximum and open a 4-player game: the layout holds
together now because text scaling is capped at 1.1x. The clamp is in
`lib/main.dart`'s `MaterialApp.builder`.
