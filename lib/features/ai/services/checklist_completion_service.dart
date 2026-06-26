import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai/functions/checklist_completion_functions.dart';

final AsyncNotifierProvider<
  ChecklistCompletionService,
  List<ChecklistCompletionSuggestion>
>
checklistCompletionServiceProvider =
    AsyncNotifierProvider.autoDispose<
      ChecklistCompletionService,
      List<ChecklistCompletionSuggestion>
    >(
      ChecklistCompletionService.new,
      name: 'checklistCompletionServiceProvider',
    );

class ChecklistCompletionService
    extends AsyncNotifier<List<ChecklistCompletionSuggestion>> {
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
}
