import 'package:flutter/material.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/ai/ui/image_analysis/ai_image_analysis_list_tile.dart';
import 'package:lotti/features/ai/ui/task_summary/ai_task_summary_list_tile.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/utils/modals.dart';

class AiPopUpMenu extends StatelessWidget {
  const AiPopUpMenu({
    required this.journalEntity,
    required this.linkedFromId,
    super.key,
  });

  final JournalEntity? journalEntity;
  final String? linkedFromId;

  @override
  Widget build(BuildContext context) {
    final journalEntity = this.journalEntity;
    return IconButton(
      icon: const Icon(Icons.assistant_rounded),
      onPressed: () => ModalUtils.showSinglePageModal(
        context: context,
        title: context.messages.aiAssistantTitle,
        builder: (_) => Column(
          children: [
            if (journalEntity != null && journalEntity is Task)
              AiTaskSummaryListTile(
                journalEntity: journalEntity,
                linkedFromId: linkedFromId,
              ),
            // if (journalEntity is! Task)
            //   AiChecklistListTile(
            //     journalEntity: journalEntity,
            //     linkedFromId: linkedFromId,
            //   ),
            if (journalEntity is JournalImage)
              AiImageAnalysisListTile(
                journalImage: journalEntity,
                linkedFromId: linkedFromId,
              ),
            verticalModalSpacer,
          ],
        ),
      ),
    );
  }
}
