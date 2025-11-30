# Checklist Item Correction Examples per Category

## Summary

Track user corrections to checklist item titles per category. When a user manually edits a checklist
item's title (via keyboard), capture the before/after pair as a "bad example" / "good example" and
store it on the category. Provide these correction examples to the AI during checklist item
creation/updates to improve accuracy based on user-provided context.

## Goals

- Capture manual corrections to checklist item titles as bad/good example pairs
- Store correction examples per category (synced automatically via existing category sync)
- Display and manage examples in category settings UI (list with swipe-to-delete)
- Inject examples into AI prompts for checklist operations
- Improve AI accuracy through user-driven context engineering

## Prior Work & References

This feature follows patterns established in recent implementations:

- **Speech Dictionary (bbeea7141)**: Nearly identical pattern—stores per-category terms in
  `CategoryDefinition`, injects via `{{speech_dictionary}}` placeholder in USER message, displays
  in category settings. See `docs/implementation_plans/2025-11-30_speech_dictionary_per_category.md`
- **Checklist Item Update Function (2025-11-29)**: Shows how the AI updates existing items including
  title corrections. See `docs/implementation_plans/2025-11-29_checklist_item_update_function.md`
- **Checklist Updates Prompt**: The `checklistUpdatesPrompt` in `preconfigured_prompts.dart` already
  includes guidance for title corrections (e.g., "mac OS" → "macOS")

## Problem Examples

Users repeatedly correct the same transcription/spelling errors:

- "test flight" → "TestFlight"
- "flat hub" → "Flathub"
- "mac OS" or "MAC OS" → "macOS"
- "git hub" → "GitHub"
- "i phone" → "iPhone"
- Project-specific terminology, names, etc.

Currently, the AI has hardcoded examples in the prompt. This feature allows user-specific examples
to accumulate over time, driven by actual corrections rather than prompt engineering.

## Proposed Data Model

### New Type: `ChecklistCorrectionExample`

Add to `lib/classes/entity_definitions.dart`:

```dart
@freezed
abstract class ChecklistCorrectionExample with _$ChecklistCorrectionExample {
  const factory ChecklistCorrectionExample({
    required String before,  // The original (bad) text
    required String after,   // The corrected (good) text
    DateTime? capturedAt,    // When this correction was captured (optional metadata)
  }) = _ChecklistCorrectionExample;

  factory ChecklistCorrectionExample.fromJson(Map<String, dynamic> json) =>
      _$ChecklistCorrectionExampleFromJson(json);
}
```

### Updated `CategoryDefinition`

Add a new optional field to `CategoryDefinition` in `lib/classes/entity_definitions.dart`:

```dart
const factory EntityDefinition.categoryDefinition({
  // ... existing fields ...
  List<String>? speechDictionary,
  List<ChecklistCorrectionExample>? correctionExamples, // NEW
}) = CategoryDefinition;
```

**Storage Format**: Array of objects, where each object has `before` and `after` string fields.

**Rationale for Named Keys over Tuples**:
- Clear semantics: `before`/`after` is more readable than positional indices
- JSON-friendly serialization
- Future extensibility (e.g., add `capturedAt`, `count`, `category` metadata)
- Matches existing patterns in the codebase

**Sync**: Examples sync automatically as part of `CategoryDefinition` via existing sync
infrastructure (last-write-wins, no vector clock conflict resolution currently).

## Proposed Architecture

### 1. Data Layer Changes

**File: `lib/classes/entity_definitions.dart`**

- Add `ChecklistCorrectionExample` freezed class
- Add `List<ChecklistCorrectionExample>? correctionExamples` to `CategoryDefinition`
- Run `build_runner` to regenerate freezed classes

**File: `lib/database/conversions.dart`**

- No changes needed (full object is JSON-serialized in `serialized` column)

### 2. Correction Capture Logic

**Key Insight**: The `ChecklistItemController.updateTitle(String? title)` method in
`lib/features/tasks/state/checklist_item_controller.dart` is called when the user edits a
checklist item's title. This is the integration point.

**Category ID Access**: Checklist items already carry `meta.categoryId` (set during creation in
`ChecklistRepository.createChecklistItem()` at line 169). The controller can access it via
`current.meta.categoryId` or the extension `current.categoryId`. No task lookup needed.

**Async Handling**: Since `updateTitle()` is `void` and used as a synchronous UI callback in
`ChecklistItemWrapper` (line 125: `onTitleChange: ref.read(provider.notifier).updateTitle`), we
must use `unawaited()` for fire-and-forget async capture to avoid breaking the UI contract.

**Normalization**: Reuse `LottiChecklistUpdateHandler.normalizeWhitespace` from
`lib/features/ai/functions/lotti_checklist_update_handler.dart` (lines 196-198) for consistency
with AI-driven updates. Do NOT create a divergent `_normalize` implementation.

**New Service: `lib/features/checklist/services/correction_capture_service.dart`**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/ai/functions/lotti_checklist_update_handler.dart';
import 'package:lotti/features/categories/repository/categories_repository.dart';

/// Provider for correction capture service.
final correctionCaptureServiceProvider = Provider<CorrectionCaptureService>((ref) {
  return CorrectionCaptureService(
    categoryRepository: ref.watch(categoryRepositoryProvider),
  );
});

/// Service for capturing user corrections to checklist item titles.
/// Follows the pattern established by SpeechDictionaryService.
class CorrectionCaptureService {
  CorrectionCaptureService({
    required this.categoryRepository,
  });

  final CategoryRepository categoryRepository;

  /// Captures a correction if the before and after texts differ meaningfully.
  /// Returns a result enum indicating success or the reason for skipping.
  Future<CorrectionCaptureResult> captureCorrection({
    required String? categoryId,
    required String beforeText,
    required String afterText,
  }) async {
    // Skip if no category
    if (categoryId == null) return CorrectionCaptureResult.noCategory;

    // Reuse existing normalization logic for consistency with AI updates
    final normalizedBefore = LottiChecklistUpdateHandler.normalizeWhitespace(beforeText);
    final normalizedAfter = LottiChecklistUpdateHandler.normalizeWhitespace(afterText);

    // Skip if texts are identical after normalization
    if (normalizedBefore == normalizedAfter) {
      return CorrectionCaptureResult.noChange;
    }

    // Skip trivial changes (pure whitespace, case-only for very short texts)
    if (!_isMeaningfulCorrection(normalizedBefore, normalizedAfter)) {
      return CorrectionCaptureResult.trivialChange;
    }

    // Get current category
    final category = await categoryRepository.getCategoryById(categoryId);
    if (category == null) return CorrectionCaptureResult.categoryNotFound;

    // Check for duplicates (same before/after pair already exists)
    final existingExamples = category.correctionExamples ?? [];
    if (_isDuplicate(existingExamples, normalizedBefore, normalizedAfter)) {
      return CorrectionCaptureResult.duplicate;
    }

    // Add the correction example
    final newExample = ChecklistCorrectionExample(
      before: normalizedBefore,
      after: normalizedAfter,
      capturedAt: DateTime.now(),
    );

    final updatedExamples = [...existingExamples, newExample];

    // Update the category
    try {
      await categoryRepository.updateCategory(
        category.copyWith(correctionExamples: updatedExamples),
      );
    } on Exception {
      return CorrectionCaptureResult.saveFailed;
    }

    return CorrectionCaptureResult.success;
  }

  bool _isMeaningfulCorrection(String before, String after) {
    // Skip if only case changes for very short texts (< 3 chars)
    if (before.length < 3 && before.toLowerCase() == after.toLowerCase()) {
      return false;
    }
    return true;
  }

  bool _isDuplicate(
    List<ChecklistCorrectionExample> existing,
    String before,
    String after,
  ) {
    return existing.any(
      (e) => e.before == before && e.after == after,
    );
  }
}

/// Result of attempting to capture a correction.
enum CorrectionCaptureResult {
  success,
  noCategory,
  noChange,
  trivialChange,
  duplicate,
  categoryNotFound,
  saveFailed,
}
```

**Integration Point: `lib/features/tasks/state/checklist_item_controller.dart`**

Modify `updateTitle()` to capture corrections using fire-and-forget:

```dart
import 'dart:async' show unawaited;
import 'package:lotti/features/checklist/services/correction_capture_service.dart';

void updateTitle(String? title) {
  final current = state.value;
  final data = current?.data;
  if (current != null && data != null && title != null) {
    final oldTitle = data.title;
    final categoryId = current.meta.categoryId; // Already available on checklist items!

    // Fire-and-forget capture (doesn't block UI callback)
    unawaited(
      ref.read(correctionCaptureServiceProvider).captureCorrection(
        categoryId: categoryId,
        beforeText: oldTitle,
        afterText: title,
      ),
    );

    // Existing update logic continues synchronously...
    final updated = current.copyWith(
      data: data.copyWith(title: title),
    );

    ref.read(checklistRepositoryProvider).updateChecklistItem(
      checklistItemId: id,
      data: updated.data,
      taskId: taskId,
    );

    state = AsyncData(updated);
  }
}
```

**Note**: This approach keeps the UI callback synchronous while allowing async capture to happen
in the background. The fire-and-forget pattern is acceptable here because:
- Capture is best-effort (not critical path)
- Failures are logged but don't affect the user
- The existing `updateTitle` behavior is preserved

### 3. Prompt Integration

**CRITICAL**: The placeholder must be in the USER message, NOT the system message.
`PromptBuilderHelper.buildSystemMessageWithData()` does NOT process placeholders (it simply returns
the raw message). Only `buildPromptWithData()` handles placeholder substitution. This matches the
pattern used for `{{speech_dictionary}}`.

**File: `lib/features/ai/util/preconfigured_prompts.dart`**

Add `{{correction_examples}}` placeholder to `checklistUpdatesPrompt` USER message (after the
directive reminder, before the REMEMBER section):

```dart
const checklistUpdatesPrompt = PreconfiguredPrompt(
  // ...
  userMessage: '''
Create checklist updates based on the context below.
...

Directive reminder:
...

{{correction_examples}}

REMEMBER:
...
''',
);
```

**File: `lib/features/ai/helpers/prompt_builder_helper.dart`**

Add handler for `{{correction_examples}}` placeholder (similar to `{{speech_dictionary}}`):

```dart
// Inject correction examples if requested (from task's category)
if (prompt.contains('{{correction_examples}}') &&
    promptConfig.aiResponseType == AiResponseType.checklistUpdates) {
  String examplesText;
  try {
    examplesText = await _buildCorrectionExamplesPromptText(entity);
  } catch (error, stackTrace) {
    _logPlaceholderFailure(
      entity: entity,
      placeholder: 'correction_examples',
      error: error,
      stackTrace: stackTrace,
    );
    examplesText = '';
  }
  prompt = prompt.replaceAll('{{correction_examples}}', examplesText);
}
```

**Template for Injected Text**:

```dart
const String _kCorrectionExamplesPromptTemplate = '''
USER-PROVIDED CORRECTION EXAMPLES:
The user has manually corrected these checklist item titles in the past.
When creating or updating items, apply these corrections when you see matching patterns.

{examples}
''';
```

**Example Output**:

```
USER-PROVIDED CORRECTION EXAMPLES:
The user has manually corrected these checklist item titles in the past.
When creating or updating items, apply these corrections when you see matching patterns.

- "test flight" → "TestFlight"
- "flat hub" → "Flathub"
- "mac OS" → "macOS"
```

### 4. Category Settings UI

**File: `lib/features/categories/ui/pages/category_details_page.dart`**

Add new `LottiFormSection` after the Speech Dictionary section:

```dart
// Correction Examples Section
LottiFormSection(
  title: context.messages.correctionExamplesSectionTitle,
  icon: Icons.auto_fix_high_outlined,
  description: context.messages.correctionExamplesSectionDescription,
  children: [
    _buildCorrectionExamples(category),
  ],
),
```

**New Widget: `lib/features/categories/ui/widgets/category_correction_examples.dart`**

```dart
class CategoryCorrectionExamples extends StatelessWidget {
  const CategoryCorrectionExamples({
    required this.examples,
    required this.onDelete,
    super.key,
  });

  final List<ChecklistCorrectionExample>? examples;
  final ValueChanged<int> onDelete;

  @override
  Widget build(BuildContext context) {
    final items = examples ?? [];

    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          context.messages.correctionExamplesEmpty,
          style: context.textTheme.bodyMedium?.copyWith(
            color: context.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final example = items[index];
        return Dismissible(
          key: Key('${example.before}-${example.after}'),
          direction: DismissDirection.endToStart,
          background: _buildDeleteBackground(context),
          onDismissed: (_) => onDelete(index),
          child: ListTile(
            leading: Icon(
              Icons.compare_arrows,
              color: context.colorScheme.primary,
            ),
            title: Row(
              children: [
                Flexible(
                  child: Text(
                    '"${example.before}"',
                    style: TextStyle(
                      decoration: TextDecoration.lineThrough,
                      color: context.colorScheme.error,
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(Icons.arrow_forward, size: 16),
                ),
                Flexible(
                  child: Text(
                    '"${example.after}"',
                    style: TextStyle(
                      color: context.colorScheme.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            subtitle: example.capturedAt != null
                ? Text(
                    DateFormat.yMMMd().format(example.capturedAt!),
                    style: context.textTheme.bodySmall,
                  )
                : null,
          ),
        );
      },
    );
  }

  Widget _buildDeleteBackground(BuildContext context) {
    return Container(
      color: context.colorScheme.error,
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 16),
      child: const Icon(Icons.delete, color: Colors.white),
    );
  }
}
```

### 5. State Management

**File: `lib/features/categories/state/category_details_controller.dart`**

Add method for updating correction examples:

```dart
void updateCorrectionExamples(List<ChecklistCorrectionExample> examples) {
  if (_pendingCategory == null) return;

  _pendingCategory = _pendingCategory!.copyWith(
    correctionExamples: examples.isEmpty ? null : examples,
  );

  state = state.copyWith(
    category: _pendingCategory,
    hasChanges: _hasChanges(_pendingCategory),
  );
}

void deleteCorrectionExample(int index) {
  if (_pendingCategory == null) return;

  final current = _pendingCategory!.correctionExamples ?? [];
  if (index < 0 || index >= current.length) return;

  final updated = List<ChecklistCorrectionExample>.from(current)..removeAt(index);
  updateCorrectionExamples(updated);
}
```

Update `_hasChanges()` to include correction examples:

```dart
bool _hasChanges(CategoryDefinition? current) {
  // ... existing checks ...
  || _hasCorrectionExamplesChanges(
      _pendingCategory!.correctionExamples,
      _originalCategory!.correctionExamples,
  );
}

bool _hasCorrectionExamplesChanges(
  List<ChecklistCorrectionExample>? current,
  List<ChecklistCorrectionExample>? original,
) {
  if (current == null && original == null) return false;
  if (current == null || original == null) return true;
  if (current.length != original.length) return true;

  for (var i = 0; i < current.length; i++) {
    if (current[i].before != original[i].before ||
        current[i].after != original[i].after) {
      return true;
    }
  }
  return false;
}
```

### 6. Localization

**IMPORTANT**: All locales must be updated (en, de, es, fr, ro) to avoid `missing_translations.txt`
issues.

**File: `lib/l10n/app_en.arb`**

```json
"correctionExamplesSectionTitle": "Checklist Correction Examples",
"correctionExamplesSectionDescription": "When you manually correct checklist items, those corrections are saved here and used to improve AI suggestions.",
"correctionExamplesEmpty": "No corrections captured yet. Edit a checklist item to add your first example."
```

**File: `lib/l10n/app_de.arb`**

```json
"correctionExamplesSectionTitle": "Checklisten-Korrekturbeispiele",
"correctionExamplesSectionDescription": "Wenn Sie Checklistenelemente manuell korrigieren, werden diese Korrekturen hier gespeichert und zur Verbesserung der KI-Vorschläge verwendet.",
"correctionExamplesEmpty": "Noch keine Korrekturen erfasst. Bearbeiten Sie ein Checklistenelement, um Ihr erstes Beispiel hinzuzufügen."
```

**File: `lib/l10n/app_es.arb`**

```json
"correctionExamplesSectionTitle": "Ejemplos de Corrección de Lista",
"correctionExamplesSectionDescription": "Cuando corriges manualmente elementos de la lista, esas correcciones se guardan aquí y se usan para mejorar las sugerencias de IA.",
"correctionExamplesEmpty": "Aún no se han capturado correcciones. Edita un elemento de la lista para agregar tu primer ejemplo."
```

**File: `lib/l10n/app_fr.arb`**

```json
"correctionExamplesSectionTitle": "Exemples de Correction de Liste",
"correctionExamplesSectionDescription": "Lorsque vous corrigez manuellement des éléments de liste, ces corrections sont enregistrées ici et utilisées pour améliorer les suggestions de l'IA.",
"correctionExamplesEmpty": "Aucune correction capturée pour l'instant. Modifiez un élément de liste pour ajouter votre premier exemple."
```

**File: `lib/l10n/app_ro.arb`**

```json
"correctionExamplesSectionTitle": "Exemple de Corecție a Listei",
"correctionExamplesSectionDescription": "Când corectați manual elementele listei, acele corecții sunt salvate aici și utilizate pentru a îmbunătăți sugestiile AI.",
"correctionExamplesEmpty": "Nu s-au capturat corecții încă. Editați un element din listă pentru a adăuga primul exemplu."
```

## Workstreams

### 1. Data Model & Serialization

- [ ] Add `ChecklistCorrectionExample` freezed class to `entity_definitions.dart`
- [ ] Add `correctionExamples` field to `CategoryDefinition`
- [ ] Run `build_runner` to regenerate freezed classes
- [ ] Verify sync works (existing infrastructure handles automatically)

### 2. Correction Capture Service

- [ ] Create `CorrectionCaptureService` with provider
- [ ] Write unit tests for capture service (validation, deduplication, normalization)
- [ ] Integrate into `ChecklistItemController.updateTitle()` with `unawaited()`
- [ ] Add tests for controller integration

### 3. Prompt Integration

- [ ] Add `{{correction_examples}}` placeholder to `checklistUpdatesPrompt` USER message
- [ ] Add placeholder handling to `PromptBuilderHelper.buildPromptWithData()`
- [ ] Add correction examples template constant
- [ ] Add tests for placeholder injection (with/without examples)

### 4. Category Settings UI

- [ ] Create `CategoryCorrectionExamples` widget
- [ ] Integrate into `CategoryDetailsPage` as new form section
- [ ] Wire delete action to controller
- [ ] Add l10n strings for ALL locales (en, de, es, fr, ro)

### 5. State Management

- [ ] Add `updateCorrectionExamples()` to `CategoryDetailsController`
- [ ] Add `deleteCorrectionExample()` method
- [ ] Update `_hasChanges()` to include correction examples
- [ ] Add tests for controller state management

### 6. Testing

- [ ] Unit: `CorrectionCaptureService` capture logic (normalization, deduplication, validation)
- [ ] Unit: `PromptBuilderHelper` injects examples correctly
- [ ] Unit: `CategoryDetailsController` correction examples updates
- [ ] Widget: Correction examples list displays correctly
- [ ] Widget: Swipe-to-delete works
- [ ] Update any test fakes that use `CategoryDefinition`

## Questions for User

1. **Maximum Examples Limit**: Should we cap the number of stored examples per category?
   - Recommendation: Yes, suggest 50 examples max to avoid token bloat in prompts
   - When limit is reached: Options are (a) drop oldest, (b) warn user, (c) require manual cleanup
   - **Preference?**

2. **Capture Sensitivity**: What minimum difference should trigger capture?
   - Current approach: Any non-whitespace change that's not purely case-only for very short texts
   - Alternative: Only capture if Levenshtein distance > threshold
   - **Is current approach acceptable?**

3. **User Feedback on Capture**: Should we show a subtle snackbar when a correction is captured?
   - Pro: User knows the system is learning
   - Con: Could be annoying if many corrections
   - **Preference?**

4. **Include `capturedAt` Timestamp**: Should we store when each correction was captured?
   - Pro: Enables sorting by recency, future cleanup of old examples
   - Con: Slightly more data, minor complexity
   - Recommendation: Yes, minimal overhead
   - **Preference?**

5. **AI Response Type Scope**: Should examples be injected only for `checklistUpdates` or also for
   `audioTranscription`?
   - Current plan: Only `checklistUpdates` (directly relevant)
   - Alternative: Also inject for audio transcription (could help with spelling)
   - **Preference?**

6. **Prompt Token Budget**: The speech dictionary feature has a 30-term warning threshold. Should
   we have a similar limit for correction examples?
   - Recommendation: Yes, warn at 30 examples, cap at 50
   - **Preference?**

## Decisions (to be confirmed)

1. **Data Structure**: Use named keys (`before`/`after`) rather than positional array/tuple
2. **Storage Location**: On `CategoryDefinition` (syncs automatically)
3. **UI Pattern**: List with swipe-to-delete (not semicolon-separated text like speech dictionary)
4. **Capture Trigger**: In `ChecklistItemController.updateTitle()` with `unawaited()` for async
5. **Normalization**: Reuse `LottiChecklistUpdateHandler.normalizeWhitespace` (no divergent impl)
6. **Prompt Injection**: New placeholder `{{correction_examples}}` in USER message (not system)
7. **Category ID Access**: Use `current.meta.categoryId` directly (already available on items)

## Risks & Mitigations

### Risk: Token Budget Bloat

Many examples could consume significant prompt tokens.

**Mitigation:**
- Cap examples at reasonable limit (e.g., 50)
- Show warning in UI when approaching limit
- Consider deduplication and merging similar examples

### Risk: Noisy Captures

Accidental edits or typos during editing could create bad examples.

**Mitigation:**
- Require meaningful difference (not just whitespace/case for short texts)
- Allow easy deletion in settings UI
- Consider "confirmation" step (future enhancement: tap to confirm capture)

### Risk: Category Resolution Failure

Checklist items might be on tasks without categories.

**Mitigation:**
- Gracefully skip capture when no category is available
- Log for debugging but don't error

### Risk: Sync Conflicts

Two devices correcting items simultaneously could create different example sets.

**Mitigation:**
- Accept last-write-wins (existing sync behavior)
- Examples are hints, not critical data—loss is acceptable

## Implementation Plan

**Important**: Use MCP tools (`mcp__dart-mcp-local__run_tests`, `mcp__dart-mcp-local__analyze_files`,
`mcp__dart-mcp-local__dart_format`, `mcp__dart-mcp-local__dart_fix`) for all validation steps.
Run analyzer, formatter, and relevant tests after each step.

### Phase 1: Data Model

1. Add `ChecklistCorrectionExample` freezed class to `entity_definitions.dart`
   - Run: `build_runner`, `dart_format`, `analyze_files`

2. Add `correctionExamples` field to `CategoryDefinition`
   - Run: `build_runner`, `dart_format`, `analyze_files`

3. Update any test fakes that use `CategoryDefinition` (if needed)
   - Run: `run_tests` for affected tests

### Phase 2: Correction Capture Service

4. Create `CorrectionCaptureService` with provider
   - Run: `dart_format`, `analyze_files`

5. Write unit tests for capture service
   - Run: `run_tests` for new tests

6. Integrate capture into `ChecklistItemController.updateTitle()` with `unawaited()`
   - Run: `dart_format`, `analyze_files`, `run_tests`

### Phase 3: Prompt Integration

7. Add `{{correction_examples}}` placeholder to `checklistUpdatesPrompt` USER message
   - Run: `dart_format`, `analyze_files`

8. Add placeholder handling to `PromptBuilderHelper.buildPromptWithData()`
   - Run: `dart_format`, `analyze_files`

9. Write tests for placeholder injection
   - Run: `run_tests` for prompt builder tests

### Phase 4: Category Settings UI

10. Add l10n strings to ALL locales (en, de, es, fr, ro)
    - Run: `analyze_files`

11. Create `CategoryCorrectionExamples` widget
    - Run: `dart_format`, `analyze_files`

12. Integrate into `CategoryDetailsPage`
    - Run: `dart_format`, `analyze_files`

13. Add state management to `CategoryDetailsController`
    - Run: `dart_format`, `analyze_files`, `run_tests`

14. Write widget tests for correction examples UI
    - Run: `run_tests`

### Phase 5: Final Validation

15. Run `dart_fix` to apply any automatic fixes
16. Run `dart_format` on all modified files
17. Run `analyze_files` — must have zero warnings
18. Run full test suite via `run_tests` — all tests must pass
19. Manual testing: edit a checklist item, verify capture, check settings UI

## Acceptance Criteria

### Functional

- [ ] Manual edits to checklist item titles capture before/after pairs
- [ ] Corrections are stored on the item's category (via `meta.categoryId`)
- [ ] Duplicate corrections are not stored
- [ ] Corrections appear in category settings UI
- [ ] Swipe-left deletes individual corrections
- [ ] Corrections inject into AI prompts for checklist operations
- [ ] Categories without corrections work normally (empty list)
- [ ] Items without categories skip capture gracefully

### Quality Gates

- [ ] `mcp__dart-mcp-local__analyze_files` — zero warnings
- [ ] `mcp__dart-mcp-local__dart_format` — all code formatted
- [ ] `mcp__dart-mcp-local__run_tests` — all tests pass
- [ ] Validation run after each implementation step

## Files to Create

- `lib/features/checklist/services/correction_capture_service.dart`
- `lib/features/categories/ui/widgets/category_correction_examples.dart`
- `test/features/checklist/services/correction_capture_service_test.dart`
- `test/features/categories/ui/widgets/category_correction_examples_test.dart`
- `test/features/ai/helpers/prompt_builder_helper_correction_examples_test.dart`

## Files to Modify

- `lib/classes/entity_definitions.dart` - Add `ChecklistCorrectionExample` and field
- `lib/features/tasks/state/checklist_item_controller.dart` - Integrate capture with `unawaited()`
- `lib/features/ai/util/preconfigured_prompts.dart` - Add placeholder to USER message
- `lib/features/ai/helpers/prompt_builder_helper.dart` - Handle placeholder in `buildPromptWithData`
- `lib/features/categories/ui/pages/category_details_page.dart` - Add section
- `lib/features/categories/state/category_details_controller.dart` - State management
- `lib/l10n/app_en.arb` - English strings
- `lib/l10n/app_de.arb` - German strings
- `lib/l10n/app_es.arb` - Spanish strings
- `lib/l10n/app_fr.arb` - French strings
- `lib/l10n/app_ro.arb` - Romanian strings

## Related

- `docs/implementation_plans/2025-11-30_speech_dictionary_per_category.md` - Similar pattern
- `docs/implementation_plans/2025-11-29_checklist_item_update_function.md` - AI updates
- `docs/implementation_plans/2025-11-06_checklist_multi_create_array_only_unification.md` -
  Checklist creation
- `lib/features/ai/README.md` - AI feature documentation
- Commit `bbeea7141` - Speech dictionary implementation (reference implementation)

## Status

- [ ] Questions answered by user
- [ ] Ready for implementation
