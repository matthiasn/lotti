# Implementation Plan: Linked Tasks UI Section

**Date**: 2026-01-08
**Status**: COMPLETED (v0.9.804)
**Feature**: Dedicated UI Section for Linked Tasks in Task Detail View

## Overview

Implemented a dedicated "Linked Tasks" section in the task detail view that displays tasks linked to/from the current task with directional indicators, dropdown menu actions for link management, and the ability to unlink tasks.

## What Was Built

### UI Design

**Final Design**: Minimal, Linear-style text links (not cards)
- Simple text with underline on tap
- Small 14px status circles (hollow for open, filled with check for completed)
- Directional labels: `↳ LINKED FROM`, `↗ LINKED TO`
- Clean unlink (×) buttons in manage mode

**Location**: Between AI Task Summary and Checklists sections in task details

### Menu Actions

1. **"Link existing task..."** - Opens FTS5-powered searchable modal
2. **"Create new linked task..."** - Creates subtask inheriting category
3. **"Manage links..."** - Toggles unlink buttons (shows "Done" when active)

Note: "Show completed" toggle was removed - all linked tasks are always shown.

## Files Created

### State

| File | Purpose |
|------|---------|
| `lib/features/tasks/state/linked_tasks_controller.dart` | Manages UI state (manageMode only) |
| `lib/features/tasks/state/linked_tasks_controller.freezed.dart` | Generated freezed code |
| `lib/features/tasks/state/linked_tasks_controller.g.dart` | Generated Riverpod code |

### UI Widgets

| File | Widget | Description |
|------|--------|-------------|
| `lib/features/tasks/ui/linked_tasks/linked_tasks_widget.dart` | `LinkedTasksWidget` | Main container, fetches links, renders sections |
| `lib/features/tasks/ui/linked_tasks/linked_tasks_header.dart` | `LinkedTasksHeader` | Title + popup menu |
| `lib/features/tasks/ui/linked_tasks/linked_from_section.dart` | `LinkedFromSection` | Incoming links (↳) |
| `lib/features/tasks/ui/linked_tasks/linked_to_section.dart` | `LinkedToSection` | Outgoing links (↗) |
| `lib/features/tasks/ui/linked_tasks/linked_task_card.dart` | `LinkedTaskCard` | Minimal text link with status circle |
| `lib/features/tasks/ui/linked_tasks/link_task_modal.dart` | `LinkTaskModal` | Searchable task selection modal |

### Tests

| File | Tests | Coverage |
|------|-------|----------|
| `test/features/tasks/state/linked_tasks_controller_test.dart` | 8 | Controller state management |
| `test/features/tasks/ui/linked_tasks/linked_tasks_widget_test.dart` | 11 | Widget integration tests |
| `test/features/tasks/ui/linked_tasks/linked_tasks_header_test.dart` | 12 | Header rendering, menu, modal opening |
| `test/features/tasks/ui/linked_tasks/linked_from_section_test.dart` | 10 | Incoming links section |
| `test/features/tasks/ui/linked_tasks/linked_to_section_test.dart` | 10 | Outgoing links section |
| `test/features/tasks/ui/linked_tasks/linked_task_card_test.dart` | 21 | Card rendering, navigation, styling |
| `test/features/tasks/ui/linked_tasks/link_task_modal_test.dart` | 20 | Search modal, filtering, link creation |

## Files Modified

### Integration

| File | Change |
|------|--------|
| `lib/features/tasks/ui/pages/task_details_page.dart` | Added `LinkedTasksWidget`, pass `hideTaskEntries: true` to LinkedEntriesWithTimer |
| `lib/features/journal/ui/widgets/entry_details_widget.dart` | Added `hideTaskEntries` parameter |
| `lib/features/journal/ui/widgets/entry_detail_linked.dart` | Added `hideTaskEntries` parameter |
| `lib/features/journal/ui/widgets/linked_entries_with_timer.dart` | Added `hideTaskEntries` parameter |

### Localization

Added to `lib/l10n/app_en.arb`:
```json
{
  "linkedTasksTitle": "Linked Tasks",
  "linkedFromLabel": "LINKED FROM",
  "linkedToLabel": "LINKED TO",
  "linkExistingTask": "Link existing task...",
  "createNewLinkedTask": "Create new linked task...",
  "manageLinks": "Manage links...",
  "unlinkTaskTitle": "Unlink Task",
  "unlinkTaskConfirm": "Are you sure you want to unlink this task?",
  "unlinkButton": "Unlink",
  "searchTasksHint": "Search tasks...",
  "linkedTasksMenuTooltip": "Linked tasks options"
}
```

## Architecture

### Data Flow

```text
LinkedTasksWidget
├── Watches linkedEntriesControllerProvider (outgoing links)
├── Watches linkedFromEntriesControllerProvider (incoming links)
├── Filters to Task type only (whereType<Task>())
└── Renders sections with optional unlink buttons (manageMode)
```

### State Model

```dart
@freezed
abstract class LinkedTasksState with _$LinkedTasksState {
  const factory LinkedTasksState({
    @Default(false) bool manageMode,  // Only manageMode, showCompleted was removed
  }) = _LinkedTasksState;
}
```

## Key Technical Decisions

1. **Reuse Existing Controllers**: `LinkedEntriesController` and `LinkedFromEntriesController` - no new database queries
2. **Filter at Widget Level**: Task type filtering done in Dart with `whereType<Task>()`
3. **No showCompleted Toggle**: Always shows all linked tasks (completed and open)
4. **hideTaskEntries Parameter**: Tasks filtered from generic "Linked Entries" to avoid duplication
5. **Category Inheritance**: New linked tasks inherit parent task's category

## Design Evolution

### Initial Plan (Card-Based)
- Heavy card treatment with backgrounds and borders
- Status icons with multiple variations
- showCompleted toggle for filtering

### Final Design (Linear-Style)
- Minimal text links with underline decoration
- Simple 14px status circles
- No filtering - always show all tasks
- Clean, intentional, not over-designed

## File Structure

```text
lib/features/tasks/
├── state/
│   ├── linked_tasks_controller.dart
│   ├── linked_tasks_controller.freezed.dart
│   └── linked_tasks_controller.g.dart
└── ui/
    └── linked_tasks/
        ├── linked_tasks_widget.dart
        ├── linked_tasks_header.dart
        ├── linked_from_section.dart
        ├── linked_to_section.dart
        ├── linked_task_card.dart
        └── link_task_modal.dart
```

## Test Coverage

All 92 tests pass:
- Controller state tests (8 tests)
- Widget integration tests (11 tests)
- Header widget tests (12 tests)
- From section tests (10 tests)
- To section tests (10 tests)
- Card widget tests (21 tests)
- Modal widget tests (20 tests)

## Critical Files Reference

| File | Purpose |
|------|---------|
| `lib/features/tasks/ui/pages/task_details_page.dart` | Integration point for LinkedTasksWidget |
| `lib/features/tasks/ui/checklists/checklists_widget.dart` | Section header pattern followed |
| `lib/features/journal/state/linked_entries_controller.dart` | Outgoing links controller (reused) |
| `lib/features/journal/state/linked_from_entries_controller.dart` | Incoming links controller (reused) |
| `lib/logic/create/create_entry.dart` | `createTask()` function for new linked task |
| `lib/logic/persistence_logic.dart` | `createLink()` method for linking existing task |
