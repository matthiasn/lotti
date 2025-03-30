import 'package:flutter/material.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/ai/ui/image_analysis/ai_image_analysis_list_tile.dart';
import 'package:lotti/features/ai/ui/image_analysis/ai_image_analysis_view.dart';
import 'package:lotti/features/ai/ui/task_summary/action_item_suggestions_list_tile.dart';
import 'package:lotti/features/ai/ui/task_summary/action_item_suggestions_view.dart';
import 'package:lotti/features/ai/ui/task_summary/ai_task_summary_list_tile.dart';
import 'package:lotti/features/ai/ui/task_summary/ai_task_summary_view.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/utils/modals.dart';
import 'package:wolt_modal_sheet/wolt_modal_sheet.dart';

class AiPopUpMenu extends StatelessWidget {
  const AiPopUpMenu({
    required this.journalEntity,
    required this.linkedFromId,
    super.key,
  });

  final JournalEntity journalEntity;
  final String? linkedFromId;

  @override
  Widget build(BuildContext context) {
    final journalEntity = this.journalEntity;
    return IconButton(
      icon: Icon(
        Icons.assistant_rounded,
        color: context.colorScheme.outline,
      ),
      onPressed: () => AiModal.show<void>(
        context: context,
        journalEntity: journalEntity,
        linkedFromId: linkedFromId,
      ),
    );
  }
}

class AiModal {
  static Future<void> show<T>({
    required BuildContext context,
    required JournalEntity journalEntity,
    required String? linkedFromId,
  }) async {
    final pageIndexNotifier = ValueNotifier(0);

    final initialModalPage = ModalUtils.modalSheetPage(
      context: context,
      title: context.messages.aiAssistantTitle,
      child: Column(
        children: [
          if (journalEntity is Task)
            AiTaskSummaryListTile(
              journalEntity: journalEntity,
              linkedFromId: linkedFromId,
              onTap: () => pageIndexNotifier.value = 1,
            ),
          if (journalEntity is Task)
            ActionItemSuggestionsListTile(
              journalEntity: journalEntity,
              linkedFromId: linkedFromId,
              onTap: () => pageIndexNotifier.value = 2,
            ),
          if (journalEntity is JournalImage)
            AiImageAnalysisListTile(
              journalImage: journalEntity,
              linkedFromId: linkedFromId,
              onTap: () => pageIndexNotifier.value = 3,
            ),
          verticalModalSpacer,
        ],
      ),
    );

    final taskSummaryModalPage = ModalUtils.modalSheetPage(
      context: context,
      title: context.messages.aiAssistantSummarizeTask,
      child: AiTaskSummaryView(id: journalEntity.id),
      onTapBack: () => pageIndexNotifier.value = 0,
    );

    final actionItemSuggestionsModalPage = ModalUtils.modalSheetPage(
      context: context,
      title: context.messages.aiAssistantActionItemSuggestions,
      child: ActionItemSuggestionsView(id: journalEntity.id),
      onTapBack: () => pageIndexNotifier.value = 0,
    );

    final imageAnalysisModalPage = ModalUtils.modalSheetPage(
      context: context,
      title: context.messages.aiAssistantAnalyzeImage,
      child: AiImageAnalysisView(id: journalEntity.id),
      onTapBack: () => pageIndexNotifier.value = 0,
    );

    return WoltModalSheet.show<void>(
      context: context,
      pageListBuilder: (modalSheetContext) {
        return [
          initialModalPage,
          taskSummaryModalPage,
          actionItemSuggestionsModalPage,
          imageAnalysisModalPage,
        ];
      },
      modalTypeBuilder: ModalUtils.modalTypeBuilder,
      barrierDismissible: true,
      pageIndexNotifier: pageIndexNotifier,
    );
  }
}
