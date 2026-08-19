---
type: Feature Module
title: Component contracts
description: The repeating patterns that are contract rather than coincidence — token-first sizing, one field surface, shell-aware spacing, and accessibility enforced at construction.
resource: ../../../lib/features/design_system/components
tags: [design-system, components, accessibility, layout]
status: stable
generated: { by: codex/gpt-5, at: 2026-08-05T20:23:15Z }
stale_after: 2027-02-08
sources:
  - id: components
    resource: ../../../lib/features/design_system/components
    title: Design-system components
    last_modified: 2026-08-16
  - id: contact-row
    resource: ../../../lib/features/design_system/components/navigation/design_system_contact_row.dart
    title: DesignSystemContactRow — the support footer both navigation surfaces close with
    last_modified: 2026-08-05
  - id: navbar
    resource: ../../../lib/widgets/nav_bar/design_system_bottom_navigation_bar.dart
    title: Bottom navigation shell
    last_modified: 2026-06-12
---

# Token-first sizing and styling

Representative components — `DesignSystemButton`, `DesignSystemCheckbox`,
`DesignSystemSplitButton` — derive padding, radii, icon size and text style from
`context.designTokens`, **not local magic numbers**. Glyph and stroke
dimensions come from the hand-authored sizing set (`ControlSizes`,
`TapTargets`, `IconSizes`, `BorderWidths` — see
[tokens and theming](tokens-and-theming.md)), never from `spacing.stepN`: a
spacing step that happens to equal 24 retunes every icon the moment the gap
scale moves.

`DesignSystemButton` sizes run `dense` → `small` → `medium` → `large` → `jumbo`.
**`dense` is the caption tier**: its label is
`typography.styles.others.caption`, so it reads as a button through its glyph, ink
and hover fill rather than by out-weighing the text around it. Use it for actions
that live inside metadata rows and settings zones, where a `small` button would
share a type tier with the surface's primary action.

A button pays its own content inset, which puts its *label* — not its box — off
the column when it sits first on a leading edge. `alignsLabelToLeadingEdge`
cancels exactly that inset, direction-aware, so a button can start a shared
column without a call site open-coding a `Transform`.

`DsPill` carries the corner-radius convention through its `shape` parameter:
the default `DsPillShape.pill` (fully-rounded, `radii.badgesPills`) is the
*interactive* grammar — filters, levers, pickers — while `DsPillShape.tag`
(`radii.xs`, 4) marks *informational* read-outs, so a fact can never be
mistaken for a button. The task-detail metadata summary is the reference
consumer of the tag shape.

`DesignSystemChip` is the canonical interactive filter token. Its `selected`
flag owns both the activated surface and selected semantics; feature code does
not repaint selected chips with local status colours. A count or status that
travels with the filter uses the chip's trailing slot with a `DsPill`. When the
chip's semantic label already includes that value, the pill is excluded from
semantics so a screen reader announces the count once.

Visible control size and interaction size are separate contracts.
`MaterialTapTargetSize.padded` gives `DesignSystemButton` a 48dp interaction
shell while leaving its token-derived pill unchanged and centred inside it.
Adoption is deliberately opt-in: use it only where the parent already owns that
height, so accessibility does not silently make a compact list or action bar
airier. The default remains `shrinkWrap`.

`DesignSystemModalActionBar` is an actual-fit footer in **both** layouts: it
measures the rendered actions and keeps one row only while they genuinely fit,
rather than comparing the available width against a breakpoint. A width
threshold cannot see a long translation, so the German and Romanian catalogs
could satisfy it and still overflow the row — and with `dominantPrimary`, whose
primary took whatever width was left, that left the confirm action at zero
width.

The two layouts differ only in how the primary is sized. `compactPrimary` keeps
the primary at its intrinsic width, so spare width opens up between the groups.
`dominantPrimary` gives the primary the width the secondaries leave, separated
by the wider `spacing.step5` gutter, and stretches it full width once the groups
wrap. Either way the secondary group stays on the leading edge, the primary on
the trailing edge, and each action is bounded by the footer width, so an
unusually long translation ellipsizes instead of producing render overflow.

The measurement is a dry layout at unbounded width, not `getMaxIntrinsicWidth`.
Two things make the intrinsic query wrong here: a `fullWidth` primary centres
its content, so laying it out against loose constraints reports the width it was
offered rather than the width it needs; and `RenderWrap` omits its own `spacing`
from its intrinsic width, which under-measures a multi-action secondary group
and lets the primary encroach on the gutter.

The compact `DesignSystemCheckbox` is a 24dp control with no outer inset. A
feature that needs a mobile-sized option target should not pad seven independent
checkboxes into a loose stack; it should use
`DesignSystemSelectionRow.multiSelect`. That component owns the full-row target,
keeps labels on the left and checkboxes on the right, and normally applies one
contiguous selected band per option. Checkbox-first lists can set
`showSelectedBackground: false` when the checkmark is the deliberate sole state
indicator; checked semantics and the full-row action remain unchanged.

The same rule applies to structural and operational surfaces:
`DesignSystemProgressBar` owns determinate progress and its visible value,
`DesignSystemSectionCard` owns grouped page content, and
`DesignSystemTextInput` owns editable settings fields. The sync maintenance
progress views, statistics page, and this-device profile are canonical
adopters: feature code supplies state and copy, while these components supply
the visual and semantic grammar. A progress header gives its label and trailing
value bounded shares of a narrow row; either may ellipsize visually, while the
bar's semantics retain the complete label and value. `DesignSystemListItem`
remains an interactive row; rendering a read-only value with no callback puts
it into its disabled treatment, so static metadata should use token-styled text
instead. Its leading and trailing glyph slots and its text block share **one**
vertical axis — all three centre on the row — so a single-line row beside a
taller reserved rail keeps its label level with the glyphs flanking it, and a
two-line row anchors both rails to the whole text block rather than to the
title's first line.

**`DesignSystemSectionCard` fixes its own fill** to `background.level02`, which
is what makes it a *surface* rather than a container. A card whose fill carries
meaning therefore cannot adopt it. `matrix_stats/metrics_grid.dart` is the
worked example: each `MetricTile` tints itself by outcome — conflicts, drops,
routine throughput — and moving it onto the section card would flatten that
three-tone scale to one neutral. It stays a token-styled `Container`, taking
`radii.m` and `decorative.level02` by hand. Reach for the section card when the
grouping is structural; keep a container when the fill is information. See
[design tokens and theming](tokens-and-theming.md) for why the tint could not
be expressed as a `colorScheme.*Container` either.

`DesignSystemToast` clips its background, countdown bar, and leading tone
gradient to one token-derived rounded outline, then paints the border in the
foreground. The order is part of the component contract: both tone layers reach
the interior edge of the curve, but neither can overpaint the outline and create
a doubled or discontinuous corner.

`DesignSystemContextMenu` follows the same single-outline rule. An optional
quiet header can name the concrete date or object being acted on, item identity
and selected semantics travel with each row, and `edgeToEdge` removes the
ordinary outer row padding. The hover ink is painted by an inner Material and
then clipped by the menu outline, so the final action reaches the rounded bottom
edge instead of leaving an unhighlighted strip above the border.

`DesignSystemFloatingActionButton` is circular and icon-only by default and
takes its `semanticLabel` for assistive technology. Passing a `label` extends
it into a worded pill: same height, same token background and radius, growing
only sideways, with the visible word excluded from semantics so the action is
announced once. Word it where the surface creates one specific kind of thing
and the bare `+` would not say which — the tasks list is the adopter.

## Beside the button tier: `DesignSystemIconAction`

A glyph-only control for card headers and panel corners — the sync statistics
and backfill refresh controls are the reference uses. It carries no label and
no variant, so it cannot read as a surface's primary action; where a
caption-tier *labelled* row is wanted, use `DesignSystemInlineAction` below
instead.

**Its busy state is the reason it is a component.** The spinner it swaps in is
the same dimension as the glyph it replaces, so the control does not resize
under the pointer that just pressed it. `isBusy` also makes it **inert**, the
way `DesignSystemButton` treats `isLoading`: the only action a busy refresh
button could re-trigger is the refresh already in flight, so a caller must not
have to remember to null `onPressed` as well to avoid a duplicate submit. It was promoted out of
`backfill_settings_page.dart`, where it sat as a private-by-convention
`IconActionButton` — a design-system control declared in a feature page. The
second surface that needed it, `matrix_stats/diagnostics_panel.dart`, had
reached for a Material `IconButton` instead, so the two refresh controls on
neighbouring sync screens had drifted to different ergonomics. That divergence
is what the promotion fixes, not an import graph: `backfill_settings_stats.dart`
still imports the page, for `SurfaceCard`.

**A glyph-only control cannot let its visual size be its target.** A labelled
button borrows hit area from its text; this one has none, so the pointer target
is pinned to `TapTargets.minimum` with the glyph centred inside it — the same
`ConstrainedBox`/`Center` pair `DesignSystemButton` uses for
`MaterialTapTargetSize.padded`, except here it is not optional. Its predecessor
in the diagnostics panel was a Material `IconButton`, which supplied that floor
for free; a compact replacement that did not would have been a silent
regression to a 16dp target.

That floor is a **layout** commitment, not just a hit-test one: the control
occupies 48×48, where the `IconActionButton` it replaces occupied 24×24
(`IconSizes.s` plus `spacing.step2` a side). On the sync statistics card the
header row has no other child that tall, so the row grows to 48 and the card
with it. This is the one deliberate exception to the guidance on
`TapTargets.minimum` in `sizing_tokens.dart`, which otherwise asks components to
take the floor only where the containing layout already owns a 48-high slot —
a glyph-only control has no label to borrow from, so for it there is no compact
option that is also reachable. Put it in card headers and panel corners, which
can absorb the height; do not put it in a dense list row.

**The tooltip is also the semantic label**, published on one explicit
`Semantics(button: true)` node with the visual subtree under `ExcludeSemantics`.
Both the tooltip and the spinner otherwise annotate themselves, so the control
would announce the same words two or three times over and never say `button` —
and while busy, when the glyph is gone, that node's label is the only remaining
statement of which action is running.

## Below the button tier: `DesignSystemInlineAction`

A caption-tier tappable row for metadata contexts — "skip this one", "change
this setting" — where even a `dense` button would read as the surface's primary
action. It reads as a control through its glyph, its ink and the shared hover
fill; **it never decorates its label**, so a band cannot end up with three
different dialects for "this is tappable".

Three behaviours are the reason it exists as a component rather than as an
open-coded `Material`/`InkWell` per call site:

- **The ink hugs its content.** It wraps *itself* in an `Align`, because a
  stretching parent hands children a *tight* width under which
  `MainAxisSize.min` is silently a no-op — and the hover layer then runs the
  width of whatever column it happens to sit in. **Everything that describes
  the control lives on the shrink-wrapped side of that `Align`**: the `Align`
  itself still occupies the full offered width, so a `Tooltip` or `Semantics`
  wrapped *around* it fires over blank space and puts the focus rectangle
  where taps do nothing.
- **The tooltip never enters semantics.** `semanticsLabel` is the whole
  announcement; a tooltip publishes its message on the same node, so keeping
  both makes a screen reader read the action twice — literally so wherever a
  caller passes one string as both.
- **The inset lives inside the ink**, so the rounded corners cannot clip the
  leading glyph.
- **`ExcludeSemantics` sits *below* the `InkWell`, never above it.** Excluding
  above drops the ink's own node and with it the tap and focus actions, leaving
  a control that announces as a button but cannot be activated by assistive
  tech. Both open-coded predecessors had this bug.

Disabled means `onTap: null` and the row still renders: a control that vanishes
when unavailable is worse than one that explains itself.

Destructive **secondary and tertiary** button labels use the stronger error
*interaction* tokens rather than the filled-action default red, keeping small
danger labels at AA on light and dark hosts. Their pressed state uses the
high-emphasis content token, **because the dark pressed surface cannot retain
4.5:1 with the available error palette**. The filled danger button keeps the
default error token as its surface.

**`constructiveOutlined`** is the outlined grammar carrying the interactive
accent on both border and label — for a demoted-but-*positive* action beside
a danger primary, where the neutral outlined treatment reads as Cancel
("Verify" next to "Remove" must still look like a good idea).

## Quieter than any tier: `DsQuietInk`

Some targets must not look like buttons at all — breadcrumb crumbs, card-title
disclosure rows, text links, glyph buttons whose visible form is a small disc
inside a larger hit area, and enlarged pointer targets around a switch. On
those, Material's default `InkWell` overlay paints a rectangle around content
that never advertised a boundary: a **phantom button** that appears on hover
and vanishes on exit. `DsQuietInk` is the tap wrapper for that class of
target. It silences every Material overlay (hover, focus, splash, highlight —
the same silence `DesignSystemButton`'s InkWell applies) and instead hands its
`builder` a `highlighted` flag, true on hover, keyboard focus, or while
pressed, so the content answers with a **token-level shift of its own ink** —
a chevron or label stepping up one emphasis tier, a disc border firming a
step. Folding focus into the flag is load-bearing: with `focusColor`
transparent, the builder's ink shift is the only visible cue keyboard users
get. Folding the press in restores tap feedback on touch, where the removed
splash used to carry it. With no tap or long-press handler it renders the
builder's rest state with no `Material`/`InkWell` at all. It adds no
semantics beyond the ink's tap action — callers keep their own `Semantics`
wrappers, and the pointer-only enlarged-target flags
(`excludeFromSemantics`, `canRequestFocus: false`) pass through.

This is a different contract from `DesignSystemInlineAction`, which *is* a
control that reads as one and keeps the shared hover fill. Reach for
`DsQuietInk` only when a hover fill would manufacture a button shape the
resting design deliberately does not have.

## The floating readout: `DsTooltip`

The design system's tooltip surface
(`components/tooltips/ds_tooltip.dart`), replacing the stock Material grey
slab wherever a hover needs to *say* something. It wraps Flutter's `Tooltip`
— positioning, trigger gestures and semantics stay the framework's — and owns
only the surface and the type: the context menu's floating-surface language
(`background.level01` fill, `decorative.level01` hairline, the same soft
shadow, `radii.s` corners) around caption type, plus a ~300 ms wait so a
cursor crossing a dense strip of targets does not strobe.

Two forms. A plain `message` renders one high-emphasis caption line. With
`title` set, the title names the subject (a date, an entity) in semibold
high-emphasis ink and the message describes it a step quieter underneath —
the shape a data readout wants. The goal page's day squares are the canonical
pairing with `DsQuietInk`: the cell paints **no** hover fill (its hit slot is
far larger than the square, so an overlay bulged a phantom button around the
data), and hover answers with `DsTooltip(title: day, message: outcome)`
instead — the pointer asks, the surface names the day and what happened on
it, and the data's own ink never changes.

## In a dense row instead: `DesignSystemContactRow`

The support footer both navigation surfaces close with — four equal,
glyph-only external destinations. Email comes first, followed by
the Manual, GitHub and Discord. The envelope is intentionally no longer a
labelled or otherwise privileged affordance: all four actions take the same
target, icon theme, hover treatment, tooltip and semantic construction. The
desktop sidebar pins the group beneath Settings; the mobile More sheet ends
with it. See [navigation](../../architecture/navigation.md) for why nothing in
it is an app destination.

**Its glyphs are deliberately not `DesignSystemIconAction`, and folding the two
together would break the row.** That control pins its target to
`TapTargets.minimum` and treats the resulting 48×48 as a layout commitment for
card headers and panel corners — it says in as many words not to put it in a
dense row. This *is* a dense row, in the narrowest column the app has. It takes
`DesignSystemFiveSlotNavBar.minTapTarget` instead: the floor the rest of this
app's navigation chrome already uses, still above the 44 px platform guidance
for touch.

**The four controls move as one trailing group.** One `Align.centerRight` owns
the placement, and one `Row(mainAxisSize: min)` owns the uninterrupted action
order. Four 44 px targets need 176 px; even the 200 px minimum sidebar leaves
184 px inside the band's `spacing.step3` inset, so the group stays on one line
without depending on label length or text scale. The component test pins that
budget and verifies every target has the same square geometry.

**There is no rule above the group, and that is why the band is full-bleed at
all.** A divider once ran edge to edge here; it gave the quietest controls
either surface has the weight of a section boundary, announcing a separation
between Settings and four external links that neither surface actually has.
What remains of the band's full width is the `step3` inset above: a
`step5`-gutter row cannot hold the group at the 200 px minimum, so the slot
hands the band the whole rail and lets it choose its own, narrower inset. The
vertical separation is now the band's own leading gap, not a line.

Two contracts beyond the sizing:

- **The glyph is a `Widget`, not an `IconData`.** Material Design Icons has no
  Discord mark and has deprecated its GitHub one, so two of the four travel as
  bundled monochrome vector assets. The row installs one `IconTheme` and all
  four actions read size and colour from it, which is what lets an `SvgPicture`
  tint itself to match the font icons beside it — and why a glyph must resolve
  the theme in its **own** `build`, below where the row installs it.
- **The footer band is always the desktop sidebar's final child.** Status stays
  in destination trailing slots rather than adding a second footer row, so the
  contact band never moves or leaves a conditional hole.

Its `ExcludeSemantics` sits **above** the `InkWell`, which is the shape
`DesignSystemInlineAction` above warns against — safe here for the same reason
it is safe in `DesignSystemIconAction`: the outer `Semantics` republishes
`onTap`, so the node it exposes is still activatable. That is the condition,
not an exception to the rule. A test drives each glyph through
`SemanticsAction.tap` rather than trusting it.

# Status without an alert: the neutral badge tone

`DesignSystemBadgeTone.neutral` is hueless — grey stroke, metadata ink, no
fill on the outlined shape. It exists so a quiet status ("Unverified, no keys
yet") cannot borrow the *identity* grammar of the secondary outlined chip or
an alert tone it has not earned; the sync device roster's "This device" and
keyless "Unverified" chips are the canonical pair that must not match.

**A queue depth is not a status, and no longer dresses as one.**
`SyncQueueCounts` once used this tone as two outlined neutral pills; it now
renders plain `typography.styles.others.caption` text at
`colors.text.lowEmphasis`, with no shell at all. `↓ count` identifies incoming
work from `inboundQueueDepthProvider`; `↑ count` identifies outgoing work from
`outboxPendingCountProvider`. Each direction disappears independently at zero,
and the whole trailing group disappears while sync is disabled.

The distinction the badge shape carries is *"there is a state here worth
naming"* — "Unverified", "This device". A sync queue names nothing: it is
ambient, self-resolving, and not actionable, so an outline gave it a boundary
and a claim on attention it had not earned beside the row's actual navigation.
What survived the shell is the part that was never decoration:

- **The counts are shaped as counts** — `numericBadgeFontFeatures` directly,
  rather than the badge's `numeric: true` opt-in — so a 9 → 10 → 99 transition
  does not re-width the row on every sync tick.
- **The arrow binds to its digits** with `syncQueueArrowGap`, a narrow no-break
  space. It is typographic rather than a spacing token deliberately: it scales
  with the glyphs, where a fixed gap tuned at 1.0× reads proportionally tighter
  as the user raises the text scale.
- **The two directions are separated by `spacing.step3`**, wider than the gap
  inside either. With the outlines gone that space is the only thing keeping
  the pair from reading as one run of glyphs.

See [the sidebar's Settings row](../../architecture/navigation.md#the-settings-row-and-its-counts)
for why the width these two occupy is a property of the row rather than of the
counts.

# Inline callouts

`DesignSystemInlineCallout` is the message grammar: a `background.level02`
surface with an alert-toned hairline border and leading glyph — something to
*read*, deliberately distinct from the hairline card sections use, so a band
cannot carry two dialects of "this is a surface". The tone rides border and
glyph (non-text, ≥ 3:1); the body text stays `text.highEmphasis`, because a
callout's message must never depend on an alert hue for its legibility.
Promoted from the sync feature, whose paused banner and add-device security
warning are the canonical uses.

# One field surface

`DesignSystemSearch` and `DesignSystemDropdown` are separate components that
routinely appear **stacked** — the link modal puts a relationship dropdown above a
task picker's search field; the AI settings header puts a dropdown under its
search bar — so their field shells are held to one treatment:

- **Fill:** `colors.surface.enabled`, an **elevation-aware translucent overlay**
  rather than an absolute background level. This is the load-bearing part: the
  overlay is theme-relative — white at 6% in dark, black at 6% in light — so the
  field lifts off a dark host and insets slightly into a light one. An opaque
  `background.level01` field on an elevated surface (every modal these appear in)
  is instead **a dark sunken hole in dark theme**. Two fields side by side must
  not react to the same sheet in opposite directions.
- **Border:** `colors.decorative.level01`, hairline.
- **Radius:** whichever the paired search size uses — `radii.l` for small,
  `radii.m` for medium. `DesignSystemDropdownSize` selects that, and **controls
  radius only**.

The dropdown keeps two deliberate differences: expanded, its border switches to
`colors.interactive.enabled`, because the search field has no focus treatment to
match and **dropping an open-state signal to win a cosmetic match would be a bad
trade**; and its *height* is content-driven, since it stacks a label above its
value where a search field holds one line.

**The two drifted apart precisely because nothing enforced the match.** The
pairing is now pinned in `design_system_dropdown_test.dart`, which renders both in
one tree and asserts fill, border and radius agree — against each other *and*
against the tokens, so a change moving both in the same wrong direction still
fails.

# Shell-aware overlay spacing

The bottom navigation shell is an **app-level overlay docked flush against the
screen's bottom edge**, not a normal `Scaffold.bottomNavigationBar`. Any
screen-level FAB or status overlay hugging the bottom edge therefore needs
explicit clearance.

The shell and its clearance wrapper live **outside this feature**, in
`lib/widgets/nav_bar/`, and are only exercised through the DS widgetbook. The
contract:

- `DesignSystemBottomNavigationBar.occupiedHeight(context)` defines how much
  vertical space the shell consumes — the bar including safe-area inset, plus the
  height of the indicator overlay row currently riding above it, published by the
  app shell.
- `DesignSystemBottomNavigationFabPadding` is the default wrapper for
  screen-level FABs that need to stay above that shell. **Feature pages should use
  the wrapper rather than inventing local bottom offsets.**
- `DesignSystemFiveSlotNavBar.contentHeight(context)` owns the slot-row height
  contract. It **scales caption line height with `MediaQuery.textScalerOf` and
  rounds fractional line boxes up to the logical pixel Flutter renders**, so
  accessibility scales such as 1.3× cannot overflow the fixed row.

# Accessibility is enforced at construction

Several components refuse to be built without accessible naming:

- `DesignSystemButton` asserts either `label` or `semanticsLabel`, merges its
  visible content into one button node, and puts the tap action on that node.
- `DesignSystemSplitButton` resolves explicit labels for primary and dropdown
  actions.
- `DesignSystemCheckbox` requires a visible label or a semantics label.
- `DesignSystemTooltipIcon` maps tooltip text into semantics by default.
- `DesignSystemContextMenuButton` always exposes a localized trigger name, using
  its tooltip when supplied and Material's "show menu" label otherwise.
- `DesignSystemTextInput` gives the editable node its persistent label plus helper
  or error text, **announces validation errors as live feedback**, requires a
  tooltip or semantic label for every actionable trailing icon, and **excludes
  decorative trailing icons** rather than announcing them as unavailable buttons.
- `DesignSystemSearch` names the editable node and exposes its clear affordance as
  a localized button rather than an unlabeled glyph.
- `DesignSystemTimeWheel` exposes hour, minute and AM/PM columns as **separate
  adjustable semantic controls**, including next/previous values.

Interactive cards that contain a checkbox plus repeated visible metadata expose
one explicit parent semantic node with the checked, enabled and tap states. Their
visual descendants are excluded from semantics, preventing the checkbox label,
visible title and capability badges from being announced as duplicate controls.

Navigation components publish disabled state explicitly: a destination with no
callback **remains discoverable**, but assistive technology announces it as
unavailable and it exposes no tap action. `SidebarMonthCalendar` exposes the month
as a heading and each day as one button labelled with its full localized date,
keeping selected, today and plan states distinct **so today is never falsely
announced as the selected date**.

**This is not universal policy machinery hidden somewhere central.** It is encoded
directly in component constructors and `Semantics` wrappers, which is better
because the rule stays close to the widget that can violate it.

`utils/disabled_overlay.dart` provides `withDisabledOpacity()`, a narrow utility
that keeps disabled treatment consistent without each widget re-implementing the
same opacity wrapper.

# Boundaries

This feature is both a library and a **policy seam**. The intended discipline:
prefer DS tokens over hard-coded literals, prefer DS components when a matching
abstraction exists, and **improve the token source or component when the
abstraction is missing**.

What it should not become: a polite wrapper around arbitrary old widgets, a
dumping ground for one-off visual exceptions, or a fake public API claiming more
stability than the exports provide.

## Extending it safely

1. Check whether the needed token already exists in `tokens.json`.
2. Update the generator only if the token *shape* needs to expand.
3. Build the widget against `context.designTokens`.
4. Add or update Widgetbook coverage.
5. Verify semantics and disabled behaviour.
6. **Only then** adopt it in production code.

When a value is missing, the preferred fix is upstream or at the DS seam. Sneaking
in a one-off literal because it looked close enough is exactly how design systems
turn into decorative fiction.
