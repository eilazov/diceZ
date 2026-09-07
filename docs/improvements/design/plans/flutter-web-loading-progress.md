# Fix: The web build shows a blank white page for several seconds before the app appears

> Follow the steps in order. Run every check. If anything in "STOP if"
> happens, stop and report instead of improvising.

- **Link**: https://flutterpro.design/details/md/flutter-web-loading-progress
- **Needs new dependency**: none

## Why

`flutter run -d chrome` (and any web build of this app) currently loads with an
empty `<body>` — nothing paints until the Flutter engine, CanvasKit runtime and
fonts finish downloading, which is a few seconds of blank white screen. This is
the primary way the app is run for testing on this machine (no Android SDK
installed), so it is hit often. The fix puts a small progress bar in
`web/index.html` that shows immediately and advances at real boot milestones,
then disappears on its own when Flutter takes over. No Dart code changes.

## Where

```html
<!-- web/index.html:34-46 — current -->
<body>
  <!--
    You can customize the "flutter_bootstrap.js" script.
    This is useful to provide a custom configuration to the Flutter loader
    or to give the user feedback during the initialization process.

    For more details:
    * https://docs.flutter.dev/platform-integration/web/initialization
  -->
  <script src="flutter_bootstrap.js" async></script>
</body>
```

The `<head>` of `web/index.html` currently ends with:

```html
<!-- web/index.html:31-33 — current -->
  <title>dice_zee</title>
  <link rel="manifest" href="manifest.json">
</head>
```

There is no `web/style.css` and no `web/flutter_bootstrap.js` in the repo (only
the auto-generated one at build time). The app's seed colour is
`Colors.indigo` (`lib/main.dart:12`), hex `#3F51B5`.

## The fix

Three files: add markup to `web/index.html`, add `web/style.css`, add a custom
`web/flutter_bootstrap.js`. All values from the article, with the bar colour set
to the app's indigo.

`web/index.html` — add the stylesheet link in `<head>` and the progress markup
in `<body>`:

```html
<!-- web/index.html — target <head> tail -->
  <title>dice_zee</title>
  <link rel="manifest" href="manifest.json">
  <link rel="stylesheet" href="style.css" />
</head>
```

```html
<!-- web/index.html — target <body> -->
<body>
  <div class="progress-container">
    <div class="progress-bar"></div>
  </div>

  <script src="flutter_bootstrap.js" async></script>
</body>
```

`web/style.css` — new file, verbatim:

```css
body {
  display: flex;
  justify-content: center;
  align-items: center;
  height: 100vh;
  margin: 0;
  background-color: #ffffff;
}

.progress-container {
  width: 120px;
  height: 8px;
  background-color: #FAFAFA;
  border-radius: 10px;
  overflow: hidden;
}

.progress-bar {
  height: 100%;
  width: 0;
  background-color: #3F51B5;
  transition: width 0.4s ease;
}
```

`web/flutter_bootstrap.js` — new file, verbatim (Flutter uses this instead of
the auto-generated bootstrap when the file exists):

```js
{{flutter_js}}
{{flutter_build_config}}

const bar = document.querySelector('.progress-bar');
const setProgress = (pct) => { bar.style.width = pct + '%'; };

setProgress(20); // bootstrap running

_flutter.loader.load({
  onEntrypointLoaded: async function (engineInitializer) {
    setProgress(50); // main.dart.js downloaded
    const appRunner = await engineInitializer.initializeEngine();
    setProgress(80); // engine ready
    await appRunner.runApp();
    // Flutter has taken over the page, nothing else to do
  },
});
```

## Steps

1. Create `web/style.css` with the exact CSS above.
2. Create `web/flutter_bootstrap.js` with the exact JS above.
3. In `web/index.html`, add the line
   `  <link rel="stylesheet" href="style.css" />` immediately before the
   `</head>` tag.
4. In `web/index.html`, replace the entire `<body>...</body>` block with the
   target `<body>` shown above (keep the existing
   `<script src="flutter_bootstrap.js" async></script>` line; add the
   `progress-container` div above it; the HTML comment inside `<body>` may be
   removed).

## Check it

- `test -f web/style.css` succeeds.
- `test -f web/flutter_bootstrap.js` succeeds.
- `grep -c 'progress-bar' web/index.html` → `1`.
- `grep -c 'style.css' web/index.html` → `1`.
- `grep -c '{{flutter_js}}' web/flutter_bootstrap.js` → `1`.
- Run `flutter run -d chrome` (or `flutter build web` then serve `build/web`):
  a thin indigo bar fills in steps on a white page, then the app replaces it.
  There is no lingering bar once the menu is visible.
- `flutter analyze` exits clean (it does not read `web/`, so this only confirms
  nothing else broke).

## Don't touch

- No Dart files. This fix is entirely under `web/`.
- Do not delete `web/manifest.json`, `web/favicon.png` or `web/icons/`.
- Do not add a large background image or animation to the loader — it would ship
  with the first request and re-create the delay it is meant to hide.
- Known limitation, leave as-is: the loader background is white in both light
  and dark OS themes for the ~3s it is visible. Do not add a dark-mode media
  query unless the author asks.

## STOP if

- `web/index.html`'s `<body>` doesn't match the quoted excerpt.
- A `web/flutter_bootstrap.js` already exists with different contents.
- `flutter run -d chrome` fails to build after the change (revert
  `web/flutter_bootstrap.js` and report — the templating tokens may differ on
  this Flutter version).
- A check fails twice.

## When you're done

Run `flutter run -d chrome`. Instead of a blank white page, a small indigo
progress bar advances through four steps and then the Dice Zee menu appears.
The change is in `web/index.html`, `web/style.css` and `web/flutter_bootstrap.js`.
