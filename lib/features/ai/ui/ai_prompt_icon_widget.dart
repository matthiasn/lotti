import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/ai/state/ollama_prompt.dart';
import 'package:lotti/features/ai/state/ollama_prompt_checklist.dart';
import 'package:lotti/features/ai/ui/ai_response_preview.dart';

class AiPromptIconWidget extends ConsumerWidget {
  const AiPromptIconWidget({
    required this.journalEntity,
    this.linkedFromId,
    super.key,
  });

  final JournalEntity? journalEntity;
  final String? linkedFromId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      icon: const Icon(Icons.assistant_rounded),
      tooltip: 'Prompt',
      onPressed: () {
        ref.read(aiResponseProvider.notifier).prompt(
              journalEntity,
              linkedFromId: linkedFromId,
            );
        showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          builder: (BuildContext context) => const AiResponsePreview(),
        );
      },
    );
  }
}

class AiChecklistIconWidget extends ConsumerWidget {
  const AiChecklistIconWidget({
    required this.journalEntity,
    this.linkedFromId,
    super.key,
  });

  final JournalEntity? journalEntity;
  final String? linkedFromId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      icon: const Icon(Icons.checklist_rounded),
      tooltip: 'Create checklist items',
      onPressed: () {
        ref.read(aiChecklistResponseProvider.notifier).createChecklistItems(
              journalEntity,
              linkedFromId: linkedFromId,
            );
        showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          builder: (BuildContext context) => const AiChecklistResponsePreview(),
        );
      },
    );
  }
}
