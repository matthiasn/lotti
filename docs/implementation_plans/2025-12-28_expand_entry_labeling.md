# Expand Entry Labeling to All Entry Types

## Summary

Extend the existing task labeling system to support all entry types (Text, Audio, Images,
Workouts, Events). The data structure (`Metadata.labelIds`) is already in place; this plan
covers only the UI integration required to assign and display labels on non-task entries.

## Goals

1. **Events**: Add a label selector in the event header, similar to the task form's approach.
2. **General Entries (Text/Audio/Image)**: Provide label access via the "triple-dot" menu.
3. **Display**: Show assigned labels on a dedicated line under the date header for all entries.
4. **Selector**: Reuse the existing modal (`LabelSelectionModalContent`) with search and checkboxes.
5. **Filtering**: Apply category-based label filtering to all entry types.
6. **Testing**: Achieve 95% test coverage for this patch.

## Non-Goals

- Database migrations or schema changes (data model is complete).
- Reworking the existing task labeling UI.
- AI auto-labeling for non-task entries (future enhancement).
- Label-based filtering in journal views (future enhancement).

## Current Architecture Summary

### Existing Components

| Component | Location | Purpose |
|-----------|----------|---------|
| `LabelSelectionModalContent` | `lib/features/tasks/ui/labels/` | Modal with search + checkbox list for selecting labels |
| `TaskLabelsWrapper` | `lib/features/tasks/ui/labels/` | Displays labels section with header + edit button for tasks |
| `LabelChip` | `lib/features/labels/ui/widgets/` | Renders individual label chips with color dot |
| `InitialModalPageContent` | `lib/features/journal/ui/widgets/entry_details/header/` | Triple-dot menu content for entries |
| `EntryDatetimeWidget` | `lib/features/journal/ui/widgets/entry_details/` | Date header widget for entries |
| `EventForm` | `lib/widgets/events/` | Form for editing event details |
| `availableLabelsForCategoryProvider` | `lib/features/labels/state/` | Riverpod provider for category-scoped labels |
| `filterLabelsForCategory` | `lib/services/entities_cache_service.dart` | Pure function for label filtering |

### Data Flow

```
Entry.meta.labelIds (List<String>)
    → EntitiesCacheService.getLabelById()
    → List<LabelDefinition>
    → LabelChip widgets
```

## Implementation Phases

### Phase 1: Generalize Label Selection Modal

**Current state**: `LabelSelectionModalContent` is hardcoded for `taskId`.

**Changes**:
1. Create a generalized version that accepts `entryId` instead of `taskId`.
2. Move the selector to `lib/features/labels/ui/widgets/` for shared access.
3. Keep `taskId`-specific logic (if any) optional.

**Files to modify/create**:
- `lib/features/labels/ui/widgets/label_selection_modal.dart` (new - generalized modal wrapper)
- `lib/features/labels/ui/widgets/label_selection_modal_content.dart` (new - moved & generalized)

**Backward compatibility**: Update `TaskLabelsWrapper` to use the new generalized component.

### Phase 2: Create Entry Labels Display Widget

**Goal**: Reusable widget to display labels on any entry, positioned under the date header.

**Component**: `EntryLabelsDisplay`

**Features**:
- Takes `entryId` and optional `categoryId` parameters
- Displays wrapped `LabelChip` widgets
- Includes edit button that opens label selector modal
- Handles privacy filtering (respects `showPrivateEntries`)
- Compact design for list views vs expanded for detail views

**Location**: `lib/features/labels/ui/widgets/entry_labels_display.dart`

**Design decisions**:
- **Edit button style**: Pencil icon similar to `TaskLabelsWrapper`
- **Empty state**: Show "No labels" text (not an add button - users access via menu/button)
- **Position**: Below date header in entry detail views

### Phase 3: Triple-Dot Menu Integration (General Entries)

**Goal**: Add "Labels" action item to the extended header modal for non-task entries.

**Target entries**: All non-task entries (`JournalEntry`, `JournalImage`, `JournalAudio`, `JournalEvent`, `WorkoutEntry`, `HealthEntry`, `MeasurementEntry`, `SurveyEntry`)

**Files to modify**:
- `lib/features/journal/ui/widgets/entry_details/header/modern_action_items.dart` - Add `ModernLabelsItem`
- `lib/features/journal/ui/widgets/entry_details/header/initial_modal_page_content.dart` - Include `ModernLabelsItem`

**UI flow**:
1. User taps triple-dot menu → Modal appears
2. User taps "Labels" → Opens `LabelSelectionModal`
3. User selects/deselects labels → Apply saves changes
4. Modal closes → Entry refreshes with updated labels

**Position in menu**: After "Toggle Flagged", before "Copy Entry Text" (visibility/metadata section)

### Phase 4: Event Header Integration

**Goal**: Add label selector to event form header, similar to task form layout.

**Current Event Form Layout** (`lib/widgets/events/event_form.dart`):
```
Title TextField
  ↓
[Category] [Status] [Stars] (Wrap)
  ↓
EditorWidget
```

**Updated Layout**:
```
Title TextField
  ↓
[Category] [Status] [Stars] (Wrap)
  ↓
Labels Section (EntryLabelsDisplay)
  ↓
EditorWidget
```

**Files to modify**:
- `lib/widgets/events/event_form.dart` - Add labels section

### Phase 5: Entry Detail Integration

**Goal**: Display labels in all entry detail views.

**Files to modify**:
- Update entry detail widgets to include `EntryLabelsDisplay` below the header

**Entry detail locations to update**:
1. `lib/features/journal/ui/pages/entry_detail_page.dart` or equivalent layout files
2. Ensure labels appear after `EntryDetailHeader` / `EntryDatetimeWidget`

### Phase 6: Localization

**New strings needed**:
- `entryLabelsHeaderTitle`: "Labels"
- `entryLabelsEditTooltip`: "Edit labels"
- `entryLabelsNoLabels`: "No labels assigned"
- `entryLabelsActionTitle`: "Labels" (for menu item)
- `entryLabelsActionSubtitle`: "Assign labels to organize this entry"

**File**: `lib/l10n/app_en.arb` (and translations)

## Testing Strategy (95% Coverage Target)

### Unit Tests

| Test File | Coverage Target |
|-----------|-----------------|
| `test/features/labels/ui/entry_labels_display_test.dart` | Widget rendering, privacy filtering, tap handlers |
| `test/features/labels/ui/label_selection_modal_test.dart` | Search filtering, selection state, apply/cancel |

### Widget Tests

| Test File | Coverage Target |
|-----------|-----------------|
| `test/features/journal/ui/widgets/entry_details/header/initial_modal_page_content_test.dart` | Labels action visibility, tap navigation |
| `test/widgets/events/event_form_labels_test.dart` | Labels section rendering in event form |
| `test/features/labels/ui/entry_labels_integration_test.dart` | Full flow: open modal → select → apply → display |

### Integration Tests

| Test File | Coverage Target |
|-----------|-----------------|
| `test/features/labels/integration/entry_labeling_workflow_test.dart` | Create entry → assign labels → verify persistence → reload → verify display |

### Edge Cases to Test

1. **Entry with no category**: Global labels only shown
2. **Entry with category**: Global + category-scoped labels shown
3. **Private labels**: Hidden when `showPrivateEntries` is false
4. **Out-of-category labels**: Already assigned labels remain visible but marked
5. **Empty label list**: Graceful handling with "No labels available"
6. **Label creation from modal**: Quick-create flow works
7. **Concurrent label updates**: Optimistic UI + conflict resolution

### Test Helpers Needed

```dart
// test/test_helpers/label_test_helpers.dart
extension LabelTestHelpers on WidgetTester {
  Future<void> openLabelsModal(String entryId) async {...}
  Future<void> selectLabel(String labelName) async {...}
  Future<void> applyLabelSelection() async {...}
  Future<void> openTripleDotMenu() async {...}
}
```

## File Changes Summary

### New Files

| Path | Description |
|------|-------------|
| `lib/features/labels/ui/widgets/entry_labels_display.dart` | Reusable labels display widget |
| `lib/features/labels/ui/widgets/label_selection_modal.dart` | Generalized modal wrapper |
| `test/features/labels/ui/entry_labels_display_test.dart` | Display widget tests |
| `test/features/labels/ui/label_selection_modal_test.dart` | Modal tests |
| `test/features/labels/integration/entry_labeling_workflow_test.dart` | Integration tests |
| `test/widgets/events/event_form_labels_test.dart` | Event form labels tests |

### Modified Files

| Path | Changes |
|------|---------|
| `lib/features/tasks/ui/labels/label_selection_modal_content.dart` | Rename `taskId` → `entryId` |
| `lib/features/tasks/ui/labels/task_labels_wrapper.dart` | Use generalized modal |
| `lib/features/journal/ui/widgets/entry_details/header/initial_modal_page_content.dart` | Add labels action |
| `lib/features/journal/ui/widgets/entry_details/header/modern_action_items.dart` | Add `ModernLabelsItem` |
| `lib/widgets/events/event_form.dart` | Add labels section |
| `lib/l10n/app_en.arb` | Add new strings |

## Verification Steps

### Manual Testing Checklist

- [ ] Text entry: Open triple-dot menu → "Labels" visible → Can assign labels → Labels appear below date
- [ ] Audio entry: Same as above
- [ ] Image entry: Same as above
- [ ] Event: Labels section visible in form → Can edit labels → Labels persist on reload
- [ ] Task: Existing labels UI unchanged and functional
- [ ] Category filtering: Only applicable labels shown in selector
- [ ] Privacy: Private labels hidden when config off
- [ ] Create label: Quick-create from empty state works
- [ ] Long-press: Description tooltip appears on labels

### Automated Verification

```bash
# Run all label-related tests
fvm flutter test test/features/labels/

# Check coverage
fvm flutter test --coverage test/features/labels/
genhtml coverage/lcov.info -o coverage/html
# Verify 95%+ coverage for new files

# Analyzer clean
fvm dart analyze

# Formatter check
fvm dart format --set-exit-if-changed .
```

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Breaking existing task labels | Low | High | Keep backward-compatible, extensive testing |
| Performance with many labels | Low | Medium | Lazy loading, limit displayed chips |
| UI inconsistency | Medium | Low | Follow existing design patterns precisely |
| Missing edge cases | Medium | Medium | Thorough test coverage, manual QA |

## Dependencies

- None external (all infrastructure exists)
- Riverpod 3 patterns for state management
- Existing Wolt modal utilities

## Timeline Markers

- **Phase 1-2**: Core widget development
- **Phase 3-4**: UI integration
- **Phase 5**: Detail view updates
- **Phase 6**: Localization
- **Testing**: Throughout all phases

## Design Decisions (Confirmed)

1. **Event labels position**: Below the Status/Category/Stars row, before the editor
2. **List card labels**: Display on BOTH list cards AND detail views
3. **Entry types scope**: ALL entry types including Workout, Health, Measurement, Survey
4. **Label order**: Alphabetical (consistent with existing task labels)
5. **Mobile vs Desktop**: Responsive wrap layout (same component, natural reflow)

---

*Created: 2025-12-28*
*Status: In Progress*
