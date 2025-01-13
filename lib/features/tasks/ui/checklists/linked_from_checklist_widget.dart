import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/journal/ui/widgets/journal_card.dart';
import 'package:lotti/features/tasks/state/checklist_controller.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';

class LinkedFromChecklistWidget extends ConsumerWidget {
  const LinkedFromChecklistWidget(
    this.item, {
    super.key,
  });

  final ChecklistItem item;

  @override
  Widget build(
    BuildContext context,
    WidgetRef ref,
  ) {
    final checklist = ref
        .watch(
          checklistControllerProvider(
            id: item.data.linkedChecklists.first,
          ),
        )
        .value;

    if (checklist == null) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        Text(
          context.messages.journalLinkedFromLabel,
          style: TextStyle(color: context.colorScheme.outline),
        ),
        JournalCard(item: checklist),
      ],
    );
  }
}
