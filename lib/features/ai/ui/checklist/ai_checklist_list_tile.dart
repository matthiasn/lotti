import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/ai/state/ollama_prompt_checklist.dart';
import 'package:lotti/features/ai/ui/checklist/ai_checklist_response_preview.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

class AiChecklistListTile extends ConsumerWidget {
  const AiChecklistListTile({
    required this.journalEntity,
    this.linkedFromId,
    super.key,
  });

  final JournalEntity? journalEntity;
  final String? linkedFromId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      leading: const Icon(Icons.checklist_rounded),
      title: Text(context.messages.aiAssistantCreateChecklist),
      onTap: () {
        ref.read(aiChecklistResponseProvider.notifier).createChecklistItems(
              journalEntity,
              linkedFromId: linkedFromId,
            );
        showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          builder: (BuildContext context) => AiChecklistResponsePreview(
            linkedFromId: linkedFromId,
          ),
        );
      },
    );
  }
}
