import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/ai/state/ollama_prompt.dart';
import 'package:lotti/features/ai/state/ollama_prompt_checklist.dart';
import 'package:lotti/features/ai/ui/ai_response_preview.dart';

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
    return PopupMenuButton(
      child: const Icon(Icons.more_vert_rounded),
      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
        PopupMenuItem(
          value: 'prompt',
          child: Row(
            children: [
              AiPromptIconWidget(
                journalEntity: journalEntity,
                linkedFromId: linkedFromId,
              ),
              const Text('Prompt'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'checklist',
          child: Row(
            children: [
              AiChecklistIconWidget(
                journalEntity: journalEntity,
                linkedFromId: linkedFromId,
              ),
              const Text('Create checklist'),
            ],
          ),
        ),
      ],
    );
  }
}

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
