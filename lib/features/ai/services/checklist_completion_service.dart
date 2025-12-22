import 'dart:developer' as developer;

import 'package:collection/collection.dart';
import 'package:lotti/features/ai/functions/checklist_completion_functions.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'checklist_completion_service.g.dart';

@riverpod
class ChecklistCompletionService extends _$ChecklistCompletionService {
  @override
  FutureOr<List<ChecklistCompletionSuggestion>> build() async {
    return [];
  }

  /// Add multiple suggestions at once
  void addSuggestions(List<ChecklistCompletionSuggestion> suggestions) {
    developer.log(
      'ChecklistCompletionService.addSuggestions called with ${suggestions.length} suggestions',
      name: 'ChecklistCompletionService',
    );

    for (final suggestion in suggestions) {
      developer.log(
        '  - ${suggestion.checklistItemId}: ${suggestion.confidence.name}',
        name: 'ChecklistCompletionService',
      );
    }

    state = AsyncData(suggestions);
  }

  /// Clear suggestion for a specific checklist item
  void clearSuggestion(String checklistItemId) {
    final currentSuggestions = state.value ?? [];
    final updatedSuggestions = currentSuggestions
        .where((s) => s.checklistItemId != checklistItemId)
        .toList();
    state = AsyncData(updatedSuggestions);
  }

  /// Get suggestion for a specific checklist item
  ChecklistCompletionSuggestion? getSuggestionForItem(String checklistItemId) {
    final suggestions = state.value ?? [];
    return suggestions
        .firstWhereOrNull((s) => s.checklistItemId == checklistItemId);
  }
}
