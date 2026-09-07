# Fix: A widget build failure shows an empty grey box in release

> Follow the steps in order. Run every check. If anything in "STOP if"
> happens, stop and report instead of improvising.

- **Link**: https://flutterpro.design/details/md/friendly-error-view
- **Needs new dependency**: none (SDK only: `dart:async`,
  `package:flutter/foundation.dart`, `package:flutter/material.dart`,
  `package:flutter/services.dart`)

## Why

If any widget throws while building, Flutter replaces it with a red screen in
debug and a blank grey box in release — the player just sees part of the screen
vanish with no explanation. Setting a custom `ErrorWidget.builder` swaps that for
a themed "Something went wrong" panel (with the exception shown in debug only),
and a hidden long-press-to-copy so a real stack trace can be retrieved from a
release build.

## Where

`main()` does not set `ErrorWidget.builder`:

```dart
// lib/main.dart:1-5 — current
import 'package:flutter/material.dart';

import 'widgets/main_menu.dart';

void main() => runApp(const DiceZeeApp());
```

There is no error view widget in `lib/`.

## The fix

Add the article's `FriendlyErrorView` as a new file (transcribed below with
Dart-3.13-safe syntax — the article's enum dot-shorthands like `.min` are
expanded to `MainAxisSize.min` etc.), then install it in `main()`.

New file — `lib/widgets/friendly_error_view.dart`, verbatim:

```dart
import 'dart:async';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Friendly replacement for Flutter's red error screen, installed via
/// [ErrorWidget.builder]. Release builds show no technical details; debug
/// builds add the exception and stack trace. A long press anywhere copies
/// the details to the clipboard.
///
/// Adapts to the space the broken widget occupied: a full layout when there
/// is room, an icon-only badge inside small slots.
class FriendlyErrorView extends StatefulWidget {
  const FriendlyErrorView({
    super.key,
    required this.details,
  });

  final FlutterErrorDetails details;

  @override
  State<FriendlyErrorView> createState() => _FriendlyErrorViewState();
}

class _FriendlyErrorViewState extends State<FriendlyErrorView> {
  Timer? _timer;
  bool _copied = false;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _copy() async {
    HapticFeedback.mediumImpact();

    await Clipboard.setData(
      ClipboardData(
        text:
            '${widget.details.exceptionAsString()}\n\n${widget.details.stack}',
      ),
    );

    if (!mounted) return;

    setState(() => _copied = true);

    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 2600), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;

    // The view can land anywhere in the tree, including where no Material or
    // Directionality ancestor exists, so it provides its own. The transparent
    // Material also prevents the yellow "missing Material" text underlines.
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Material(
        type: MaterialType.transparency,
        child: Semantics(
          container: true,
          label: 'Something went wrong. Restarting the app should fix it.',
          child: ExcludeSemantics(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onLongPress: _copy,
              child: LayoutBuilder(
                builder: (context, c) {
                  final bool full = c.maxHeight.isFinite &&
                      c.maxHeight >= 320 &&
                      c.maxWidth.isFinite &&
                      c.maxWidth >= 300;

                  // Only fill bounded axes; under unbounded constraints
                  // (lists, FittedBox) the view sizes to its content.
                  return Container(
                    width: c.hasBoundedWidth ? c.maxWidth : null,
                    height: c.hasBoundedHeight ? c.maxHeight : null,
                    decoration: BoxDecoration(
                      color: cs.primaryContainer,
                      borderRadius: BorderRadius.circular(full ? 0 : 28),
                    ),
                    child: full
                        ? _FullView(
                            details: widget.details,
                            copied: _copied,
                          )
                        : _CompactView(
                            details: widget.details,
                            copied: _copied,
                          ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FullView extends StatelessWidget {
  const _FullView({
    required this.details,
    required this.copied,
  });

  final FlutterErrorDetails details;
  final bool copied;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final TextTheme tt = Theme.of(context).textTheme;

    final Widget header = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Badge(
          size: 104,
          copied: copied,
        ),
        const SizedBox(height: 24),
        Text(
          'Something went wrong',
          textAlign: TextAlign.center,
          style: tt.titleLarge?.copyWith(
            color: cs.onPrimaryContainer,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Restarting the app should fix it.',
          textAlign: TextAlign.center,
          style: tt.bodyMedium?.copyWith(
            color: cs.onPrimaryContainer.withValues(alpha: 0.75),
          ),
        ),
      ],
    );

    // Centered while the content fits, scrollable once it doesn't: the
    // sliver forces the child to at least viewport height, and the centered
    // column simply grows past it when the debug stack trace is long.
    return CustomScrollView(
      slivers: [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Padding(
            // Clear the status bar and home indicator; the view has no
            // Scaffold or SafeArea above it (and possibly no MediaQuery).
            padding: EdgeInsets.fromLTRB(
              32,
              (MediaQuery.maybePaddingOf(context)?.top ?? 0) + 32,
              32,
              (MediaQuery.maybePaddingOf(context)?.bottom ?? 0) + 32,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                header,
                if (kDebugMode) ...[
                  const SizedBox(height: 32),
                  _DebugText(
                    '${details.exceptionAsString()}\n\n${details.stack}',
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _CompactView extends StatelessWidget {
  const _CompactView({
    required this.details,
    required this.copied,
  });

  final FlutterErrorDetails details;
  final bool copied;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _Badge(
                size: 48,
                copied: copied,
              ),
              if (kDebugMode) ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: 240,
                  child: _DebugText(
                    details.exceptionAsString(),
                    maxLines: 2,
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The badge briefly swaps its "!" for a check after the hidden long-press
/// copy gesture, so regular users never see a hint.
class _Badge extends StatelessWidget {
  const _Badge({
    required this.size,
    required this.copied,
  });

  final double size;
  final bool copied;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;

    return Container(
      width: size,
      height: size,
      decoration: ShapeDecoration(
        color: cs.primary,
        // A soft flower built with the SDK's StarBorder, so this file needs
        // no shape package.
        shape: const StarBorder(
          points: 12,
          innerRadiusRatio: 0.8,
          pointRounding: 0.7,
          valleyRounding: 0.3,
        ),
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: Icon(
          copied ? Icons.check_rounded : Icons.priority_high_rounded,
          key: ValueKey<bool>(copied),
          color: cs.onPrimary,
          size: size * 0.4,
        ),
      ),
    );
  }
}

/// Exception text shown only in debug builds.
class _DebugText extends StatelessWidget {
  const _DebugText(this.text, {this.maxLines, this.textAlign});

  final String text;
  final int? maxLines;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;

    return Text(
      text,
      maxLines: maxLines,
      textAlign: textAlign,
      overflow: maxLines == null ? TextOverflow.fade : TextOverflow.ellipsis,
      style: TextStyle(
        fontFamily: 'monospace',
        fontFamilyFallback: const ['Menlo', 'Courier'],
        fontSize: 12,
        color: cs.onPrimaryContainer.withValues(alpha: 0.6),
      ),
    );
  }
}
```

`lib/main.dart` — set the builder before `runApp`:

```dart
// lib/main.dart — target
import 'package:flutter/material.dart';

import 'widgets/friendly_error_view.dart';
import 'widgets/main_menu.dart';

void main() {
  ErrorWidget.builder = (details) => FriendlyErrorView(details: details);
  runApp(const DiceZeeApp());
}
```

## Steps

1. Create `lib/widgets/friendly_error_view.dart` with the exact contents shown
   above (the whole code block).
2. In `lib/main.dart`, add `import 'widgets/friendly_error_view.dart';` on the
   line above the existing `import 'widgets/main_menu.dart';` (alphabetical).
3. In `lib/main.dart`, replace the single line
   `void main() => runApp(const DiceZeeApp());` with the four-line `void main()
   { ... }` block shown above.
4. Run `dart analyze`. If — and only if — it reports `prefer_const_constructors`
   or `prefer_const_literals_to_create_immutables` on a line inside
   `friendly_error_view.dart`, add `const` at exactly that call site. Make no
   other change to the file.

## Check it

- `dart analyze` exits clean.
- `test -f lib/widgets/friendly_error_view.dart` succeeds.
- `grep -c "ErrorWidget.builder" lib/main.dart` → `1`.
- `grep -c "friendly_error_view.dart" lib/main.dart` → `1`.
- `flutter test` still passes (no test builds a deliberately-throwing widget, so
  the builder is installed but never invoked).
- Optional manual check: temporarily put `throw 'boom';` at the top of
  `MainMenuScreen.build`, run in debug — a themed panel with "Something went
  wrong" and the exception text appears instead of the red screen; long-press
  copies the details. Remove the `throw` afterward.

## Don't touch

- Do not localize or restyle the panel beyond what the article ships.
- Do not remove the `if (kDebugMode)` guards — release builds must not show
  exception text.
- Do not wire the long-press copy to any visible button; it is intentionally
  hidden.
- No new dependencies.

## STOP if

- `lib/main.dart` doesn't match the quoted `main()` excerpt.
- `lib/widgets/friendly_error_view.dart` already exists.
- `dart analyze` reports an *error* (not a `const` lint) coming from the pasted
  widget — report it with the message rather than editing the widget's logic.
- A check fails twice.

## When you're done

`ErrorWidget.builder` is now set in `lib/main.dart`, backed by
`lib/widgets/friendly_error_view.dart`. If any screen ever fails to build, the
player sees a themed "Something went wrong" panel in the app's colours instead of
a grey gap, and a long press copies the real error out of a release build.
