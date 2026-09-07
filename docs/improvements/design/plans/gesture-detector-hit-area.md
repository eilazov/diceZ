# Fix: Taps near the edge of a die don't register

> Follow the steps in order. Run every check. If anything in "STOP if"
> happens, stop and report instead of improvising.

- **Link**: https://flutterpro.design/details/md/gesture-detector-hit-area
- **Needs new dependency**: none

## Why

Each die is a `GestureDetector` with no `behavior` set, so it only accepts taps
where its child actually paints. The die has rounded corners (transparent) and,
during the roll animation, is scaled down and rotated inside its 56x56 box —
leaving a ring of live-but-unpainted area where a tap to hold or release the die
silently does nothing. Setting `behavior: HitTestBehavior.opaque` makes the
whole 56x56 box take the tap.

## Where

```dart
// lib/widgets/dice_row.dart:64-98 — current
    return GestureDetector(
      onTap: onTap,
      child: TweenAnimationBuilder<double>(
        key: ValueKey(animateKey),
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        builder: (context, t, child) => Transform.rotate(
          angle: (1 - t) * math.pi / 6,
          child: Transform.scale(scale: 0.85 + 0.15 * t, child: child),
        ),
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: held ? scheme.primaryContainer : scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: held ? scheme.primary : scheme.outlineVariant,
              width: held ? 2 : 1,
            ),
          ),
          child: Stack(
            children: [
              Center(child: _Pips(value: value, color: scheme.onSurface)),
              if (held)
                Positioned(
                  top: 2,
                  right: 2,
                  child: Icon(Icons.push_pin, size: 14, color: scheme.primary),
                ),
            ],
          ),
        ),
      ),
    );
```

Note: `onTap` is `null` when the die can't be held (before the first roll / after
the third). An opaque `GestureDetector` with `onTap: null` simply absorbs the
tap; nothing sits behind the dice row that needs it, so this is fine.

## The fix

Add one line — `behavior: HitTestBehavior.opaque,` — to the `GestureDetector`.

```dart
// lib/widgets/dice_row.dart — target
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: TweenAnimationBuilder<double>(
```

## Steps

1. In `lib/widgets/dice_row.dart`, in `_Die.build`, add
   `behavior: HitTestBehavior.opaque,` as the first argument of the
   `GestureDetector(`, on the line directly above `onTap: onTap,`.

## Check it

- `dart analyze` exits clean.
- `grep -c "behavior: HitTestBehavior.opaque" lib/widgets/dice_row.dart` → `1`.
- `flutter test` still passes. `test/widgets/dice_row_test.dart` taps
  `find.byKey(const ValueKey('die_2'))` and expects the callback with index `2`;
  making the hit area larger does not change that.
- Manually: start a game, roll, and tap the very corner of a die — it toggles
  the hold pin now instead of ignoring the tap.

## Don't touch

- Do not change the `Transform.scale` / `Transform.rotate` animation here — that
  is a separate concern (the roll animation is being redesigned elsewhere).
- Do not add `behavior` to any other widget; `dice_row.dart` has the only
  `GestureDetector` in the app.
- The `Padding(horizontal: 4)` between dice in `DiceRow.build` is intentional
  spacing and sits outside each `GestureDetector`; leave it.

## STOP if

- The `GestureDetector` in `dice_row.dart` doesn't match the quoted excerpt, or
  it already sets `behavior:`.
- A check fails twice.

## When you're done

In a game, tap the rounded corner or the edge of any die: it now holds/releases
instead of missing. The change is one line in `lib/widgets/dice_row.dart`.
