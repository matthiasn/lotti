import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/ai/ui/task_summary/ai_task_summary_view.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/utils/modals.dart';

class AiTaskSummaryListTile extends ConsumerWidget {
  const AiTaskSummaryListTile({
    required this.journalEntity,
    required this.processImages,
    this.linkedFromId,
    super.key,
  });

  final JournalEntity journalEntity;
  final String? linkedFromId;
  final bool processImages;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      leading: const Icon(Icons.chat_rounded),
      title: Text(
        processImages
            ? context.messages.aiAssistantSummarizeTaskWithImages
            : context.messages.aiAssistantSummarizeTask,
      ),
      onTap: () {
        Navigator.of(context).pop();
        ModalUtils.showSinglePageModal(
          context: context,
          title: context.messages.aiAssistantTitle,
          builder: (_) => AiTaskSummaryView(
            id: journalEntity.id,
            processImages: processImages,
          ),
        );
      },
    );
  }
}
