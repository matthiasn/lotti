# Label Creation — Substring Match UX Improvement (2025-11-16)

Refers to and builds on: `docs/implementation_plans/2025-10-26_task_labels_system.md` and
`docs/implementation_plans/2025-10-31_task_labels_applicable_categories.md`.

## Summary

- Improve the label creation UX in the label selection modal to allow creating new labels even when
  there are substring matches with existing labels.
- Currently, if a user types "CI" and there's an existing label "dependencies" (which contains "
  CI"), the option to create a new "CI" label is hidden because the filtered results are not empty.
- The improved behavior should only hide the creation option when there's an exact match (
  case-insensitive) with an existing label.
- This change enhances discoverability and reduces friction in the label creation workflow,
  particularly for short label names that might appear as substrings in longer label names.

## Goals

- Allow users to create a new label when their search query is a substring match of existing labels,
  as long as it's not an exact match.
- Improve the label creation UX by making the "Create label" option more consistently available when
  appropriate.
- Maintain existing behavior of hiding the creation option only when there's an exact match with an
  existing label.
- Keep analyzer/tests green, add comprehensive test coverage for the new behavior.
- Reference the checklist improvements from `2025-11-11_checklist_creation_current_entry_default.md`
  for similar UX patterns.

## Non-Goals

- Changing the search/filter logic itself (substring matching remains unchanged).
- Modifying the label creation flow or editor sheet.
- Adding fuzzy matching or advanced search capabilities.
- Changing category-scoped label filtering behavior.

## Problem Statement

### Current Behavior

In `lib/features/tasks/ui/labels/label_selection_modal_content.dart:100-107`, the logic for showing
the create button is:

```dart
if (filtered.isEmpty) {
final hasQuery = _searchRaw.trim().isNotEmpty;
return _EmptyState(
isSearching: hasQuery,
searchQuery: hasQuery ? _searchRaw.trim() : null,
onCreateLabel: () => _openLabelCreator(defaultName: _searchRaw.trim()),
);
}
```

This means the "Create label" option is only shown when `filtered.isEmpty` (no labels match the
search query at all).

### Issue

When a user types "CI" to create a new label:

1. The search filters labels by name/description containing "CI" (case-insensitive substring match)
2. "dependencies" appears in results because it contains "CI"
3. `filtered` is NOT empty, so the empty state is not shown
4. No "Create label" option is available, even though "CI" doesn't exactly match any existing label

### Expected Behavior

The "Create label" option should be available whenever there's no exact match (case-insensitive),
regardless of substring matches. In the example above:

- User types "CI"
- "dependencies" is shown in the filtered list (substring match)
- "Create 'CI' label" button is ALSO shown (no exact match exists)
- User can choose to select "dependencies" or create a new "CI" label

## Design Overview

### Approach

Rather than relying solely on `filtered.isEmpty`, we need to:

1. Check if there's an exact match (case-insensitive) between the search query and any existing
   label name
2. Show the "Create label" option when:
  - No labels match the search (current behavior), OR
  - Labels match the search but none are exact matches (new behavior)

### UI Patterns

Two possible UI approaches:

**Option A: Inline Create Button (Recommended)**

- Show filtered labels as usual
- Add a "Create 'X' label" button at the bottom of the list when no exact match exists
- Similar to the checklist creation pattern from
  `2025-11-11_checklist_creation_current_entry_default.md`

**Option B: Sticky Create Button**

- Show filtered labels as usual
- Add a sticky "Create 'X' label" button at the top or bottom that appears when no exact match
  exists
- Always visible when search query is present and no exact match

For this implementation, we'll use **Option A** (inline at bottom of list) to minimize layout
complexity and align with existing patterns.

### Implementation Strategy

1. Add a helper function to check for exact match:
   ```dart
   bool _hasExactMatch(List<LabelDefinition> labels, String query) {
     final queryLower = query.trim().toLowerCase();
     return labels.any((label) => label.name.toLowerCase() == queryLower);
   }
   ```

2. Update the build logic to show create button when appropriate:
   ```dart
   Widget _buildList(BuildContext context, List<LabelDefinition> labels) {
     final result = buildSelectorLabelList(...);
     final filtered = result.items;
     final hasQuery = _searchRaw.trim().isNotEmpty;
     final hasExactMatch = hasQuery && _hasExactMatch(filtered, _searchRaw);

     // Show empty state only when truly empty
     if (filtered.isEmpty) {
       return _EmptyState(...);
     }

     // Build the list with optional create button
     return Column(
       children: [
         ListView.separated(...), // existing filtered list
         if (hasQuery && !hasExactMatch)
           _CreateLabelButton(
             searchQuery: _searchRaw.trim(),
             onCreateLabel: () => _openLabelCreator(defaultName: _searchRaw.trim()),
           ),
       ],
     );
   }
   ```

3. Create a new `_CreateLabelButton` widget for consistent styling

## Data/Code Touchpoints

- Main implementation: `lib/features/tasks/ui/labels/label_selection_modal_content.dart`
  - `_buildList` method (lines 83-151): add exact match check and conditional create button
  - Add `_hasExactMatch` helper method
  - Add `_CreateLabelButton` widget for the inline create button
- Tests: `test/features/tasks/ui/labels/label_selection_modal_content_test.dart`
  - Add test cases for substring match scenarios
  - Verify create button appears when query has substring matches but no exact match
  - Verify create button is hidden when exact match exists
  - Verify create button is hidden when query is empty

## Implementation Plan

### Phase 1 — Core Logic

- [x] Add `_hasExactMatch` helper method to `LabelSelectionModalContent`
  - Takes list of labels and search query
  - Returns true if any label name matches query exactly (case-insensitive, trimmed)
- [x] Add `_CreateButton` widget (renamed from `_CreateLabelButton` after initial implementation)
  - Accept `searchQuery` and `onCreateLabel` callback
  - Style consistently with existing `_EmptyState` button (`FilledButton.icon`)
  - Include icon (Icons.add) and text "Create 'X' label"
  - Centered, not full-width (wrapped in `Center` widget)
- [x] Update `_buildList` method
  - Calculate `hasExactMatch` alongside existing `filtered` results
  - Return `Column` containing both the filtered list and conditional create button
  - Removed `crossAxisAlignment: CrossAxisAlignment.stretch` to prevent full-width button

### Phase 2 — Testing

- [x] Add widget tests for new behavior:
  - Test: substring match shows create button ✓
  - Test: exact match hides create button (same case) ✓
  - Test: exact match hides create button (different case) ✓
  - Test: multiple substring matches still show create button ✓
  - Test: empty query hides create button ✓
  - Test: whitespace-only query hides create button ✓
  - Test: create button tap opens editor with prefilled name ✓
  - Test: category scoping compatibility ✓

### Phase 3 — Polish & Documentation

- [x] Run analyzer and formatter
- [x] Verify all tests pass (35 tests)
- [x] Update `CHANGELOG.md` with UX improvement note
- [x] Removed "A new label will be prefilled with..." hint text from `_EmptyState`
  - Determined to be redundant/obvious (user feedback)
  - Removed corresponding test

### Implementation Notes

**Deviations from original plan:**
1. Initial implementation created a `_CreateLabelButton` with `FilledButton.tonalIcon` (wrong styling) - corrected to `FilledButton.icon` to match existing `_EmptyState` button
2. Removed unnecessary divider above button
3. Removed hint text about prefilling (not in original plan, but removed based on user feedback for cleaner UI)
4. Widget renamed to `_CreateButton` for simplicity

**Final implementation:**
- `_hasExactMatch()` helper method for exact match detection
- Exact match check performed against ALL labels (via `labelsStreamProvider`), not just category-filtered labels, to prevent duplicate label names across categories
- `_CreateButton` widget matching `_EmptyState` styling exactly
- Centered button (not full-width) using `Center` wrapper
- Clean UI without redundant hint text

## Testing Strategy

### Unit Tests

- Helper method `_hasExactMatch`:
  - Empty list returns false
  - No match returns false
  - Exact match (same case) returns true
  - Exact match (different case) returns true
  - Substring match only returns false
  - Whitespace handling (trimmed query)

### Widget Tests

Cover the following scenarios in `label_selection_modal_content_test.dart`:

1. **Substring match with no exact match**
  - Setup: Label "dependencies" exists
  - Action: Search for "CI"
  - Expected: "dependencies" shown in list + "Create 'CI' label" button visible

2. **Exact match exists (same case)**
  - Setup: Label "CI" exists
  - Action: Search for "CI"
  - Expected: "CI" shown in list + no create button

3. **Exact match exists (different case)**
  - Setup: Label "CI" exists
  - Action: Search for "ci"
  - Expected: "CI" shown in list + no create button

4. **Multiple substring matches**
  - Setup: Labels "dependencies", "continuous integration" exist
  - Action: Search for "CI"
  - Expected: Both labels shown + "Create 'CI' label" button visible

5. **No matches (empty results)**
  - Setup: No labels match
  - Action: Search for "nonexistent"
  - Expected: Empty state with create button (existing behavior, unchanged)

6. **Empty query**
  - Setup: Any labels exist
  - Action: Search query is ""
  - Expected: All labels shown + no create button

7. **Create button interaction**
  - Setup: Substring match scenario
  - Action: Tap "Create 'CI' label" button
  - Expected: LabelEditorSheet opens with "CI" as initialName

8. **Category scoping still works**
  - Setup: Category-scoped labels, substring match scenario
  - Action: Search with no exact match
  - Expected: Scoped labels shown + create button visible

### Integration Tests

- End-to-end: search → no exact match → tap create → create label → verify new label appears in
  filtered list with exact match → create button now hidden

## UI/UX Details

### Create Button Styling

The `_CreateButton` widget (final implementation):

- Uses `FilledButton.icon` to match `_EmptyState` button styling (green filled button)
- Includes `Icons.add` icon
- Text: "Create '{query}' label"
- Centered (not full-width) via `Center` wrapper
- Padding: `EdgeInsets.all(16)`
- No divider (cleaner visual separation)

### Layout Considerations

When the create button is shown with filtered results:

- ListView shows filtered labels (scrollable if needed)
- Divider (subtle, using `Theme.of(context).colorScheme.outline.withValues(alpha: 0.12)`)
- Create button (fixed at bottom, not scrollable)
- No gap between last list item and button (divider provides visual separation)

### Accessibility

- Create button must have proper semantics label: "Create {query} label"
- Screen reader should announce both the filtered results count and the create button availability
- Keyboard navigation should work: tab through list items, then to create button

## Risks & Mitigations

- **Visual clutter with many substring matches**: Mitigated by showing create button below the list,
  clearly separated by a divider.
- **Confusion between selecting existing vs creating new**: Mitigated by clear button text "Create '
  X' label" and icon.
- **Performance with large label sets**: No impact; exact match check is O(n) on already-filtered
  list which is typically small.
- **Whitespace edge cases**: Mitigated by trimming query before comparison, following existing
  patterns.

## Decisions

1. Create button placement: Bottom (after filtered list) to maintain focus on existing options
   first, similar to search patterns.
2. No hint text near the create button; the button text "Create 'X' label" is self-explanatory.
3. Divider styling: Use the same divider style as between list items for consistency.

## Acceptance Criteria

- [x] When search query has substring matches but no exact match, "Create 'X' label" button is shown
  below the filtered list (centered, not full-width)
- [x] When search query has an exact match (case-insensitive), create button is hidden
- [x] When search query is empty or whitespace-only, create button is hidden
- [x] Tapping create button opens label editor with query prefilled as name
- [x] All existing tests pass (35 tests)
- [x] New widget tests cover all scenarios (substring match, exact match, empty query, etc.)
- [x] Analyzer and formatter run cleanly
- [x] Button styling matches `_EmptyState` button (green `FilledButton.icon`)
- [x] No redundant hint text shown
- [x] CHANGELOG.md updated

## Related Work

- Labels system: `docs/implementation_plans/2025-10-26_task_labels_system.md`
- Category-scoped labels:
  `docs/implementation_plans/2025-10-31_task_labels_applicable_categories.md`
- Checklist creation UX patterns:
  `docs/implementation_plans/2025-11-11_checklist_creation_current_entry_default.md`

## Rollout

- No feature flag needed (minor UX improvement)
- No data migration required
- Launch behind green tests and analyzer
- QA: verify on desktop and mobile with various label sets and search queries
