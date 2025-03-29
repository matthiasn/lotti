import 'package:flutter/material.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

class AiTaskSummaryListTile extends StatelessWidget {
  const AiTaskSummaryListTile({
    required this.journalEntity,
    required this.onTap,
    this.linkedFromId,
    super.key,
  });

  final JournalEntity journalEntity;
  final String? linkedFromId;
  final void Function()? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.chat_rounded),
      title: Text(context.messages.aiAssistantSummarizeTask),
      onTap: onTap,
    );
  }
}
