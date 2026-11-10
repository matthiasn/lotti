# Daily OS day page redesign

**Date:** 2026-11-10
**Status:** Proposed — awaiting the user's review of this plan
**Design reference:** the "Combined" direction in the designs page delivered on
2026-11-09 (`daily_os_designs.html`, scratchpad), which draws on three
explorations — *Ledger* (header + list card), *Blocks* (timeline) and
*Briefing* (one agent sentence carrying the capacity bar).

## Problem

The day page (`/calendar`, `DayPage`) works, but reads as a collection of
competent parts rather than one designed surface. Rated against a
professional, well-funded product it sits around 60/100. The specific faults
the mocks fix:

| Fault today | Where it lives |
|---|---|
| Header, toggle, nudge chip, stat card, agenda cards and footer all carry similar visual weight — the eye has no path | `DayHeader`, `_StatStrip`, `AgendaCard`, `_DayReviewFooter` |
| Boxed cards inside a boxed page: every agenda item is its own bordered `level02` card with a 4 px stripe, an ordinal and a `LinkBadge` | `agenda_card.dart` |
| The stat strip is an instrument panel — an 86 px donut, headline, pressure line and a per-category ledger — before the user has seen a single item | `agenda_view.dart` `_StatStrip`, `capacity_donut.dart` |
| Colour is not reserved: category stripes, info-blue link badges, teal legend, violet nudge chip and green checks all compete on one screen | `agenda_card.dart`, `link_badge.dart`, `knowledge_nudge.dart` |
| The footer stacks chips + composer under the list rather than closing the page | `day_page_plan_review_strip_part.dart`, `day_composer_bar.dart` |
| The date is a navigation control (chevron · label · chevron), not the page's title | `daily_os_date_strip.dart` as the header title |

## Goal

The day page reads as one surface with one hierarchy, in Lotti's own palette,
and scores **≥ 88/100** on the design-review panel (experts first, then
personas), at phone and desktop widths, in dark and light mode — with no
regression in what the page can do.

## What does not change

- All behaviour: day navigation, the Agenda / Day / Activity projections and
  their memory in `dailyOsNextPlanViewProvider`, inline rename, block edit
  modal, arrange mode, overlap layout, folding, the companion's spoken
  briefing, quick refinements → Refine, commit / undo, shutdown, the knowledge
  nudge, the onboarding spotlight, the setup nudge.
- All data: `DraftPlan`, `AgendaItem`, `TimeBlock`, `categoryTotalsFor`,
  `DayBriefing`, `liveTaskMetadataProvider`.
- The docked desktop day column (`DayViewSidePanel`) keeps using `DayTimeline`
  and the compact date strip; it inherits the timeline changes and nothing
  else.
- The planning modal (Capture → Reconcile → Drafting, Refine, Shutdown) is out
  of scope.

## The design, element by element

Every value below is a design-system token. Nothing is hard-coded; the
token-value ratchet (`make token_check`) must not rise in any touched file.

### 1. Header — the date is the title

```text
Today · Sunday                      ← calmEyebrowStyle, text.lowEmphasis
November 9                 [🙂]     ← heading2 (25/32 Bold), companion bust
S  M  T  W  T  F  S                 ← 7-day strip, today = teal@16% pill + teal dot
[ Agenda | Day | Activity ]         ← DsSegmentedToggle, unchanged
```

- **Overline** says the relation to today (*Today*, *Tomorrow*, *Yesterday*,
  else the weekday) and the weekday; **title** is the month + day in
  `typography.styles.heading.heading2`. On a day in another year the overline
  carries the year. Both via `DateFormat` with the locale, tabular figures so
  stepping days does not reflow.
- **The 7-day strip replaces the chevron row as the primary day control.**
  Seven cells, Monday-first per `MaterialLocalizations.firstDayOfWeekIndex`,
  weekday initial above the day number; the selected day is a
  `surface.selected` (teal@16 %) pill with `interactive.enabled` text; today
  (when not selected) carries a `step1` teal dot under its number. A tap
  selects; horizontal swipe on the strip pages a week. Days with a plan show
  nothing extra — the strip is navigation, not a heat-map.
- **Prev/next chevrons and the date picker survive**: tapping the title opens
  `showDailyOsDayPicker`; long-press returns to today. The chevrons move to
  the ends of the week strip on desktop width only (they are not needed on a
  phone where the strip swipes). `DailyOsDateStrip` itself is unchanged — the
  docked column still uses its `compact` form.
- **Actions** keep their slot at the end of the title row: companion bust
  (`DayBriefingCompanion`), `DayAgentStatusChip`,
  `ProcessingCategoryFilterButton`, `AgentSurfaceMenuButton`. The status chip
  is demoted to icon-only while idle; its label shows only in the
  *working* / *attention* states.
- `_MeasuredDayHeader` keeps its row-packing contract (title never yields to
  the actions; the toggle joins the title row only when it fits). The week
  strip is a new third `start` item that always takes its own row.

**Files:** `day_page_header.dart` (new `_DayMasthead` replacing
`_DefaultDayHeaderTitle`; the `dateStrip` slot becomes a `selected`/`onSelect`
pair), new `ui/widgets/day_week_strip.dart`, `daily_os_next_root.dart`
(stop injecting `_DateStrip` into the title; pass the selection callbacks
instead).

### 2. Briefing strip — the agent's one sentence carries the capacity

Replaces `_StatStrip` + `CapacityDonut` on the Agenda tab, and is shown on
the Day tab too (same header, same strip, only the body differs).

```text
┌ aiCard.background · aiCard.border · radii.l ──────────────────┐
│ ✦ Five blocks today; Deep work on the migration is next at 10. │
│ ▓▓▓▓▓▓▓▓▓▓▓▓▓▓░░░░░░░░░░ (4 px, segmented by category)          │
│ 5h 20m planned                                   2h 40m free    │
└────────────────────────────────────────────────────────────────┘
```

- The sentence is **`composeDayBriefing`'s first two clauses** (count + next),
  not the spoken paragraph — `DayBriefing.of` already computes both. This is
  the same source the companion speaks, so the strip and her voice never
  disagree. The sparkle is `LottiIcons.aiSpark` in `aiCard.accent`; the text
  is `body.bodySmall` in `text.highEmphasis`. Tapping the strip does what
  tapping the companion does (speak / stop) when she is enabled; otherwise it
  is inert.
- The **capacity bar** is a `step1`-tall `ClipRRect(radii.xs)` row of
  `Expanded` segments, one per `categoryTotalsFor` entry in category colour,
  over a `decorative.level01` track; the remainder is the track. Over
  capacity: the bar fills fully and the trailing caption turns
  `alert.error.ink` and reads *N over* — the same honesty rule `CapacityDonut`
  enforces today, in one line instead of a ring.
- The two captions are `others.caption` in `text.lowEmphasis` with
  `numericBadgeFontFeatures`.
- **No plan:** the strip keeps the violet surface and says
  `dailyOsNextBriefingNoPlan` (her existing invitation); the bar shows tracked
  minutes in `interactive.enabled` over the track; the captions read *Nh
  tracked* / *N done* — what `_TrackedLegend` says today.
- `CapacityDonut` and `_StatStrip` / `_CategoryMix` / `_CategoryLegend` /
  `_TrackedLegend` are deleted with their tests; `categoryTotalsFor` moves to
  `logic/` (it is pure) and keeps its tests. The per-category minutes the
  legend listed are not lost: they become the bar's segment tooltips /
  semantics labels.

**Files:** new `ui/widgets/day_briefing_strip.dart` (+ test), new
`ui/widgets/day_capacity_bar.dart` (+ test), `agenda_view.dart` (drop the
strip), `day_page.dart` (mount the strip under the header on all three
views), delete `capacity_donut.dart` + test, move `categoryTotalsFor` to
`logic/day_category_totals.dart`.

### 3. Agenda tab — one list card, rows with a time column

Replaces the stack of bordered `AgendaCard`s.

```text
┌ background.level02 · radii.l ───────────────────────────────────┐
│ 09:00  ● Review PR queue                              45m      │  done: 50% opacity, strikethrough, ✓ success
│ ─────────────────────────────── decorative.level01 hairline ── │
│▌10:00  ● Deep work on the migration                   2h       │  active: 2px interactive.enabled left edge
│        ✦ Your best hours; nothing else until noon.             │  one-liner: aiCard.accent, caption
│        Migration project · 1 of 3                              │  meta: caption, lowEmphasis
│ ─────────────────────────────────────────────────────────────── │
│ 13:00  ● Gym                                          1h       │
└─────────────────────────────────────────────────────────────────┘
```

- **Row anatomy**, left to right: time column (`others.caption`,
  `text.lowEmphasis`, tabular, fixed `step10` wide — the block's start, or
  `—` for an item with no block), category dot (`step2` circle), title
  (`subtitle.subtitle2` for the in-progress row, `body.bodySmall` otherwise,
  `text.highEmphasis`), right-aligned estimate (`others.caption`, tabular,
  `text.mediumEmphasis`). Minimum row height `TapTargets.minimum`; vertical
  padding `step3`; horizontal `cardPadding`.
- **Second line** only when there is something to say: the `whyReason`
  (sparkle + `aiCard.accent` caption, one line, ellipsis) and/or the meta
  line (project / linked task name, progress as *n of m* when the item has
  sub-progress).
- **States:** `inProgress` → a `step1`-wide `interactive.enabled`
  `ColoredBox` down the row's left edge, title in `subtitle2`, progress bar
  (`step1` tall, category colour over `decorative.level01`) under the meta
  line when `item.progress` is between 0 and 1. `done` → the whole row at
  `decorative.level03`-equivalent opacity (`Opacity(0.5)`), title with
  `TextDecoration.lineThrough`, `LottiIcons.confirm` in `alert.success` in
  place of the estimate. `dropped` items are not listed (as today).
- **Task-linked vs standalone:** the info-blue `LinkBadge` goes. A task-linked
  row shows `LottiIcons.chevronRight` in `text.lowEmphasis` at the far right
  (it opens the task); a standalone row shows the `EditableTitle` pencil on
  hover / long-press as today. The absence of a chevron is the marker, which
  matches the "standalone is the unmarked default" rule already in the
  knowledge concept.
- **Cover art** (`CoverArtThumbnail`) is dropped from the row — it was a
  32 px tile beside the ordinal and fought the category dot. It stays on the
  task page and in the companion's preview cards.
- **The ordinal** (1, 2, 3…) is dropped; the time column orders the list.
- **Empty state** (`_AgendaEmptyState`) keeps its dashed card and
  `TimeSpentCard`, restyled only by the shared tokens.
- Rows are `DesignSystemListItem`-shaped but not that widget: it has no time
  column and its leading slot is a 40 px icon well. A new `DayAgendaRow`
  owns the layout; the card is the same `_FrontRowsCard` construction the
  companion's lists use (`level02`, `radii.l`, `DesignSystemDivider` between
  rows) — lift that private widget into
  `design_system/components/cards/ds_rows_card.dart` so both features share
  it instead of copying it.

**Files:** rewrite `agenda_card.dart` → `day_agenda_row.dart` (+ test),
`agenda_view.dart` (list card + `findChildIndexCallback`, keyed rows),
new `design_system/components/cards/ds_rows_card.dart` (+ test),
`front_task_list.dart` (use it), delete `link_badge.dart` + test.

### 4. Day tab — the timeline, tuned

`DayTimeline` keeps its machinery (folding, overlap, arrange, hour rail,
energy band, now line, planned/recorded lanes). The changes are paint only:

- **Planned blocks**: 5 % tint fill + 1 px dashed outline at
  `kTimelinePlannedAccentAlpha` — this is already the contract in
  `category_color.dart`; verify every planned block honours it and that the
  `DsDashedBorder` dash length is `step1`/`step1`.
- **Tracked blocks**: filled at `timelineBlockTintAlpha`, `step1` solid
  category stripe (already the construction after the overlap work).
- **Now line**: `interactive.enabled`, 1 px, with the time in a teal pill
  (`NowLine` already does this; confirm the pill uses `radii.badgesPills` and
  `text.onInteractiveAlert`).
- **Hour rail** labels: `others.caption` in `decorative.level03`-alpha white
  (`text.lowEmphasis` is too strong beside the blocks); hour lines
  `decorative.level01`.
- **Energy band**: keep, at `decorative.level01` alpha, no label.
- **Toolbar** (`_TimelineToolbar`): Arrange and the lane-format toggle become
  icon buttons at the end of the briefing strip's row rather than a separate
  toolbar row, so the Day tab has no extra chrome the Agenda tab lacks. The
  coaching line ("Swipe for plan") stays where it is.
- **Block title** `body.bodySmall`; the task-link glyph goes (same rule as the
  agenda: a chevron on tap, no badge).

**Files:** `day_timeline_widgets.dart` (`_TimelineToolbar`, `_SharedHourRail`,
`_GridLines`), `day_timeline_block.dart` (`DayBlock` paint, drop the link
icon), `day_timeline.dart` (toolbar slot), `category_color.dart` (unchanged
unless the audit finds a drift).

### 5. Activity tab

Not mocked; must fit the same frame. `DayActivityView`'s `_ActivityCard`s
move onto the same `DsRowsCard` list (one row per entry: time column,
transcript excerpt as title, state glyph, *Use* as a trailing action) so the
three tabs share one body shape. Error / empty states keep their copy.

**Files:** `day_activity_view.dart` (+ test).

### 6. Footer — the glass strip closes the page

`DayComposerBar` already sits on `DesignSystemGlassStrip`. Changes:

- The quick-refinement chips (`_QuickRefinementChips`) are
  `DesignSystemChip` outlined at `radii.smallChips`, `decorative.level02`
  border, `others.caption` label — same widget, smaller size variant
  (`DesignSystemChipSize.compact`) so they read as suggestions, not buttons.
- The composer field is a `radii.badgesPills` pill on `level02`; the mic is
  `interactive.enabled` (it is the one action colour).
- The stage action (`_DayStageAction` — *Looks good* / *Wrap up*) is the one
  filled `DesignSystemButton` on the page: `interactive.enabled` on
  `text.onInteractiveAlert`, `radii.badgesPills`, height `ControlSizes`
  default. It sits in `DesignSystemChatInput.leading` as today.
- The strip's top hairline is `decorative.level01`; the scrim keeps the
  existing blur.
- `_NoPlanFooter` keeps its CTA and setup states, restyled through the same
  tokens.

**Files:** `day_page_plan_review_strip_part.dart`, `day_composer_bar.dart`
(token audit only), `design_system_glass_strip.dart` (only if the hairline is
not already `decorative.level01`).

### 7. Nudges

- `KnowledgeNudge` keeps its violet sparkle (agent content) but drops its
  own `surface.enabled` pill: it becomes a one-line caption row under the
  briefing strip, so the page has one violet surface, not two.
- `_DailyOsSetupNudge` (settings attention) uses the `alert.warning` ink on a
  plain row in the same slot. Both render nothing when there is nothing to
  say, as today.

**Files:** `knowledge_nudge.dart` (+ test), `day_page.dart`.

## Colour discipline (the rule the whole page follows)

| Colour | Allowed uses on this page | Nothing else |
|---|---|---|
| `interactive.enabled` (teal) | selected day, selected tab, now line, the in-progress row edge, the mic, the one primary button | not on category data, not on links |
| `aiCard.accent` / `aiCard.background` (violet) | the briefing strip, the one-liner `whyReason`, the knowledge nudge sparkle | not on buttons, not on chrome |
| category hue | the `step2` dot, the capacity bar segment, the block fill / stripe / dashed outline | not on text, not as a card stripe |
| `alert.success` | the done check | not on progress bars |
| `alert.error` / `alert.warning` | over-capacity caption, setup nudge | — |
| everything else | `text.*` emphasis levels and `decorative.*` hairlines | — |

A test in `test/features/daily_os_next/ui/pages/day_page_palette_test.dart`
walks the rendered tree of the screenshot scenarios and asserts that no
`Container`/`DecoratedBox`/`Icon` colour outside this table appears (the
category hues are whitelisted from the fixture). This is the regression guard
for "random blue".

## Light mode

Every token above has a light value; the one visual risk is the briefing
strip (`aiCard.background` light = `#F0EEFF`-class, border `#5A4BD1@14%`)
reading as a pastel box on `#F1F4F3`. The screenshot scenarios run both
brightnesses; if the light strip fails the panel, the fallback is
`dsCardSurface` with the violet border only — decided from the capture, not
in advance.

## Measuring it

1. **Baseline first.** Run the existing
   `test/features/daily_os_next/ui/pages/day_page_screenshots_test.dart`
   (`LOTTI_SCREENSHOT_DIR=…`) at phone and desktop, dark and light, for:
   Agenda with a plan, Day with a plan, Agenda with no plan, Activity. Store
   as `before/` per the screenshots convention. These are the captures that
   cannot be reconstructed once the change is in.
2. **Score the baseline** with the `design-review-panel` skill (experts
   panel) — this replaces the guessed "60".
3. Implement phase by phase; after each phase regenerate the **same** shots
   and re-score. The target is **experts ≥ 8.8 average on every shot**, then
   the personas panel once.
4. Publish the final before/after pairs for the PR body.

## Phasing

Each phase is screenshot-able on its own and keeps the page shippable.

| Phase | Scope | Deletes | Risk |
|---|---|---|---|
| **0** | Baseline captures + panel score; `DsRowsCard` lifted into the design system; `categoryTotalsFor` moved to `logic/` | — | none |
| **1** | Header masthead + week strip (§1), nudges (§7) | `_DefaultDayHeaderTitle`, root's `_DateStrip` injection | medium — `_MeasuredDayHeader` layout tests |
| **2** | Briefing strip + capacity bar (§2) on all tabs | `CapacityDonut`, `_StatStrip` and its legends | low |
| **3** | Agenda rows (§3) | `AgendaCard`, `LinkBadge` | medium — rename, tap, progress, done, live-metadata tests move to `DayAgendaRow` |
| **4** | Footer tokens (§6) | — | low |
| **5** | Timeline paint + toolbar relocation (§4) | the block's link glyph | medium — toolbar relocation touches `DayViewSidePanel`'s `toolbarLeading` slot |
| **6** | Activity rows (§5) | `_ActivityCard` | low |
| **7** | Palette test, light-mode decision, panel to target, docs + l10n + changelog | — | — |

Phases 1–3 are one PR (they are the look); 4–6 may follow as a second PR if
the first is large. One branch per phase per the stacked-branch convention,
one PR from the head.

## Localization

New labels, in every catalog: the overline words (*Today*, *Tomorrow*,
*Yesterday* already exist as `dailyOs…`? — audit first), the capacity
captions (*{n} planned*, *{n} free*, *{n} over*, *{n} tracked*), the week
strip's semantics (*Select {date}*), the Activity row's *Use* if not already
present. Sentence case throughout — `daily_os_sentence_case_test.dart`
enforces it.

## Documentation

- `knowledge/features/daily_os_next/ui-surfaces.md`: rewrite "Day navigation
  and view memory" for the week strip, replace "The capacity ring" with "The
  briefing strip", update "Task-linked versus standalone" (chevron, not
  badge), update the footer paragraph, bump `sources[].last_modified`.
- `lib/features/daily_os_next/README.md`: one line under "Opens on the
  calendar" for the week strip and the briefing strip.
- `changelog.d/2026-11-10-daily-os-day-page-redesign.md`: `### Changed`, as
  the user sees it.

## Open questions

1. **Week strip vs chevrons on desktop.** The mock shows the strip only. The
   plan keeps chevrons at the strip's ends on desktop width because the
   sidebar can leave the pane at 460 px where swiping is awkward with a
   mouse. Confirm, or drop them and rely on the picker.
2. **Category hue for the fixture.** The mock's *Work* used the indigo persona
   hue, which reads cool. Categories are user-chosen in the app; the
   screenshot fixture should use the penguin world's real category colours so
   the panel scores what users see.
3. **Per-category minutes.** The legend's numbers move to bar-segment
   tooltips / semantics. If that is too hidden, a tap on the bar can expand
   one caption row listing them — not in the mock, so not in the first pass.
4. **The ordinal.** Dropped in favour of the time column. An item with no
   linked block has no time; it sorts last with `—`. If the agent commonly
   produces such items, revisit.
