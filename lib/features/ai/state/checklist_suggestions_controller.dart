import 'dart:async';

import 'package:lotti/classes/checklist_item_data.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/state/latest_summary_controller.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'checklist_suggestions_controller.g.dart';

@riverpod
class ChecklistSuggestionsController extends _$ChecklistSuggestionsController {
  @override
  Future<List<ChecklistItemData>?> build({
    required String id,
  }) async {
    final provider = latestSummaryControllerProvider(
      id: id,
      aiResponseType: AiResponseType.actionItemSuggestions,
    );

    final latestAiEntry = await ref.watch(provider.future);
    final suggestedActionItems = latestAiEntry?.data.suggestedActionItems;

    final checklistItems = suggestedActionItems?.map((item) {
      final title = item.title.replaceAll(RegExp('[-.,"*]'), '').trim();
      return ChecklistItemData(
        title: title,
        isChecked: item.completed,
        linkedChecklists: [],
      );
    }).toList();

    return checklistItems;
  }

  void notifyCreatedChecklistItem({required String title}) {
    final provider = latestSummaryControllerProvider(
      id: id,
      aiResponseType: AiResponseType.actionItemSuggestions,
    );
    ref.read(provider.notifier).removeActionItem(title: title);
  }

  void removeActionItem({required String title}) {
    final provider = latestSummaryControllerProvider(
      id: id,
      aiResponseType: AiResponseType.actionItemSuggestions,
    );
    ref.read(provider.notifier).removeActionItem(title: title);
  }
}
