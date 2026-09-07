# Design findings — Dice Zee

Selected from the `flutter-improve-design` catalog audit. All nine were chosen for planning.
Plans live in `docs/improvements/design/plans/`.

---

**1. Don't let the system navigation bar cover the bottom of scrollable lists**

the last item of scrollable lists gets obscured by the system navigation bar. Leave space as tall as that bar at the end of the list so the last item has a breathing room against the bar.

**Link:** https://flutterpro.design/details/md/safe-area-replacement

---

**2. Show loading progress while Flutter web boots**

Flutter web takes a few seconds to boot, and users stare at a blank white page wondering if the site is broken. Show a splash or progress bar instead, so they know the app is coming.

**Link:** https://flutterpro.design/details/md/flutter-web-loading-progress

---

**3. Add haptic feedback to key moments**

the app feels flat when taps and results happen in silence. A subtle haptic vibration on a tab switch, a successful submit or an error makes the app feel responsive in the hand.

**Link:** https://flutterpro.design/details/md/haptic-feedback

---

**4. Use tabular figures for changing numbers**

digits have different widths in most fonts, so a timer or counter jumps around as it changes. Tabular figures make every digit the same width: numbers stay still and line up.

**Link:** https://flutterpro.design/details/md/tabular-figures

---

**5. Show the app version in settings**

when a user reports a bug, the first question is which version they're on, and the app has no place to answer it.

**Link:** https://flutterpro.design/details/md/show-app-version

---

**6. Show scrollbars on vertical scrollables**

a scrollbar shows the user where they are in the list and how much is left.

**Link:** https://flutterpro.design/details/md/scrollbars

---

**7. Make the whole GestureDetector area tappable**

by default `GestureDetector` only takes taps on what its child paints, so the padding and the gaps between an icon and a text do nothing. The user taps the row and misses. The whole box should take the tap.

**Link:** https://flutterpro.design/details/md/gesture-detector-hit-area

---

**8. Limit text scaling so layouts don't break**

some users increase their device's text size for accessibility, and at high scales layouts overflow and break. After the fix, run the app at the capped scale yourself to confirm nothing breaks.

**Link:** https://flutterpro.design/details/md/text-scale-factor

---

**9. Show a friendly view when a widget breaks**

when a widget fails to build, users see an empty grey box in release. Show a friendly "Something went wrong" in the app's own colors instead.

**Link:** https://flutterpro.design/details/md/friendly-error-view
