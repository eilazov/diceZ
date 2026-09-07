# Fix: There is nowhere in the app to see which version is installed

> Follow the steps in order. Run every check. If anything in "STOP if"
> happens, stop and report instead of improvising.

- **Link**: https://flutterpro.design/details/md/show-app-version
- **Needs new dependency**: `package_info_plus` — the only way to read the app's
  version and build number at runtime. The article's fix requires it. **This
  project's `CLAUDE.md` says no package may be added without the author's
  approval, so Step 1 is to get that approval.**

## Why

This app is distributed by sideloading APKs and IPAs, so there is no store
listing to check a version against. When something misbehaves on a phone, there
is currently no way to tell which build is on it. A dim version line at the
bottom of the main menu answers that at a glance.

There is no settings screen in this app; the main menu is the natural home for
the line, matching the article's "usually at the bottom of the settings page".
Shorebird is not used (not in `pubspec.yaml`), so the Shorebird patch part of
the article's widget is omitted.

## Where

The app has no version display anywhere and does not depend on
`package_info_plus`. The main menu column is where the line goes:

```dart
// lib/widgets/main_menu.dart:35-62 — current
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Dice Zee',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.displaySmall,
                  ),
                  const SizedBox(height: 40),
                  Text('New game', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 12),
                  for (final count in [2, 3, 4])
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: FilledButton.tonal(
                        onPressed: () => _startGame(context, count),
                        child: Text('$count Players'),
                      ),
                    ),
                  const SizedBox(height: 32),
                  OutlinedButton.icon(
                    onPressed: () => _openStatistics(context),
                    icon: const Icon(Icons.bar_chart),
                    label: const Text('Statistics'),
                  ),
                ],
              ),
```

```yaml
# pubspec.yaml:dependencies — current
dependencies:
  flutter:
    sdk: flutter
  cupertino_icons: ^1.0.8
  shared_preferences: ^2.5.5
```

## The fix

Add `package_info_plus`, add a `VersionIndicator` widget (article's widget,
trimmed to drop Shorebird and adapted to this codebase's Dart 3.13 style), and
place it at the end of the menu column.

New file — `lib/widgets/version_indicator.dart`:

```dart
// lib/widgets/version_indicator.dart — target (new file)
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// A dim `AppName 1.2.0 (3)` line. Reads the package version once on init and
/// renders nothing until it is available. Meant for the bottom of a screen.
class VersionIndicator extends StatefulWidget {
  const VersionIndicator({super.key});

  @override
  State<VersionIndicator> createState() => _VersionIndicatorState();
}

class _VersionIndicatorState extends State<VersionIndicator> {
  String? _label;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final PackageInfo info = await PackageInfo.fromPlatform();
    if (!mounted) return;
    setState(() {
      _label = '${info.appName} ${info.version} (${info.buildNumber})';
    });
  }

  @override
  Widget build(BuildContext context) {
    final label = _label;
    if (label == null) return const SizedBox.shrink();

    return Text(
      label,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        fontFeatures: const [FontFeature.tabularFigures()],
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}
```

`lib/widgets/main_menu.dart` — add a spacer and the indicator as the last two
children of the menu `Column`:

```dart
// lib/widgets/main_menu.dart — target (end of the Column children)
                  OutlinedButton.icon(
                    onPressed: () => _openStatistics(context),
                    icon: const Icon(Icons.bar_chart),
                    label: const Text('Statistics'),
                  ),
                  const SizedBox(height: 24),
                  const VersionIndicator(),
                ],
              ),
```

## Steps

1. **Get the author's approval to add `package_info_plus`** (required by
   `CLAUDE.md`). If not approved, STOP and report — the rest of this plan needs
   the package.
2. Add `package_info_plus: ^8.3.1` to `pubspec.yaml` under `dependencies:`,
   after the `shared_preferences:` line, then run `flutter pub get`.
3. Create `lib/widgets/version_indicator.dart` with the exact contents above.
4. In `lib/widgets/main_menu.dart`, add `import 'version_indicator.dart';` with
   the other relative imports (alphabetical: after `import 'statistics_screen.dart';`).
5. In `lib/widgets/main_menu.dart`, at the end of the menu `Column`'s `children`
   list, immediately after the `OutlinedButton.icon(...)` for Statistics, add:
   ```dart
                  const SizedBox(height: 24),
                  const VersionIndicator(),
   ```

## Check it

- `dart analyze` exits clean.
- `grep -c "package_info_plus" pubspec.yaml` → `1`.
- `test -f lib/widgets/version_indicator.dart` succeeds.
- `grep -c "VersionIndicator" lib/widgets/main_menu.dart` → `2` (the import and
  the usage).
- Run the app: a small grey `dice_zee 1.0.0 (1)` line sits under the Statistics
  button on the menu.
- `flutter test` still passes. `test/widgets/main_menu_test.dart` and
  `test/widget_test.dart` pump the menu; `PackageInfo.fromPlatform()` returns
  mock data under the test binding and the widget renders a `SizedBox.shrink()`
  first frame, so the existing finders (`find.text('2 Players')`,
  `find.text('Statistics')`) are unaffected. If a test fails because it now
  needs `PackageInfo` mock values, add
  `PackageInfo.setMockInitialValues(...)` — but do not change assertions.

## Don't touch

- Do not add a settings screen; the menu line is the whole fix.
- Do not include Shorebird / `ShorebirdUpdater` code — this project doesn't use
  Shorebird.
- Do not add any dependency other than `package_info_plus`, and only after
  approval.
- Do not make the line prominent — keep `fontSize: 12` and the muted colour.

## STOP if

- The author does not approve adding `package_info_plus`.
- The menu `Column` doesn't match the quoted excerpt.
- A check fails twice.

## When you're done

Open the app to the main menu: a faint `dice_zee 1.0.0 (1)` line now sits below
the Statistics button, so any phone's build can be identified at a glance. The
new widget is `lib/widgets/version_indicator.dart`.
