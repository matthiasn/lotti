# Settings Header Modernization — Mobile & Desktop

## Summary

- Tall `SliverTitleBar` headers built with `appBarTextStyleNewLarge` (25px base font) collide with
  the leading back button on compact devices, especially for long Matrix settings titles.
- Fixed dimensions (`expandedHeight: 120`, `leadingWidth: 100`) don't adapt to device constraints
  or text scaling, causing overlap issues when accessibility settings scale text up to 200%.
- The visual hierarchy across settings/sync list pages feels oversized compared with the surrounding
  cards, undermining the polished, premium aesthetic we target.
- Two separate header systems (`SliverTitleBar` and `TitleAppBar`) lack consistency and test coverage.
- We will design and ship a responsive, typography-driven header system that scales gracefully
  across phone, tablet, and desktop, while staying consistent with `agents.md` process expectations.

## Goals

- Deliver a responsive settings header layout that preserves back-button affordances and safe-area
  spacing on iOS/Android and desktop shells.
- Establish shared typography, spacing, and decorative treatments (e.g., divider, supporting copy)
  so every settings surface feels cohesive and premium.
- Provide configurable variants for list scaffolds (`SliverBoxAdapterPage`, `SyncListScaffold`, and
  any direct `SliverTitleBar` consumers) without duplicating layout code.
- Unify or clarify the distinct roles of `SliverTitleBar` (scrollable) and `TitleAppBar` (fixed).
- Create comprehensive test coverage BEFORE refactoring to enable safe changes.
- Implement non-breaking migration path using adapter pattern to avoid disrupting existing features.
- Maintain zero analyzer warnings, add meaningful widget coverage, and update user-facing
  docs and changelog alongside the implementation.

## Non-Goals

- No redesign of the settings card content blocks themselves (animations, icons, or segmented
  controls stay as-is).
- No overhaul of global navigation chrome outside the settings/sync stack.
- No new localization strings beyond what's required for optional supporting text.

## Findings Recap

- `lib/widgets/app_bar/sliver_title_bar.dart` hardcodes `expandedHeight: 120`, `leadingWidth: 100`,
  and centers a large multi-line title with `appBarTextStyleNewLarge` (25px font), causing overlap
  when the back button renders (`BackWidget` from `title_app_bar.dart`).
- Zero test coverage exists for `SliverTitleBar` or `TitleAppBar`, making refactoring risky.
- `BackWidget` uses flutter_animate with 1-second fade-in animations that need coordination.
- `SliverBoxAdapterPage` and `SyncListScaffold` both wrap `SliverTitleBar`, so any header change
  must account for two pathways (simple content vs. streaming list).
- `SyncListScaffold` already implements sophisticated responsive padding via `_effectivePaddingForWidth`
  (lines 149-189) with 9 breakpoints—this pattern should be reused, not reinvented.
- Desktop builds rely on the same widget, yielding an overly sparse first fold when the title
  shrinks; we need adaptive spacing rather than a one-size-fits-all `expandedHeight`.
- Current `SliverTitleBar` supports a `bottom` property for additional widgets (PreferredSizeWidget)
  that must be preserved in any refactoring.
- With accessibility text scaling, `appBarTextStyleNewLarge` can reach 50px+, exceeding safe zones.
- Current typography tokens live in `theme.dart` with limited variants for large headings; we may
  need a dedicated settings header text style to align with the brand scale.

## Experience Pillars

- **Responsive precision** — Layout adapts to width breakpoints (phone, tablet, desktop) with
  controlled max widths and dynamic padding.
- **Clarity first** — Back affordance, breadcrumbs, and optional subtitle or metadata never overlap;
  typography remains legible at large titles and high text scaling.
- **Premium feel** — Introduce subtle motion, tint, or glass treatment that connects the header to
  the card list while keeping contrast accessible.

## Implementation Overview

1. Create comprehensive test coverage for existing `SliverTitleBar` and `TitleAppBar` to enable
   safe refactoring with regression detection.
2. Extract and reuse existing responsive patterns from `SyncListScaffold._effectivePaddingForWidth`
   into shared utilities.
3. Gather visual direction and approve a target design (wireframe/Figma) covering long/short titles,
   text scaling scenarios, and platform-specific safe areas.
4. Introduce theme tokens and responsive sizing helpers, leveraging existing patterns and adding
   text scale clamping for accessibility.
5. Create new `SettingsHeader` component with adapter pattern for `SliverTitleBar` to ensure
   non-breaking migration path.
6. Implement the new header component with proper scroll behavior.
7. Migrate `SliverBoxAdapterPage`, `SyncListScaffold`, and direct consumers using the adapter
   pattern for backward compatibility.
8. Validate via analyzer/tests (`dart-mcp.*`), add widget coverage, update docs (feature
   README, `agents.md`-aligned process notes).

## Phase -1 — Test Foundation & Documentation

- Create comprehensive widget tests for current `SliverTitleBar` behavior including:
  - Long title truncation/wrapping
  - Back button rendering and interaction
  - Bottom widget support (PreferredSizeWidget)
  - Pinned vs unpinned scrolling behavior
- Create widget tests for `TitleAppBar` and `BackWidget` including animation timing
- Document current behavior and known issues
- Set up test fixtures for different title lengths and device configurations

### Exit Criteria

- 90%+ test coverage for existing header components
- Documented behavior matrix for regression tracking

## Phase 0 — Discovery & Alignment

- Audit all settings/sync entry points (Matrix settings, maintenance, outbox, conflicts, logs,
  advanced pages) to catalogue title lengths and subtitle needs.
- Collect measurements from current implementation (safe-area offsets, text scaling with system font
  at 120% and 200%, behavior in landscape, platform-specific notch/status bar handling).
- Extract and document `SyncListScaffold._effectivePaddingForWidth` pattern for reuse.
- Collaborate with design to define the polished header (typography tokens, optional gradient/card,
  animation) and produce annotated mocks.
- Confirm accessibility requirements (minimum tap targets, dynamic type with max scale, contrast).

### Exit Criteria

- Approved design spec with breakpoint guidance and platform-specific considerations.
- Documented list of affected screens with migration complexity assessment.
- Extracted responsive utilities ready for reuse.

## Phase 1 — Theme & Token Foundations

- Extend `theme.dart` with responsive text styles that clamp text scaling:
  ```dart
  // Example implementation
  fontSize: MediaQuery.textScaleFactorOf(context).clamp(0.8, 1.2) *
           (constraints.width < 400 ? 18 : 22)
  ```
- Extract `SyncListScaffold._effectivePaddingForWidth` into shared `ResponsiveLayout` utility
- Introduce collision prevention calculations:
  ```dart
  final backButtonWidth = showBackButton ? 48.0 : 0; // Icon + padding
  final titlePadding = EdgeInsets.only(left: backButtonWidth + 8);
  ```
- Add platform-specific height calculations:
  ```dart
  final topPadding = MediaQuery.of(context).padding.top;
  final expandedHeight = Platform.isIOS
    ? max(120, topPadding + 80)  // Account for notch/Dynamic Island
    : 100;  // Standard Android
  ```
- Add unit tests around all new helpers ensuring breakpoint thresholds behave as designed.

### Exit Criteria

- New theme tokens available with text scale clamping
- Shared responsive utilities extracted and tested
- Platform-specific calculations documented
- Design tokens referenced in README or theme documentation for future reuse.

## Phase 2 — Header Component Architecture

- Create new `SettingsHeader` component with:
  - Support for optional subtitle/metadata/action slots
  - Preserve existing `bottom` property support (PreferredSizeWidget)
  - Proper handling of long titles and text wrapping
  - Responsive sizing based on device constraints
- Implement adapter pattern for non-breaking migration:
  ```dart
  // Existing SliverTitleBar delegates to new implementation
  class SliverTitleBar extends StatelessWidget {
    @override
    Widget build(BuildContext context) {
      return SettingsHeader.legacy(
        title: title,
        pinned: pinned,
        showBackButton: showBackButton,
        bottom: bottom,
      );
    }
  }
  ```
- Update `BackWidget` sizing with collision prevention:
  - Calculate actual widget width including icon and padding
  - Pass width to header for proper title inset calculation
  - Coordinate with existing 1-second fade animation timing
- Add debug mode collision overlay to visualize safe zones
- Add comprehensive widget tests covering:
  - Long title truncation/wrapping behavior
  - Back button interaction across breakpoints
  - Subtitle rendering and safe-area padding
  - Accessibility text scaling up to 200%

### Exit Criteria

- New component integrated with adapter pattern maintaining backward compatibility
- All existing `SliverTitleBar` usages continue working without modification
- Tests passing with 95%+ coverage of new component

## Phase 3 — Migration & Integration

- Migrate all pages in a single coordinated update:
  1. Update `SliverBoxAdapterPage` to use new header
  2. Update `SyncListScaffold` to use new header
  3. Update direct `SliverTitleBar` usage in habits/tags pages
- For each migration:
  - Run existing tests to verify no regression
  - Test with accessibility settings at max scale
- Adjust surrounding padding/margins leveraging extracted responsive utilities
- Coordinate `TitleAppBar` updates for consistency between fixed and scrollable headers

### Exit Criteria

- All pages successfully migrated in single update
- All tests passing with new implementation

## Phase 4 — QA, Accessibility, and Launch Prep

- Run `dart-mcp.analyze_files` and focused widget tests, then smoke `dart-mcp.run_tests` for
  impacted suites.
- Validate dynamic type (iOS accessibility setting ≥ 2 steps) and RTL layout if supported.
- Update feature README(s) and changelog entry.
- Coordinate with release to ensure any new assets or dependencies are noted.

### Exit Criteria

- Analyzer/test suite clean, accessibility checklist satisfied, documentation merged.

## Technical Implementation Details

### Collision Prevention Algorithm
```dart
double calculateTitleInset(BuildContext context, bool showBackButton) {
  const iconSize = 30.0;
  const iconPadding = 18.0; // 2px + 8px internal + 8px margin
  const backButtonWidth = iconSize + iconPadding;
  const safetyMargin = 8.0;

  return showBackButton
    ? backButtonWidth + safetyMargin
    : safetyMargin;
}
```

## Risks & Mitigations

- **Breaking existing features:** Mitigate with adapter pattern for backward compatibility
- **Test regression:** Create comprehensive test suite BEFORE refactoring (Phase -1)
- **Animation coordination issues:** Maintain existing `BackWidget` fade timing
- **Tablet/desktop regressions:** Reuse proven `SyncListScaffold._effectivePaddingForWidth` pattern
- **Accessibility breakage:** Test with 200% text scaling and platform-specific screen readers
- **Design churn:** Lock spec in Phase 0 with clear sign-off to avoid late-cycle redesigns
- **Missing test coverage:** Phase -1 ensures 90%+ coverage before any changes

## Process Alignment (agents.md)

- Follow `agents.md` by preferring MCP workflows (`dart-mcp.analyze_files`, `dart-mcp.run_tests`,
  `dart-mcp.dart_format`) before final review.
- Maintain zero analyzer warnings, update changelog, and refresh any feature README touched by
  header changes.
- Use the planning conventions (update plan tool, preamble before grouped tool calls) for ongoing
  work as outlined in `agents.md`.

## References

- `lib/widgets/app_bar/sliver_title_bar.dart`, `lib/widgets/app_bar/title_app_bar.dart`
- `lib/features/settings/ui/pages/sliver_box_adapter_page.dart`
- `lib/features/sync/ui/widgets/sync_list_scaffold.dart`
- `agents.md` — repository-wide collaboration/process guidance
- Existing implementation plans from 2025-10-23 and 2025-10-24 for structure and rigor

