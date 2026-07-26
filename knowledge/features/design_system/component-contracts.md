---
type: Feature Module
title: Component contracts
description: The repeating patterns that are contract rather than coincidence — token-first sizing, one field surface, shell-aware spacing, and accessibility enforced at construction.
resource: ../../../lib/features/design_system/components
tags: [design-system, components, accessibility, layout]
status: stable
generated: { by: claude-code/opus-5, at: 2026-07-26T02:00:00Z }
stale_after: 2027-01-31
sources:
  - id: components
    resource: ../../../lib/features/design_system/components
    title: Design-system components
    last_modified: 2026-07-25
  - id: navbar
    resource: ../../../lib/widgets/nav_bar/design_system_bottom_navigation_bar.dart
    title: Bottom navigation shell
    last_modified: 2026-07-25
---

# Token-first sizing and styling

Representative components — `DesignSystemButton`, `DesignSystemCheckbox`,
`DesignSystemSplitButton` — derive padding, radii, icon size and text style from
`context.designTokens`, **not local magic numbers**.

`DesignSystemButton` sizes run `dense` → `small` → `medium` → `large` → `jumbo`.
**`dense` is the caption tier**: its label is
`typography.styles.others.caption`, so it reads as a button through its glyph, ink
and hover fill rather than by out-weighing the text around it. Use it for actions
that live inside metadata rows and settings zones, where a `small` button would
share a type tier with the surface's primary action.

Destructive **secondary and tertiary** button labels use the stronger error
*interaction* tokens rather than the filled-action default red, keeping small
danger labels at AA on light and dark hosts. Their pressed state uses the
high-emphasis content token, **because the dark pressed surface cannot retain
4.5:1 with the available error palette**. The filled danger button keeps the
default error token as its surface.

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

- `DesignSystemButton` asserts either `label` or `semanticsLabel`.
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
