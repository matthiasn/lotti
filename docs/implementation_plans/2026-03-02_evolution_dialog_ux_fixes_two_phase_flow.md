# Evolution Review Page UX Fixes + Two-Phase Dialog Flow

**Date**: 2026-03-02
**Status**: Draft
**Branch**: `feat/evolution_dialog`

---

## Problem Statement

Four UX issues on the evolution review page and chat page need addressing:

1. **Nested scrolling**: The review page has a `ListView` (page body) containing a `SizedBox(height: 350)` with another `ListView.builder` (tab content). This creates scroll-in-scroll: only half the page is visible, with an inner scrollbar fighting the outer one.
2. **Expand icons unreachable**: The chevron icons on `FeedbackItemTile` sit at the far right, behind the inner scrollbar, making them untappable.
3. **Reasoning card ugly dark grey**: `ThinkingDisclosure` uses `surfaceContainerHighest` (`#3A3A4C`) which creates an ugly dark grey box inside the already-dark chat bubble (`surfaceDarkElevated` `#2A2A3C`). Needs a subtler treatment.
4. **Missing two-phase dialog flow**: Evolution chat currently jumps straight to a proposal. Instead it should: (a) present insights on what went well/didn't, (b) ask for per-category ratings (1-5 stars), (c) only then propose new directives.

---

## Part A: Review Page Scroll & Tap Fixes

### A1. Remove nested scroll — make tab content fill remaining space

**Problem**: `SizedBox(height: 350)` wrapping `_SentimentItemList` creates a fixed-height nested scroll region.

**Files**:
- `lib/features/agents/ui/evolution/evolution_review_page.dart`
- `lib/features/agents/ui/evolution/widgets/feedback_summary_section.dart`

**Changes**:

#### `evolution_review_page.dart`

Replace `ListView` body with a `Column` + `Expanded`:

```dart
// Before: ListView with all children as scrollable
body: ListView(
  padding: const EdgeInsets.all(16),
  children: [
    // template name, proposal card, section header...
    FeedbackSummarySection(feedback: feedback),
    const SizedBox(height: 80), // FAB spacer
  ],
),

// After: Column where FeedbackSummarySection fills remaining space
body: Padding(
  padding: const EdgeInsets.all(16),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // template name (non-scrollable)
      Text(templateName, ...),
      const SizedBox(height: 20),
      // proposal card (non-scrollable, compact)
      pendingAsync.whenOrNull(...) ?? const SizedBox.shrink(),
      // section header
      _SectionHeader(...),
      const SizedBox(height: 12),
      // Expanded feedback section fills remaining space
      Expanded(
        child: feedbackAsync.when(
          data: (feedback) => feedback == null
              ? _EmptyState(...)
              : FeedbackSummarySection(feedback: feedback),
          loading: () => ...,
          error: (_, __) => ...,
        ),
      ),
    ],
  ),
),
```

- Remove the `SizedBox(height: 80)` FAB spacer (no longer needed)

#### `feedback_summary_section.dart`

Replace `SizedBox(height: 350)` with `Expanded`:

```dart
// Before:
SizedBox(
  height: 350,
  child: _SentimentItemList(...),
),

// After:
Expanded(
  child: _SentimentItemList(...),
),
```

This requires `_SentimentTabView` to be inside a parent that provides bounded height (the `Expanded` in the review page's `Column` does this).

### A2. Fix expand icons tappability

The expand chevron icons on `FeedbackItemTile` are already inside a `GestureDetector` that wraps the entire tile (line 28 of `feedback_item_tile.dart`), so tapping anywhere on the tile toggles expand. The issue is that the inner scrollbar from the nested `SizedBox(height: 350)` overlaps the right edge. Fixing A1 (removing the fixed-height constraint) resolves this — with the tab content filling the page via `Expanded`, the scrollbar is the `ListView.builder`'s own scrollbar which doesn't overlap tile content.

No additional code changes needed beyond A1.

### A3. Update test for removed fixed-height constraint

**File**: `test/features/agents/ui/evolution/widgets/feedback_summary_section_test.dart`

The test "tab content is bounded in a fixed-height container" currently asserts on `SizedBox(height: 350)`. This test needs updating since the `SizedBox(height: 350)` is being removed. Replace it with a test that verifies the tab content is rendered inside an `Expanded` widget.

---

## Part B: Reasoning Card Styling Fix

**File**: `lib/features/ai_chat/ui/widgets/chat_interface/thinking_disclosure.dart`

### Current state (ugly)

```dart
Container(
  decoration: BoxDecoration(
    color: theme.colorScheme.surfaceContainerHighest,  // #3A3A4C — dark grey
    borderRadius: BorderRadius.circular(12),
    border: Border.all(
      color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
    ),
  ),
```

### Proposed change (subtle)

```dart
Container(
  decoration: BoxDecoration(
    color: Colors.white.withValues(alpha: 0.05),  // subtle lift
    borderRadius: BorderRadius.circular(12),
    border: Border.all(
      color: GameyColors.aiCyan.withValues(alpha: 0.15),  // themed border
    ),
  ),
```

This matches the treatment used by the proposal summary card on the review page (`Colors.white.withValues(alpha: 0.05)`), creating visual consistency.

### Localize hardcoded strings

While in this file, localize these hardcoded strings:
- `'Hide reasoning'` / `'Show reasoning'` → `context.messages.thinkingDisclosureHide` / `context.messages.thinkingDisclosureShow`
- `'Copy reasoning'` tooltip → `context.messages.thinkingDisclosureCopy`
- `'Reasoning copied'` snackbar → `context.messages.thinkingDisclosureCopied`
- `'Reasoning section, expanded/collapsed'` semantics label → `context.messages.thinkingDisclosureSemantics`

Add to all 5 arb files (`app_en.arb`, `app_de.arb`, `app_es.arb`, `app_fr.arb`, `app_ro.arb`).

---

## Part C: Two-Phase Dialog Flow

### C1. Update system prompts

#### `evolution_context_builder.dart` — `_buildSystemPrompt()`

**Remove**:
```text
- NEVER end a turn without having called `propose_directives` at least once in
  the session, unless you are responding to a rejection with a refined proposal.
```

And the line:
```text
- **propose_directives**: ... You MUST call this tool in your first response.
```

**Replace with two-phase instructions**:

```text
## Workflow — Two Phases

### Phase 1: Insights & Category Ratings
In your first response:
1. **Analyze** (2-3 paragraphs): Share clear insights about what went well and
   what didn't, based on the feedback signals and performance data.
2. **Record notes**: Use `record_evolution_note` to capture observations.
3. **Request ratings**: Use `render_surface` with `CategoryRatings` widget to
   ask the user to rate each feedback category (1-5 stars). Categories:
   accuracy, communication, prioritization, tooling, timeliness, general.
4. Do NOT call `propose_directives` yet — wait for the user's ratings.

### Phase 2: Proposal
After receiving the user's category ratings:
1. Incorporate the ratings alongside the feedback signals to weight your
   proposal toward the categories the user rated lowest.
2. Use `propose_directives` to formally propose improved directives.
```

#### `_buildUserMessage()` — closing line

**Replace**:
```text
Review this data, record any evolution notes, and then propose improved
directives using the `propose_directives` tool.
```

**With**:
```text
Review this data and share your insights about what's working and what isn't.
Record any evolution notes, then ask me for category ratings before proposing
directive changes.
```

#### `ritual_context_builder.dart`

Apply analogous two-phase changes to both `_buildRitualSystemPrompt()` and `_buildMetaRitualSystemPrompt()`.

For `_buildRitualSystemPrompt()`:
- In the Workflow section, split step 4 into two phases
- Phase 1: present feedback summary, ask questions, request category ratings
- Phase 2: incorporate ratings and propose directives

For `_buildMetaRitualSystemPrompt()`:
- Similar split: meta-analysis + ratings request in Phase 1, proposal in Phase 2

### C2. Add `CategoryRatings` GenUI widget

**File**: `lib/features/agents/genui/evolution_catalog.dart`

Add a new `CatalogItem` for `CategoryRatings`:

**Schema**:
```dart
final _categoryRatingsSchema = S.object(
  properties: {
    'categories': S.list(
      items: S.object(
        properties: {
          'name': S.string(description: 'Category identifier (e.g., accuracy)'),
          'label': S.string(description: 'Display label for the category'),
        },
        required: ['name', 'label'],
      ),
      description: 'Categories to rate',
    ),
  },
  required: ['categories'],
);
```

**Widget**: A stateful card with one row per category showing:
- Category label
- 5 tappable star icons (filled/unfilled based on current rating)

**Submit button**: Dispatches `UserActionEvent` with:
- `name: 'ratings_submitted'`
- `sourceComponentId`: JSON-encoded map of `{categoryName: ratingValue}`
- `surfaceId`: the surface ID from the item context

**Registration**: Add `categoryRatingsItem` to `buildEvolutionCatalog()` list.

### C3. Register in GenUI bridge

**File**: `lib/features/agents/genui/genui_bridge.dart`

- Add `'CategoryRatings'` to `supportedRootTypes` set (line 83)
- Add `'CategoryRatings'` to the `'enum'` list in `toolDefinition` parameters (line 53-58)
- Update the tool `description` string to mention `CategoryRatings`

### C4. Handle ratings event

**File**: `lib/features/agents/genui/genui_event_handler.dart`

Add a new callback:
```dart
void Function(String surfaceId, Map<String, int> ratings)? onRatingsSubmitted;
```

In `_handleEvent`, add handling for `name == 'ratings_submitted'`:
```dart
if (name == 'ratings_submitted') {
  final ratingsJson = action.sourceComponentId;
  // Parse JSON string to Map<String, int>
  final decoded = jsonDecode(ratingsJson);
  if (decoded is Map<String, dynamic>) {
    final ratings = decoded.map(
      (k, v) => MapEntry(k, v is num ? v.toInt() : 0),
    );
    onRatingsSubmitted?.call(action.surfaceId, ratings);
  }
}
```

### C5. Wire ratings in chat state

**File**: `lib/features/agents/ui/evolution/evolution_chat_state.dart`

Wire `eventHandler.onRatingsSubmitted` in `build()` alongside the existing `onProposalAction` wiring:

```dart
session.eventHandler?.onRatingsSubmitted = (surfaceId, ratings) {
  _handleRatingsSubmitted(ratings);
};
```

`_handleRatingsSubmitted(Map<String, int> ratings)`:
1. Format ratings into a user message string: `"My category ratings: accuracy: 4/5, communication: 3/5, ..."`
2. Call `sendMessage()` with this formatted string so the LLM receives the ratings and can proceed to Phase 2

Clean up in `ref.onDispose`:
```dart
session.eventHandler?.onRatingsSubmitted = null;
```

---

## Localization

### New arb keys

| Key | EN | DE | ES | FR | RO |
|-----|----|----|----|----|-----|
| `thinkingDisclosureShow` | Show reasoning | Begründung anzeigen | Mostrar razonamiento | Afficher le raisonnement | Afișează raționamentul |
| `thinkingDisclosureHide` | Hide reasoning | Begründung ausblenden | Ocultar razonamiento | Masquer le raisonnement | Ascunde raționamentul |
| `thinkingDisclosureCopy` | Copy reasoning | Begründung kopieren | Copiar razonamiento | Copier le raisonnement | Copiază raționamentul |
| `thinkingDisclosureCopied` | Reasoning copied | Begründung kopiert | Razonamiento copiado | Raisonnement copié | Raționament copiat |
| `agentCategoryRatingsTitle` | Rate Categories | Kategorien bewerten | Calificar categorías | Évaluer les catégories | Evaluează categoriile |
| `agentCategoryRatingsSubmit` | Submit Ratings | Bewertungen absenden | Enviar calificaciones | Envoyer les évaluations | Trimite evaluările |

---

## Testing

### Updated tests

1. **`feedback_summary_section_test.dart`**: Update "tab content is bounded in a fixed-height container" test to verify `Expanded` instead of `SizedBox(height: 350)`.
2. **`evolution_review_page_test.dart`**: Tests should still pass as the page structure change is internal (Column vs ListView). May need to switch `makeTestableWidgetNoScroll` usage since the page body is no longer scrollable via `ListView`.

### New tests

3. **CategoryRatings widget test**: Verify the widget renders star rows for each category, tapping updates the rating, and submit dispatches the correct event.
4. **GenUI event handler test**: Verify `onRatingsSubmitted` callback is invoked with correct parsed ratings when a `ratings_submitted` event arrives.

### Verification checklist

1. `dart_fix`, `dart_format`, `analyze_files` — all green
2. Run `test/features/agents/ui/evolution/evolution_review_page_test.dart`
3. Run `test/features/agents/ui/evolution/widgets/feedback_summary_section_test.dart`
4. Run `test/features/agents/ui/evolution/` (full folder)
5. Run `test/features/agents/` (full agent test suite)
6. Manual: open evolution review page, verify tab fills page, no nested scroll, chevrons tappable
7. Manual: open evolution chat, verify reasoning disclosure styling is subtle, not ugly grey box
8. Manual: start evolution session, verify LLM shares insights first, shows category ratings widget, then proposes after ratings submitted

---

## Implementation Order

1. **Part B** (ThinkingDisclosure styling + localization) — smallest, self-contained
2. **Part A** (Scroll fix) — medium, affects layout but straightforward
3. **Part C1** (System prompt changes) — text-only, no widget changes
4. **Part C2** (CategoryRatings widget) — new GenUI catalog item
5. **Part C3** (GenUI bridge registration) — small wiring change
6. **Part C4** (Event handler) — small addition
7. **Part C5** (Chat state wiring) — connects everything together
8. **Tests** — update existing + add new throughout

---

## Risk Assessment

- **Part A**: Low risk. The `Expanded` approach requires the parent `Column` to have bounded height (provided by `Scaffold`'s body). If any intermediate widget doesn't pass down the constraint, the `Expanded` will fail at runtime with an unbounded height error.
- **Part B**: Very low risk. Cosmetic change only.
- **Part C**: Medium risk. The two-phase flow depends on the LLM following the updated system prompt. If the LLM ignores the instruction and calls `propose_directives` immediately, the user will still get a proposal — just without the ratings step. This is a graceful degradation, not a failure.
