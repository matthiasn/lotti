# Habits — Streak Cards

A redesign of the Lotti Habits tab, picking the "Streak Cards" direction
(list-first hierarchy with the original stacked-area chart restored at the top).

## What's in this bundle

- `Habits - Streak Cards.html` — the prototype. Open in any browser. One file,
  no external dependencies, works offline.

## What you're looking at

A pannable design canvas showing two artboards:

1. **Desktop** (1280×800) — Lotti window chrome with the sidebar; Habits tab content.
2. **Mobile** (390×844) — iOS frame with the bottom tab bar; same content adapted.

Both are fully interactive. State is shared — log a habit in one and the other
updates immediately.

## The design

### Top of page (same on desktop + mobile)

- Page title `Habits` with today's date.
- Segmented filter pills: **due · later · done · all** (one selectable).
- Density picker: **14 / 30 / 40 / 90 days** — controls the 40-day strip width.
- **Daily stacked-area chart** (14-day window). Layered: success (teal,
  front) → skip (amber, middle) → fail (red, back). Y-axis labels, a dashed 80%
  target line, and date labels below — matching the original Lotti chart.
- Summary line: `N of M habits completed today · X failed · Y skipped`.

### Habit cards

Each habit renders as a card with:

- Category-tinted icon tile (mic, eye, run, focus, book, leaf, moon, drop).
- Habit name + star (for favorites).
- Inline meta: category, current streak (with flame), `N/7 last week`.
- Three always-visible quick-action buttons on the right:
  - **Fail** (red `×`) — outline button
  - **Skip** (amber `»`) — outline button
  - **Success** (teal `✓`) — filled primary button
- 40-day strip across the bottom of the card, with explicit
  success/fail/skip/empty colors.

### Completion dialog

Tapping a card body opens the full completion dialog (rather than logging
directly):

- Centered modal on desktop, bottom sheet on mobile.
- Last-7-days mini strip at the top.
- Completed-at timestamp (editable, `YYYY-MM-DD HH:MM`).
- Value field with `+ / −` steppers (only for measurable habits — Audio Journal,
  Morning Run, Deep work, Read 20 pages, Water 2L).
- Comment textarea + a "voice note" shortcut (a `mic` chip that flips to
  `recording` state for parity with Lotti's audio journal pattern).
- Action bar: Fail · Skip on the left, **Success** as the primary teal button
  on the right.

### Tweaks

In the toolbar, toggle **Tweaks** to reveal:

- **Theme** — Dark / Light (the design system supports both; dark is primary).
- **40-day density** — 14, 30, 40 (default), 90.

## Design-system grounding

Everything pulls from the Lotti design system:

| Surface | Token |
|---|---|
| Page background | `--bg-01` (#181818 dark) |
| Card surface | `--bg-02` (#222222 dark) |
| Primary interactive (Success, links) | `--interactive` (Lotti teal #5ED4B7 dark) |
| Error / Fail | `--error` (#D65E5C dark) |
| Warning / Skip | `--warning` (#FBA336 dark) |
| Text — high / med / low | `--fg-high / --fg-med / --fg-low` |
| Radii — cards / chips | `--r-l` (16px) / `--r-pill` |
| Type | Inter (display + body), Inconsolata (mono) |
| Shadows | `--shadow-1 … --shadow-overlay`, never colored |

## Implementation notes for engineering

- **Data shape** — each habit carries `{ id, name, category, catColor, icon,
  desc, measurable, unit?, target?, starred, history: Entry[] }` and each entry
  is `{ date: Date, status: 'success'|'fail'|'skip'|'empty', value?: number,
  comment?: string }`. 90 days of history are generated; the 40-day strip
  takes `history.slice(-days)`.
- **Status colors** — `cell-success`, `cell-fail`, `cell-skip`, `cell-empty`
  classes are defined once in the page stylesheet. Replace with your Flutter
  equivalents during port.
- **Dialog** — `<CompletionDialog mode="centered|sheet">` is responsive-by-prop,
  not by media query. Decide which mode based on the host platform (Flutter's
  `Platform.isMobile` or layout breakpoint).
- **Density** — drives a single number (`days`) consumed by the `DayStrip`
  component. The cells flex to fill available width, so changing density is a
  no-op for layout.

## Things deliberately left alone

- The functional pieces — chart, filters, summary line, habit list, completion
  dialog with Fail / Skip / Success — are all present and unchanged in purpose.
- Calendar / search icons in the header are placeholders; wire to existing
  routes when porting.

## Variants explored (not in this bundle)

Three other card treatments were explored before settling on this one:
**B · Strip-as-rail**, **C · Compact (one-line rows)**, **D · Score-forward
(big streak numeral)**. Happy to revisit any of them if a constraint changes
(e.g. you start tracking 20+ habits, which would push toward C).
