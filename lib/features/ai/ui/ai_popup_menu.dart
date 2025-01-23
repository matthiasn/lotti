import 'package:flutter/material.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/ai/ui/checklist/ai_checklist_list_tile.dart';
import 'package:lotti/features/ai/ui/prompt/ai_prompt_list_tile.dart';
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
            if (journalEntity != null)
              AiTaskSummaryListTile(
                journalEntity: journalEntity,
                linkedFromId: linkedFromId,
              ),
            AiPromptListTile(
              journalEntity: journalEntity,
              linkedFromId: linkedFromId,
            ),
            AiChecklistListTile(
              journalEntity: journalEntity,
              linkedFromId: linkedFromId,
            ),
            verticalModalSpacer,
          ],
        ),
      ),
    );
  }
}
