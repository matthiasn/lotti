import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/ai/ui/task_summary/action_item_suggestions_view.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/utils/modals.dart';

class ActionItemSuggestionsListTile extends ConsumerWidget {
  const ActionItemSuggestionsListTile({
    required this.journalEntity,
    this.linkedFromId,
    super.key,
  });

  final JournalEntity journalEntity;
  final String? linkedFromId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      leading: const Icon(Icons.chat_rounded),
      title: Text(
        context.messages.aiAssistantActionItemSuggestions,
      ),
      onTap: () {
        Navigator.of(context).pop();
        ModalUtils.showSinglePageModal<void>(
          context: context,
          title: context.messages.aiAssistantTitle,
          builder: (_) => ActionItemSuggestionsView(
            id: journalEntity.id,
          ),
        );
      },
    );
  }
}
