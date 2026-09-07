# Dice Zee — Design Brief

A description of the app as it exists today, for a designer/design-agent doing a
visual redesign. It covers purpose, rules, every screen, every interactive
element, and every visual state. It does **not** prescribe a visual direction —
that is the redesign's job.

The current UI is stock Material 3 with an indigo seed colour and no custom
styling; it is functional but plain. Everything below describes *what must be on
screen and what it does*, not how it should look.

---

## 1. What the app is

- **Dice Zee** is a personal-use, Yatzy/Yahtzee-style dice game.
- **Players:** 2–4, **simple hot-seat pass-and-play on one device** — people
  physically pass the phone around. **One shared score table** shows every
  player's scores at once (like a paper Yahtzee sheet). No online play, no
  accounts, no network of any kind.
- **Platform:** Flutter, phone form factor, portrait. Runs on iOS and Android;
  distributed by personal sideload only (not the App Store / Play Store).
- **Audience:** the owner and friends/family, playing casually. It replaces a
  paper score sheet.
- **No AI/bot, no single-player mode.** A game always has 2–4 human seats.

### Tone
Casual tabletop game night. It should feel tactile and playful (it's dice), quick
to read at arm's length while passing the phone, and legible in both light and
dark. Not a slick "casino" product, not childish.

---

## 2. Game mechanics (the rules the UI expresses)

A **match** is **15 rounds**. In each round every player takes one **turn**.

**A turn:**
1. The active player taps **Roll**. All 5 dice roll.
2. They may **tap dice to "hold"** them, then **Roll** again to re-roll only the
   dice that are *not* held.
3. They get **up to 3 rolls** per turn. They can stop early.
4. They then **commit**: tap one of their 15 still-open score categories. That
   category is scored for the current dice (possibly **0** if the dice don't
   match it) and locked for that player for the rest of the match.
5. The device passes to the next player.

When all players have taken their turn, the round advances. After round 15 every
player has filled all 15 categories. **Highest grand total wins.** A shared top
total is a **tie** (reported as a tie, no tie-break).

Each finished match is saved to local history, which feeds the Statistics screen.

### The 15 categories and how they score

Given the player's 5 committed dice:

| Category (label shown) | Score |
|---|---|
| Ones / Twos / Threes / Fours / Fives / Sixes | Sum of the dice showing that face (e.g. three 4s in "Fours" = 12) |
| One pair | 2 × the highest face that appears ≥ 2 times; 0 if no pair |
| Two pairs | Sum of the four dice forming two **different** pairs; 0 otherwise |
| Three of a kind | Sum of **all five** dice if some face appears ≥ 3 times; else 0 |
| Four of a kind | Sum of **all five** dice if some face appears ≥ 4 times; else 0 |
| Full house | 25 for three of one face + two of another; else 0 |
| Small straight | 30 for four consecutive values (1-2-3-4, 2-3-4-5, or 3-4-5-6); else 0 |
| Large straight | 40 for five consecutive values (1-2-3-4-5 or 2-3-4-5-6); else 0 |
| Dice Zee | **100** for five of a kind; else 0 |
| Chance | Sum of all five dice, always |

No upper-section bonus, no bonus for extra "Dice Zee"s, no joker rules. "Dice Zee"
is this game's name for the Yahtzee category — note it collides with the app name,
so the redesign may want to visually distinguish them or rename the row.

---

## 3. Constraints the redesign must respect

- **Flutter + Material 3.** Theming via `ThemeData` / `ColorScheme`. Custom
  widgets and painters are fine.
- **Only dependency is `shared_preferences`.** Adding any package (animation libs,
  icon sets, font packages, etc.) needs the owner's approval first. Custom fonts
  bundled as assets are OK.
- **State is plain `setState`**; navigation is plain `Navigator.push`. A redesign
  that needs richer navigation/animation should flag it rather than assume.
- **Portrait phone only.** No landscape, no tablet layout required (but don't
  break on a wide screen).
- **Light and dark both matter** — the app follows the system setting.
- The dice faces are **drawn in code as pip circles**, not images — fully
  restylable (custom faces, numerals, textures, 3D, etc.).
- Icons currently used are Material glyphs: `casino` (Roll), `push_pin` (held
  die), `bar_chart` (Statistics), `history` is *not* currently used.
- There is **no app icon / launcher branding / splash** yet — in scope if the
  designer wants to define it.

---

## 4. Screens

The app has **three screens** and **one dialog**.

```
MainMenuScreen  ──"2/3/4 Players"──▶  GameScreen  ──match ends──▶  "Game over" dialog ──"Back to menu"──▶ MainMenuScreen
      │
      └────────"Statistics"────────▶  StatisticsScreen
```

Both `GameScreen` and `StatisticsScreen` are pushed routes with a standard
back arrow in the app bar (or the OS back gesture).

---

### 4.1 Main Menu (`MainMenuScreen`)

The app opens here. Currently: a centered column, max width 360, on a plain
`Scaffold` with **no app bar**.

Elements, top to bottom:
1. **"Dice Zee"** — the app title / wordmark. Currently just large text
   (`displaySmall`), centered. This is the main branding moment.
2. Section label **"New game"**.
3. Three buttons, full-width, stacked: **"2 Players"**, **"3 Players"**,
   **"4 Players"**. Currently tonal filled buttons. Tapping one starts a match
   with that many players (pushes `GameScreen`).
4. A gap, then **"Statistics"** — currently an outlined button with a bar-chart
   icon. Pushes `StatisticsScreen`.

That is the entire screen. There is no settings, no rules/help, no quit.

**Redesign notes / opportunities:** this screen is mostly empty space. Room for a
proper wordmark/logo, a hero dice illustration, a rules/how-to-play entry point,
maybe surfacing a headline stat ("Best ever: 243"). The player-count choice could
be a segmented control, a stepper, or dice-themed (choose 2–4 pips) instead of
three buttons.

---

### 4.2 Game Screen (`GameScreen`) — the important one

This is where ~95% of the time is spent and where the current design is weakest:
it's a single scrolling column and everything competes for attention.

App bar: title **"Dice Zee"**, back arrow.

Body (currently one vertical `SingleChildScrollView` column), top to bottom:

1. **Turn banner** — **"Player N's turn"** (large text, `titleLarge`). The
   handoff cue when the phone is passed.

2. **Status row** — left: **"Round N / 15"**, right: **"Rolls left: M"**
   (M counts down 3 → 2 → 1 → 0 within a turn).

3. **Dice row** — the **5 dice**, centered, ~56pt squares with pip faces.
   - Before the first roll of a turn: dice show a placeholder face (all 1s),
     not interactive.
   - After a roll: each die is tappable to **hold / release**. A held die is
     visually distinct (filled background, coloured border, a small pin icon in
     the corner).
   - On each roll, the un-held dice play a short scale + slight-rotation tween
     (~250 ms). This is the only animation in the app and is deliberately minimal.

4. **Roll button** — a filled button with a dice icon, label **"Roll"**.
   - Enabled when the player has rolls left and the match isn't over.
   - Disabled (greyed) at 0 rolls left, or once the match is over.
   - The label does not currently show the count (the status row does).

5. **Shared score table** (`ScoreTable`) — one table, all players. Described in
   4.3. This is both the scoreboard (everyone sees everyone's scores and totals)
   and the way the active player commits their turn.

**Turn/commit interaction:**
- The active player's **column** is highlighted. Only cells in that column are
  interactive, and only on the active player's turn.
- Until they have rolled at least once this turn, no cell is interactive.
- After rolling, each **still-open cell in the active player's column** shows a
  **greyed preview number** = what the current dice would score there (including
  `0`). Tapping it **commits** that score, locks the cell, and passes the turn.
- All other cells are read-only: filled cells show their locked score, empty
  cells are blank.

**End of match:** when the last cell is committed, the app saves the result and
shows the **"Game over" dialog** (4.4).

**Known gaps / redesign opportunities:**
- **No "pass the phone to Player N" moment.** The turn just changes. A deliberate
  handoff/confirm screen ("Player 3, ready?") would prevent the next player
  seeing the previous player's final dice and mis-tapping, and is a natural place
  for personality.
- The stacked text blocks (turn banner, round/rolls) have little hierarchy — a
  redesign should make "whose turn + how many rolls left" instantly scannable.
- Dice, hold state, and the Roll button are the tactile core and currently look
  like grey rounded rectangles.
- The screen scrolls as one long column (dice + controls + 16-row table). Consider
  a fixed dice/controls area with only the table scrolling, and/or grouping the
  table (upper number categories vs. combinations).
- The table's active-column highlight is a faint tint; the "preview vs locked
  vs empty" cell states are carried only by text colour. All of this needs
  stronger, more legible treatment — this table is the core surface.
- No seat identity beyond "P1".."P4" text. Per-seat colour could carry through
  the dice area, turn banner, and the table's active column and header.
- With 4 players the table is dense on a phone; category labels are abbreviated
  to fit (see 4.3). The redesign owns making 4 columns + labels comfortably
  readable at arm's length.

---

### 4.3 Shared score table (`ScoreTable`, used inside Game Screen)

One table. **Rows = the 15 categories + a Totals row. Columns = the players
(2–4).** It is the whole scoreboard: every player's filled scores and running
total are always on screen.

- **Header row:** an empty first cell, then **"P1" … "P4"**. The active player's
  header is bold and its whole column carries a faint highlight tint.
- **First column:** the category label (abbreviated — see below), left-aligned.
- **Score cells:** centred. Three states:

  | Cell state | When | Shows | Tappable |
  |---|---|---|---|
  | Empty | category not yet scored by that player | blank | no |
  | Preview | that player is active, has rolled, category still open | preview score (incl. `0`), **muted/grey** | **yes → commits, passes turn** |
  | Locked | category already scored by that player | the score, normal colour | no |

  Only the **active player's column** ever has Preview cells; every other cell is
  Empty or Locked and read-only.
- **Totals row:** first cell **"Total"**, then each player's grand total; the
  active player's total is in the highlighted column.

**Abbreviated category labels** (to fit up to 4 columns on a phone without
horizontal scrolling): Ones, Twos, Threes, Fours, Fives, Sixes, **1 pair**,
**2 pairs**, **3 of a kind**, **4 of a kind**, Full house, **Sm straight**,
**Lg straight**, Dice Zee, Chance. (The Statistics screen still uses the full
names — "One pair", "Small straight", etc.)

**Redesign opportunities:** the current version is a bare Material `Table` — thin
tint for the active column, text-colour-only cell states, no grouping between the
six number categories and the nine combinations, no dice-glyph hints for what
"Full house" / straights / pairs mean, no affordance that a preview cell is a
button. With 4 players the columns are ~50pt wide. This table is where the game
is read and played — it deserves the most design attention.

---

### 4.4 "Game over" dialog

A modal `AlertDialog`, not dismissible by tapping outside.

- Title: **"Game over"**.
- First line: **"Player N wins!"**, or **"It's a tie!"** if the top total is
  shared.
- Then the **final standings**: every player as **"Player N: <total>"**, sorted
  highest first.
- One action button: **"Back to menu"** (returns to the Main Menu).

**Gaps:** no "Play again" / "Rematch" action (you must go to the menu and pick a
player count again); no per-category breakdown or highlights ("Player 2 got a
Dice Zee!"); no celebration/animation for the winner. This is a good candidate to
become a full results *screen* rather than a cramped dialog.

---

### 4.5 Statistics (`StatisticsScreen`)

App bar: title **"Statistics"**, back arrow.

- While loading: a centered spinner.
- If no games have been finished yet: centered text **"No games played yet."**
  (This is the only real empty state in the app — worth designing properly.)
- Otherwise a scrolling list:
  - **"Games played: N"**
  - **"Average score: X.X"** — the mean final total across *every player of every
    recorded game*, one decimal.
  - Divider.
  - Section heading **"Best ever by category"**.
  - 15 rows (`ListTile`, dense): category label on the left, the **highest score
    ever committed to that category in any game** on the right. `0` if it has
    never been scored.

That's all the statistics — deliberately aggregate-only. No per-player records,
no recent-games list, no charts, no dates.

**Redesign opportunities:** currently a flat text list. The two headline numbers
(games played, average) could be "stat cards"; "best by category" could be a
compact grid with dice glyphs; the empty state needs art + a "Start a game" CTA.

---

## 5. Component state catalogue (for a component library)

**Die** (5 per game):
- placeholder (pre-roll), value 1–6 shown as pips
- not held / held (held = highlighted + pin marker)
- interactive (can toggle hold) vs locked (before first roll, or after 3rd roll,
  or when match over)
- rolling (brief transform animation on un-held dice)

**Roll button:** enabled / disabled.

**Score table** (see 4.3): per-player columns with an active-column highlight;
score cells in one of three states — empty / preview (tappable, active column
only) / locked; a totals row.

**Turn banner:** shows current seat; changes on every commit.

**Screens with an empty/loading state:** Statistics (loading spinner, "no games"
empty state).

**Seats:** always referred to as **"Player 1" … "Player 4"** (**"P1"–"P4"** in the
table header) — no names, no avatars, no colours currently. Introducing a per-seat
colour/identity is a reasonable redesign move and would touch: the score table's
header + active column, the turn banner, the game-over standings, and potentially
the dice while that player is active.

---

## 6. Full text inventory (every user-visible string today)

- App / Game Screen app bar title: **"Dice Zee"**
- Menu: **"Dice Zee"**, **"New game"**, **"2 Players"**, **"3 Players"**,
  **"4 Players"**, **"Statistics"**
- Game Screen: **"Player N's turn"**, **"Round N / 15"**, **"Rolls left: M"**,
  **"Roll"**
- Score table headers: **"P1" … "P4"**; totals row label **"Total"**
- Score table category labels (abbreviated): **Ones, Twos, Threes, Fours, Fives,
  Sixes, 1 pair, 2 pairs, 3 of a kind, 4 of a kind, Full house, Sm straight,
  Lg straight, Dice Zee, Chance**
- Game over dialog: **"Game over"**, **"Player N wins!"**, **"It's a tie!"**,
  **"Player N: <total>"**, **"Back to menu"**
- Statistics: **"Statistics"**, **"No games played yet."**, **"Games played: N"**,
  **"Average score: X.X"**, **"Best ever by category"**, then the **full**
  category labels: **Ones … Sixes, One pair, Two pairs, Three of a kind,
  Four of a kind, Full house, Small straight, Large straight, Dice Zee, Chance**

---

## 7. Out of scope (don't design these — they don't exist and aren't planned)

- Online / multi-device play, lobbies, matchmaking
- Accounts, profiles, cloud sync
- A bot / AI / single-player mode
- In-app purchases, ads, monetisation
- Settings screen, sound toggles, localisation
- Achievements, unlocks, cosmetics store
- Landscape / tablet-specific layouts
