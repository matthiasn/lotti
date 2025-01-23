import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/ai/state/ollama_prompt.dart';
import 'package:lotti/features/ai/ui/prompt/ai_response_preview.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

class AiPromptListTile extends ConsumerWidget {
  const AiPromptListTile({
    required this.journalEntity,
    this.linkedFromId,
    super.key,
  });

  final JournalEntity? journalEntity;
  final String? linkedFromId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      leading: const Icon(Icons.chat_rounded),
      title: Text(context.messages.aiAssistantRunPrompt),
      onTap: () {
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
