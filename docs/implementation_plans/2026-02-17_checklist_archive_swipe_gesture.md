# Checklist Item Archive Swipe Gesture - Implementation Plan

**Date:** 2026-02-17
**Status:** Implemented
**Version:** 0.9.863

## Problem Statement

Currently, checklist items have only two states: open (unchecked) and completed (checked), plus soft-delete. This creates a semantic gap:

1. Users check items that are tracked elsewhere, even though the task isn't "done" - semantically inaccurate.
2. Users delete items, losing historical context.

An "Archive" state captures reality better: the item is **not relevant anymore** but the record is preserved.

## Design

### Data Model

Add `isArchived` field to `ChecklistItemData` (freezed):

```dart
@freezed
abstract class ChecklistItemData with _$ChecklistItemData {
  const factory ChecklistItemData({
    required String title,
    required bool isChecked,
    required List<String> linkedChecklists,
    @Default(false) bool isArchived,  // NEW
    String? id,
  }) = _ChecklistItemData;
}
```

`@Default(false)` ensures backward compatibility - existing items deserialize with `isArchived: false`.

### Swipe Interaction

Replace the current single-direction `Dismissible` (endToStart = delete) with a bidirectional `Dismissible`:

| Direction | Gesture | Background | Action |
|-----------|---------|------------|--------|
| **Right** (startToEnd) | Swipe right | Amber + archive/unarchive icon | Archive or unarchive (toggle) |
| **Left** (endToStart) | Swipe left | Red + delete icon | Delete item (existing) |

**Why bidirectional `Dismissible` over `flutter_slidable`:**
- No new dependency required
- Works naturally with existing `super_drag_and_drop` (long-press = drag, swipe = dismiss)
- Standard two-direction pattern (used by Gmail, Apple Mail, etc.)
- Clear, distinct gestures for each action

**Archive swipe behavior:**
- `confirmDismiss` performs the archive/unarchive toggle and returns `false` (item stays in list)
- State update causes re-render with strikethrough styling
- If "Open" filter is active, the existing hide animation removes it from view
- Shows SnackBar with "Undo" action after archiving

**Unarchive behavior:**
- Switch to "All" filter to see archived items
- Swipe right again on an archived item to unarchive it
- The background icon changes to `Icons.unarchive` for already-archived items

**Delete swipe behavior:**
- Unchanged from current implementation (confirmation dialog + soft delete)

### Visual Appearance

Archived items reuse the existing strikethrough styling (same as checked items in `ChecklistItemWidget`):

```dart
// Strikethrough when checked OR archived
if (_isChecked || widget.isArchived) {
  style = TextStyle(decoration: TextDecoration.lineThrough, ...);
}
```

The checkbox is disabled when archived. The checkbox state remains unchanged (`isChecked: false`) - the item is not "done", just "not relevant".

### Filter Behavior

| Filter | Shows |
|--------|-------|
| **Open** | Items where `!isChecked && !isArchived` |
| **All** | All items (checked, unchecked, and archived) |

This extends the existing `_shouldHide` pattern: `widget.hideCompleted && (widget.isChecked || widget.isArchived)`.

### Completion Metrics

Archived items are excluded from both numerator and denominator:

```
activeItems    = items.where(!isDeleted && !isArchived)
completedCount = activeItems.where(isChecked).length
totalCount     = activeItems.length
```

An item that is "not relevant anymore" should not affect the completion percentage.

## Files Changed

### 1. Data Model
| File | Change | Status |
|------|--------|--------|
| `lib/classes/checklist_item_data.dart` | Added `@Default(false) bool isArchived` field | Done |
| **build_runner** | Regenerated `.freezed.dart` and `.g.dart` | Done |

### 2. State / Controllers
| File | Change | Status |
|------|--------|--------|
| `lib/features/tasks/state/checklist_item_controller.dart` | Added `archive()`, `unarchive()`, `_setArchived()` methods | Done |
| `lib/features/tasks/state/checklist_controller.dart` | Excluded archived from completion counts in `_computeState()` | Done |

Note: No repository changes were needed — `archive()`/`unarchive()` use the existing `updateChecklistItem()`.

### 3. UI Components
| File | Change | Status |
|------|--------|--------|
| `lib/features/tasks/ui/checklists/checklist_item_wrapper.dart` | Bidirectional `Dismissible` with archive (right) + delete (left), SnackBar with undo | Done |
| `lib/features/tasks/ui/checklists/checklist_item_widget.dart` | Added `isArchived` param, disabled checkbox when archived, strikethrough when archived | Done |
| `lib/features/tasks/ui/checklists/checklist_item_with_suggestion_widget.dart` | Added `isArchived` param, extended `_shouldHide`, tracked `_lastIsArchived` in `didUpdateWidget` | Done |

Note: `checklist_card_body.dart` did not need changes — the archive data flows through the controller and wrapper.

### 4. Localization
| File | Entries Added | Status |
|------|---------------|--------|
| `lib/l10n/app_en.arb` | `checklistItemArchiveUndo`, `checklistItemArchived`, `checklistItemUnarchived` | Done |
| `lib/l10n/app_de.arb` | German translations | Done |
| `lib/l10n/app_es.arb` | Spanish translations | Done |
| `lib/l10n/app_fr.arb` | French translations | Done |
| `lib/l10n/app_ro.arb` | Romanian translations | Done |
| `lib/l10n/app_cs.arb` | Czech translations | Done |

### 5. Tests
| File | Tests Added | Status |
|------|-------------|--------|
| `test/features/tasks/state/checklist_item_controller_test.dart` | 3 tests: archive sets isArchived, unarchive clears it, archive preserves checked state | Done (7 total pass) |
| `test/features/tasks/ui/checklists/checklist_item_widget_test.dart` | 4 tests: strikethrough when archived, disabled checkbox, both archived+checked, not disabled when not archived | Done (26 total pass) |
| `test/features/tasks/ui/checklists/checklist_item_wrapper_test.dart` | 6 tests: archive swipe calls archive + shows snackbar, unarchive swipe, delete swipe shows dialog, both backgrounds configured, unarchive icon for archived items, isArchived passed through | Done (21 total pass) |

All 701 tests in `test/features/tasks/` pass.

### 6. Documentation & Release
| File | Change | Status |
|------|--------|--------|
| `CHANGELOG.md` | Entry under `[0.9.863]` | Done |
| `flatpak/com.matthiasn.lotti.metainfo.xml` | Matching release entry | Done |
| `lib/features/tasks/README.md` | Documented archive feature, ChecklistItemWrapper, and archive section | Done |

## Implementation Order (as executed)

1. **Data model** — Added `isArchived` to `ChecklistItemData`, ran build_runner
2. **Controller** — Added `archive()`/`unarchive()` to `ChecklistItemController`
3. **Completion metrics** — Excluded archived items in `ChecklistCompletionController._computeState()`
4. **UI - ChecklistItemWidget** — Added `isArchived` param, strikethrough + disabled checkbox
5. **UI - ChecklistItemWithSuggestionWidget** — Added `isArchived` param, extended hide logic + `didUpdateWidget`
6. **UI - ChecklistItemWrapper** — Bidirectional `Dismissible` with archive/unarchive toggle
7. **Localization** — Added labels to all 6 arb files, ran `make l10n`
8. **Tests** — Controller tests, widget tests, wrapper tests (all pass)
9. **Documentation** — CHANGELOG, metainfo, feature README
10. **Analyzer + formatter** — Zero warnings, all formatted
