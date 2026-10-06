import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai/functions/checklist_completion_functions.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/services/domain_logging.dart';

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
    // One line per batch, not per suggestion: the confidence spread is the
    // signal, the item ids are in the suggestions themselves.
    final byConfidence = {
      for (final level in ChecklistCompletionConfidence.values)
        level.name: suggestions.where((s) => s.confidence == level).length,
    };
    ref
        .read(domainLoggerProvider)
        .log(
          LogDomain.ai,
          'addSuggestions called with ${suggestions.length} suggestions '
          '$byConfidence',
          subDomain: 'ChecklistCompletionService',
        );

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
