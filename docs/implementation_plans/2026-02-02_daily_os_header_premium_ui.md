# Daily OS Header — Premium UI Overhaul

**Created**: 2026-02-02
**Status**: Planning
**Reference Design**: Nano Banana mockup (2026-02-02)
**Affected PRs**: #2625 (Data Layer), #2626 (UI Implementation), #2627 (Chart)

---

## Executive Summary

This document outlines the visual overhaul of the Daily OS header component to transform it from a "developer prototype" aesthetic to a polished, premium experience befitting a well-funded startup. The header currently functions correctly but lacks intentionality in its visual design.

**Core Problem Statement:**
> "The chart itself renders correctly, but the overall layout is disorienting. It lacks intentionality and polish. Specifically: difficult to distinguish which day is which at a glance, no clear visual separation between weekdays and weekends, the 'currently active' day marker is not distinct enough."

---

## Current State Analysis

### Existing Implementation

The header consists of:
- **Month label row** (16px height): Shows visible month(s) in "MMM yyyy" format
- **Day segments** (56px width each): Horizontal scrollable list with day numbers
- **Stream chart** (72px height): Symmetric stacked area chart showing time distribution
- **Date label row** (44px height): Full date, day label chip, budget status, Today button

### Current Visual Issues

| Issue | Current Behavior | Impact |
|-------|------------------|--------|
| **Day identification** | Only shows day number | Users must mentally calculate day-of-week |
| **Selected state** | Primary color border only | Not prominent enough, easy to lose track |
| **Weekend distinction** | None | Saturday/Sunday blend with weekdays |
| **Overall cohesion** | Functional but flat | Feels like a prototype, not a polished product |

### Reference: Nano Banana Design

The mockup shows:
1. **Two-line day cells**: Weekday abbreviation (Mon, Tue) above day number
2. **Filled selection**: Selected day has solid primary background with white text
3. **Weekend outline**: Sat/Sun cells have subtle rounded border
4. **Clean typography**: Clear visual hierarchy between weekday and day number

---

## Design Specification

### 1. Day Segment Redesign

#### Layout Change
```
Current:           Proposed:
┌──────┐           ┌──────┐
│      │           │ Mon  │  ← Weekday abbreviation
│  29  │    →      │  29  │  ← Day number
│      │           │      │
└──────┘           └──────┘
```

#### Visual States

| State | Background | Border | Weekday Text | Day Number |
|-------|------------|--------|--------------|------------|
| **Default (Weekday)** | Transparent | None | onSurfaceVariant, w400 | onSurface, w500 |
| **Selected** | primary (filled) | None | onPrimary, w500 | onPrimary, w700 |
| **Weekend (Sat/Sun)** | Transparent | outlineVariant 0.5α | onSurfaceVariant, w400 | onSurface 0.8α, w500 |
| **Weekend + Selected** | primary (filled) | None | onPrimary, w500 | onPrimary, w700 |

#### Typography Specifications

| Element | Font Size | Weight | Style |
|---------|-----------|--------|-------|
| Weekday abbreviation | 11px | 400 (regular) / 500 (selected) | labelSmall |
| Day number | 16px | 500 (regular) / 700 (selected) | titleMedium |

#### Spacing

- Segment width: 56px (unchanged)
- Border radius: 8px
- Internal padding: 4px horizontal, 4px vertical
- Day divider width: 1px (reduced from 2px)
- Divider alpha: 0.2 (reduced from 0.5)

### 2. Selection State Enhancement

The current border-only selection is insufficiently prominent. The new design uses:

```dart
// Selected state
Container(
  decoration: BoxDecoration(
    color: context.colorScheme.primary,  // Filled background
    borderRadius: BorderRadius.circular(8),
  ),
  child: Column(
    children: [
      Text(weekdayAbbrev, style: onPrimary...),
      Text(dayNumber, style: onPrimary...),
    ],
  ),
)
```

### 3. Weekend Differentiation

Weekends receive a subtle outline to create visual grouping:

```dart
// Weekend state (not selected)
Container(
  decoration: BoxDecoration(
    borderRadius: BorderRadius.circular(8),
    border: Border.all(
      color: context.colorScheme.outlineVariant.withValues(alpha: 0.5),
    ),
  ),
  ...
)
```

This creates a "weekend group" visual effect where Saturday and Sunday appear as a cohesive unit, distinct from weekdays.

### 4. Date Label Row Polish

Minor refinements to the bottom row:
- Ensure consistent spacing between elements
- Status indicator already well-designed (keep as-is)

---

## Implementation Plan

### Files to Modify

| File | Changes |
|------|---------|
| `lib/features/daily_os/ui/widgets/time_history_header/day_segment.dart` | Complete redesign |
| `lib/features/daily_os/ui/widgets/time_history_header/time_history_header_widget.dart` | Adjust divider width constant |
| `test/features/daily_os/ui/widgets/time_history_header/day_segment_test.dart` | Update for new layout |

### Task Breakdown

#### Phase 1: Day Segment Redesign

- [ ] **1.1** Add `_isWeekend` getter to `DaySegment` class
- [ ] **1.2** Extract weekday abbreviation using `DateFormat.E(locale)`
- [ ] **1.3** Implement three visual states:
  - [ ] Default weekday (transparent, no border)
  - [ ] Selected (filled primary background)
  - [ ] Weekend (transparent with outline border)
- [ ] **1.4** Apply typography hierarchy (weekday small, day number larger)
- [ ] **1.5** Center content vertically within segment
- [ ] **1.6** Reduce day divider width from 2px to 1px
- [ ] **1.7** Reduce divider alpha from 0.5 to 0.2

#### Phase 2: Test Updates

- [ ] **2.1** Update existing tests for new two-line layout
- [ ] **2.2** Add test for weekend styling (verify border on Sat/Sun)
- [ ] **2.3** Add test for weekday abbreviation rendering
- [ ] **2.4** Verify accessibility labels still work

#### Phase 3: Verification

- [ ] **3.1** Run analyzer (`fvm dart analyze`)
- [ ] **3.2** Run formatter (`fvm dart format .`)
- [ ] **3.3** Run all Daily OS tests
- [ ] **3.4** Manual verification on iOS, macOS, Linux

---

## Code Changes

### day_segment.dart (Complete Rewrite)

```dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lotti/features/daily_os/state/time_history_header_controller.dart';
import 'package:lotti/themes/theme.dart';

/// Fixed width for each day segment in the horizontal list.
const double daySegmentWidth = 56;

/// Width of the day divider (left/right border).
const double dayDividerWidth = 1;

/// Individual day segment in the horizontal list.
///
/// Premium design features:
/// - Two-line layout: weekday abbreviation on top, day number below
/// - Selected state: filled primary background with contrasting text
/// - Weekend differentiation: subtle outline border for Sat/Sun
class DaySegment extends StatelessWidget {
  const DaySegment({
    required this.daySummary,
    required this.isSelected,
    required this.onTap,
    this.showRightBorder = false,
    super.key,
  });

  final DayTimeSummary daySummary;
  final bool isSelected;
  final VoidCallback onTap;
  final bool showRightBorder;

  bool get _isWeekend {
    final weekday = daySummary.day.weekday;
    return weekday == DateTime.saturday || weekday == DateTime.sunday;
  }

  @override
  Widget build(BuildContext context) {
    final day = daySummary.day;
    final locale = Localizations.localeOf(context).toString();
    final weekdayAbbrev = DateFormat.E(locale).format(day);

    return GestureDetector(
      onTap: onTap,
      child: Semantics(
        label: DateFormat.yMMMMd(locale).format(day),
        button: true,
        selected: isSelected,
        child: Container(
          width: daySegmentWidth,
          decoration: BoxDecoration(
            // Subtle day separator (midnight divider)
            border: Border(
              left: BorderSide(
                color:
                    context.colorScheme.outlineVariant.withValues(alpha: 0.2),
                width: dayDividerWidth,
              ),
              right: showRightBorder
                  ? BorderSide(
                      color: context.colorScheme.outlineVariant
                          .withValues(alpha: 0.2),
                      width: dayDividerWidth,
                    )
                  : BorderSide.none,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: _buildDayContent(context, weekdayAbbrev, day.day),
          ),
        ),
      ),
    );
  }

  Widget _buildDayContent(
    BuildContext context,
    String weekdayAbbrev,
    int dayNumber,
  ) {
    // Selected state: filled primary background
    if (isSelected) {
      return Container(
        decoration: BoxDecoration(
          color: context.colorScheme.primary,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              weekdayAbbrev,
              style: context.textTheme.labelSmall?.copyWith(
                color: context.colorScheme.onPrimary,
                fontWeight: FontWeight.w500,
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              dayNumber.toString(),
              style: context.textTheme.titleMedium?.copyWith(
                color: context.colorScheme.onPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    // Weekend state: subtle outline border
    if (_isWeekend) {
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: context.colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              weekdayAbbrev,
              style: context.textTheme.labelSmall?.copyWith(
                color: context.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w400,
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              dayNumber.toString(),
              style: context.textTheme.titleMedium?.copyWith(
                color: context.colorScheme.onSurface.withValues(alpha: 0.8),
                fontWeight: FontWeight.w500,
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    // Default weekday state: no background
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          weekdayAbbrev,
          style: context.textTheme.labelSmall?.copyWith(
            color: context.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w400,
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          dayNumber.toString(),
          style: context.textTheme.titleMedium?.copyWith(
            color: context.colorScheme.onSurface,
            fontWeight: FontWeight.w500,
            fontSize: 16,
          ),
        ),
      ],
    );
  }
}
```

---

## Visual Comparison

### Before (Current)

```
┌────────────────────────────────────────────────────────┐
│                   Feb 2026                              │
├──────┬──────┬──────┬──────┬──────┬──────┬──────┬──────┤
│      │      │      │ ┌──┐ │      │      │      │      │
│  27  │  28  │  29  │ │30│ │  31  │  1   │  2   │  3   │
│      │      │      │ └──┘ │      │      │      │      │
└──────┴──────┴──────┴──────┴──────┴──────┴──────┴──────┘
        Selected has border only, no weekday labels
```

### After (Nano Banana)

```
┌────────────────────────────────────────────────────────┐
│                   Feb 2026                              │
├──────┼──────┼──────┼──────┼──────┼──────┼──────┼──────┤
│ Thu  │ Fri  │░Sat░░│░Sun░░│ Mon  │██████│ Wed  │ Thu  │
│  27  │  28  │░ 1 ░░│░ 2 ░░│  3   │█ 4 ██│  5   │  6   │
│      │      │░░░░░░│░░░░░░│      │██████│      │      │
└──────┴──────┴──────┴──────┴──────┴──────┴──────┴──────┘
        ░░░░ = Weekend outline    ████ = Selected (filled)
```

---

## Testing Strategy

### Unit Tests

```dart
group('DaySegment Premium UI', () {
  testWidgets('displays weekday abbreviation above day number', (tester) async {
    // Arrange: Create a segment for Monday, Feb 3
    // Act: Pump widget
    // Assert: Find 'Mon' text and '3' text in vertical arrangement
  });

  testWidgets('selected state has filled primary background', (tester) async {
    // Arrange: Create a selected segment
    // Act: Pump widget
    // Assert: Container has primary color fill, no border
  });

  testWidgets('weekend has outline border when not selected', (tester) async {
    // Arrange: Create segment for Saturday (not selected)
    // Act: Pump widget
    // Assert: Container has border, no fill
  });

  testWidgets('weekend selected state has filled background, no outline', (tester) async {
    // Arrange: Create selected segment for Saturday
    // Act: Pump widget
    // Assert: Container has primary fill (same as weekday selected)
  });
});
```

### Visual Regression

Manual verification on:
- iOS Simulator (iPhone 15 Pro)
- macOS (native)
- Linux (Flathub)

Check for:
- Correct weekday abbreviation localization
- Selection visibility on light and dark themes
- Weekend grouping visual coherence
- Chart alignment with day boundaries

---

## Risks and Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Localized weekday abbrev too long | Low | Medium | Test with German (Mi, Do) and Japanese (月, 火) locales |
| Selection not visible on certain themes | Low | High | Test on both light and dark mode |
| Weekend border conflicts with selection | Low | Low | Selection takes precedence, no border when selected |

---

## Acceptance Criteria

1. **Day Identification**: Each column clearly shows which day of the week it represents
2. **Selection Prominence**: Active day is immediately obvious at a glance
3. **Weekend Grouping**: Saturday and Sunday visually distinct from weekdays
4. **No Regressions**: All existing tests pass, chart alignment preserved
5. **Polished Feel**: Overall aesthetic matches "well-funded startup" quality bar

---

## Appendix: Files Reference

| File | Purpose |
|------|---------|
| `lib/features/daily_os/ui/widgets/time_history_header/day_segment.dart` | Day cell widget |
| `lib/features/daily_os/ui/widgets/time_history_header/time_history_header_widget.dart` | Main header container |
| `lib/features/daily_os/ui/widgets/time_history_header/date_label_row.dart` | Bottom row with full date |
| `lib/features/daily_os/ui/widgets/time_history_header/status_indicator.dart` | Budget status badge |
| `test/features/daily_os/ui/widgets/time_history_header/day_segment_test.dart` | Widget tests |

---

*Plan created based on Nano Banana design mockup (2026-02-02).*
