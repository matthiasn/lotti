# Categories Redesign — Implementation Plan

> **Figma source:** Lotti DEMO → Mobile → Dark → Categories (node `234:126402`)
> **Branch:** `feat/figma-mcp-integration`

---

## Overview

Redesign the Categories feature UI to match the Figma mockups. The redesign covers
5 screens: Categories List, Edit Category, Add Category, AI Profile Picker, and
Delete Confirmation Dialog. All screens use dark theme styling with updated card
layouts, a new color dot picker, refined icon grid, and an enhanced delete flow
that lets users reassign tasks before deletion.

---

## Phase 1 — Categories List Page

**File:** `lib/features/categories/ui/pages/categories_list_page.dart`

### Design changes (from Figma)

| Element | Current | Target |
|---------|---------|--------|
| Header action | FAB (bottom-right) | "+ Add category" text button in app bar (green) |
| Category tile | Icon circle + name + language subtitle + trailing status icons | Colored dot + name + task count (e.g. "12 tasks") |
| Card style | `ModernBaseCard` | Dark card with rounded corners, subtle border |
| Empty state | Icon + text | Keep, restyle to match theme |
| Search | Text field at top | Keep, restyle if needed |

### Implementation steps

1. Update `CategoriesListPage` app bar: replace FAB with a header text button "+ Add category"
2. Create a new `CategoryListTile` widget that renders:
   - Small filled color circle (category color)
   - Category name (white text, medium weight)
   - Task count subtitle (grey text) — requires a task count query/provider
3. Add a `categoryTaskCountProvider(categoryId)` to fetch task counts per category
4. Update card styling: dark background, rounded corners, consistent padding
5. Remove trailing status icons (private/inactive) from list view — these are edit-mode concerns
6. Keep search/filter and empty state; adjust colors to match Figma

### Tests — `test/features/categories/ui/pages/categories_list_page_test.dart`

| Test | What it verifies |
|------|-----------------|
| renders header with add button | App bar shows "+ Add category" button |
| add button navigates to create | Tapping add button navigates to create route |
| renders category tiles with color dot | Each tile shows colored circle matching category color |
| renders task count per category | Subtitle shows correct count from provider |
| renders empty state when no categories | Empty state widget shown with message |
| search filters categories by name | Typing filters list; clearing restores full list |
| search shows no-results state | Non-matching query shows no-results widget |
| tap category navigates to detail | Tapping tile navigates to edit route with correct ID |
| categories sorted alphabetically | List order matches alphabetical sort |
| error state renders error message | Error from provider shows error widget |
| loading state renders indicator | Loading state shows shimmer/spinner |

### Test — `test/features/categories/state/category_task_count_provider_test.dart`

| Test | What it verifies |
|------|-----------------|
| returns correct count for category | Provider returns number of tasks in category |
| returns zero for empty category | Category with no tasks returns 0 |
| updates when tasks change | Count reacts to task additions/deletions |

---

## Phase 2 — Color Dot Picker

**File:** new `lib/features/categories/ui/widgets/category_color_dot_picker.dart`

### Design changes (from Figma)

Replace the current `flutter_colorpicker` dialog with an inline row of colored
dots. The Figma shows ~16 preset colors in a horizontal wrap.

### Implementation steps

1. Define a `kCategoryColors` list of ~16 preset hex colors matching the Figma palette
2. Create `CategoryColorDotPicker` widget: horizontal `Wrap` of circular color dots
3. Selected dot gets a white border/ring indicator
4. Wire into both create and edit forms, replacing `CategoryColorPicker`
5. Keep `CategoryColorPicker` available for power users who want custom colors (optional — confirm with user)

### Tests — `test/features/categories/ui/widgets/category_color_dot_picker_test.dart`

| Test | What it verifies |
|------|-----------------|
| renders all preset colors | Shows correct number of dots |
| selected color has border indicator | Active color has visual distinction |
| tapping dot calls onColorChanged | Callback fires with correct hex value |
| no selection when initial color is null | No dot highlighted when no color set |
| handles color not in presets | Graceful fallback (closest match or no selection) |

---

## Phase 3 — Edit Category Page

**File:** `lib/features/categories/ui/pages/category_details_page.dart`

### Design changes (from Figma)

| Element | Current | Target |
|---------|---------|--------|
| Color picker | Dialog-based | Inline color dots (Phase 2 widget) |
| Icon picker | 4-col grid | Keep grid, verify icon set matches Figma |
| AI settings | Profile + Template selectors | "AI summaries" toggle + "Smart tagging" toggle + "AI profile" row |
| Delete action | Alert dialog (bottom bar button) | "Delete this category" red link at bottom of scroll view |
| Bottom bar | Delete + Cancel + Save | Cancel + Save only |
| Section headers | Current styling | "AI SETTINGS" label styling per Figma |

### Implementation steps

1. Replace color picker section with `CategoryColorDotPicker`
2. Verify icon grid matches Figma icon set; adjust if needed
3. Restructure AI settings section:
   - "AI summaries" toggle (maps to existing functionality or new field)
   - "Smart tagging" toggle (maps to existing functionality or new field)
   - "AI profile" navigation row showing selected profile name + chevron
4. Move delete action from bottom bar to a "Delete this category" red text link at the scroll bottom
5. Update bottom bar to Cancel + Save only
6. Adjust section header styling to match Figma

### Tests — `test/features/categories/ui/pages/category_details_page_test.dart`

| Test | What it verifies |
|------|-----------------|
| edit mode renders category name | Name field pre-filled with category name |
| edit mode renders color dot picker | Color dots shown, correct one selected |
| edit mode renders icon grid | Icon grid visible with correct selection |
| tapping color dot updates color | Color change reflected in form state |
| tapping icon updates icon | Icon change reflected in form state |
| AI summaries toggle works | Toggle fires correct callback |
| Smart tagging toggle works | Toggle fires correct callback |
| AI profile row shows selected name | Displays current profile name |
| AI profile row navigates on tap | Tapping navigates to profile picker |
| delete link visible at bottom | "Delete this category" link rendered |
| delete link triggers confirmation | Tapping shows delete dialog (Phase 5) |
| save button disabled without changes | Save greyed out when `hasChanges` is false |
| save button enabled with changes | Save active when form modified |
| cancel button discards changes | Cancel navigates back without saving |
| keyboard shortcut Cmd+S saves | Keyboard event triggers save |
| name field validation on empty | Empty name shows validation error |

---

## Phase 4 — Add Category Page

**File:** `lib/features/categories/ui/pages/category_details_page.dart` (create mode)

### Design changes (from Figma)

Same layout as edit mode but with:
- Title "Add category" instead of category name
- Cancel + Save header buttons (instead of bottom bar)
- No delete link
- No AI profile row (or empty default)

### Implementation steps

1. Update create mode header to show "Add category" title with Cancel/Save
2. Ensure color dot picker and icon grid work in create mode
3. AI settings section: show toggles with defaults (off), no profile row until saved
4. Remove bottom bar in create mode; use header buttons

### Tests — `test/features/categories/ui/pages/category_details_page_test.dart` (create mode group)

| Test | What it verifies |
|------|-----------------|
| create mode shows "Add category" title | Header text correct |
| create mode shows Cancel and Save buttons | Both buttons rendered |
| create mode name field empty | Name field starts empty |
| create mode color picker has no selection | No dot pre-selected |
| create mode icon grid has no selection | No icon pre-selected |
| save creates category with entered values | Save calls repository with correct data |
| cancel navigates back | Cancel pops navigation |
| save disabled when name empty | Cannot save without name |

---

## Phase 5 — Delete Confirmation Dialog

**File:** new `lib/features/categories/ui/widgets/category_delete_dialog.dart`

### Design changes (from Figma)

| Element | Current | Target |
|---------|---------|--------|
| Layout | Simple AlertDialog | Custom dialog with warning icon, task count, category reassignment dropdown |
| Content | Generic "are you sure" text | "This category has N tasks. Choose where to move them before deleting." |
| Actions | Cancel + Delete | "Delete and move tasks" (red) + "Cancel" |
| Task reassignment | Not supported | Dropdown to pick target category |

### Implementation steps

1. Create `CategoryDeleteDialog` widget with:
   - Warning icon (exclamation in circle, orange/red)
   - Title: "Delete this category?"
   - Body: "This category has N tasks. Choose where to move them before deleting."
   - Category dropdown (excluding current category) with color dot + name
   - "Delete and move tasks" red button
   - "Cancel" text button
2. Add `moveTasksToCategory(fromId, toId)` method to repository/controller
3. Wire the dialog into the edit page's delete link
4. Handle edge case: category with 0 tasks (skip reassignment UI, just confirm)

### Tests — `test/features/categories/ui/widgets/category_delete_dialog_test.dart`

| Test | What it verifies |
|------|-----------------|
| renders warning icon and title | Visual elements present |
| shows correct task count | "This category has 5 tasks" text |
| renders category dropdown | Dropdown shows other categories |
| dropdown excludes current category | Deleted category not in list |
| delete button calls delete and move | Correct callbacks fired with selected target |
| cancel dismisses dialog | Dialog closed without action |
| zero tasks hides reassignment UI | No dropdown when task count is 0 |
| zero tasks shows simple confirm | Simplified message for empty categories |
| delete button disabled without selection | Must pick target before deleting (when tasks > 0) |

---

## Phase 6 — AI Profile Picker Screen

**File:** already exists as `lib/features/agents/ui/profile_selector.dart` — may need restyling

### Design changes (from Figma)

| Element | Current | Target |
|---------|---------|--------|
| Layout | Modal/bottom sheet | Full page with Back + Save header |
| Profile items | Name only | Name + description + checkmark on selected |
| Default indicator | None | "(Default)" suffix on default profile |

### Implementation steps

1. Evaluate whether the existing `ProfileSelector` can be restyled or if a new
   `CategoryProfilePickerPage` is needed
2. Add profile descriptions to the list items
3. Add checkmark indicator on selected profile
4. Add "(Default)" label where applicable
5. Wire navigation from the edit page's "AI profile" row

### Tests — `test/features/categories/ui/widgets/category_profile_picker_test.dart`

| Test | What it verifies |
|------|-----------------|
| renders all available profiles | List shows all non-desktop-only profiles |
| selected profile has checkmark | Visual indicator on current selection |
| default profile shows label | "(Default)" text on default profile |
| tapping profile selects it | Selection callback fires |
| back button returns to edit page | Navigation pops correctly |
| save button persists selection | Selected profile saved to category |

---

## Cross-cutting Concerns

### Localization

New ARB keys needed (add to all 6 locale files):

- `categoryAddButton` — "+ Add category"
- `categoryTaskCount` — "{count} tasks" (with plural)
- `categoryDeleteTitle` — "Delete this category?" (may already exist)
- `categoryDeleteWithTasks` — "This category has {count} tasks..."
- `categoryDeleteAndMove` — "Delete and move tasks"
- `categoryMoveTasksTo` — "Move tasks to"
- `categoryAiSummaries` — "AI summaries"
- `categoryAiSummariesSubtitle` — "Auto-generated after sessions"
- `categorySmartTagging` — "Smart tagging"
- `categorySmartTaggingSubtitle` — "AI suggests labels & tags"
- `categoryAiProfile` — "AI profile"
- `categoryAiSettings` — "AI SETTINGS"
- `categorySelectColor` — "Select Color"
- `categorySelectIcon` — "Select Icon"

### CHANGELOG

Add entry under current version `0.9.928`:

```markdown
### Changed
- Redesigned Categories list with color dots and task counts
- Redesigned category edit/create forms with inline color picker and updated AI settings
- Enhanced delete flow with task reassignment to another category
```

### Flatpak metainfo

Update `/Users/gbj/StudioProjects/lotti/flatpak/com.matthiasn.lotti.metainfo.xml`
with matching release notes.

---

## Execution Order

```
Phase 1 → Phase 2 → Phase 3 → Phase 4 → Phase 5 → Phase 6
  │          │          │          │          │          │
  │          │          │          │          │          └─ AI profile picker
  │          │          │          │          └─ Delete dialog + task move
  │          │          │          └─ Add category form
  │          │          └─ Edit category form
  │          └─ Color dot picker widget
  └─ Categories list page + task count provider
```

Each phase is independently testable and deployable. Tests are written alongside
implementation within each phase. The analyzer must report zero warnings before
moving to the next phase.

---

## Test Coverage Target

**100% branch coverage** for all new and modified code. Each test file follows
the modular style: one focused test per behavior/branch/edge case. No monolithic
test functions — each `test()` call covers exactly one scenario.

**Test file mapping:**

| Source file | Test file |
|------------|-----------|
| `categories_list_page.dart` | `categories_list_page_test.dart` |
| `category_task_count_provider.dart` | `category_task_count_provider_test.dart` |
| `category_color_dot_picker.dart` | `category_color_dot_picker_test.dart` |
| `category_details_page.dart` | `category_details_page_test.dart` |
| `category_delete_dialog.dart` | `category_delete_dialog_test.dart` |
| `category_profile_picker.dart` | `category_profile_picker_test.dart` |
| `categories_repository.dart` (if modified) | `categories_repository_test.dart` |
| `category_details_controller.dart` (if modified) | `category_details_controller_test.dart` |