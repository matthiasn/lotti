import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/journal/ui/widgets/journal_card.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';

class LinkedFromTaskWidget extends ConsumerWidget {
  const LinkedFromTaskWidget(
    this.item, {
    super.key,
  });

  final Checklist item;

  @override
  Widget build(
    BuildContext context,
    WidgetRef ref,
  ) {
    final linkedTasks = item.data.linkedTasks;

    if (linkedTasks.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        Text(
          context.messages.journalLinkedFromLabel,
          style: TextStyle(color: context.colorScheme.outline),
        ),
        ...linkedTasks.map(
          (id) {
            final task =
                ref.watch(entryControllerProvider(id: id)).value?.entry;

            if (task == null) {
              return const SizedBox.shrink();
            }

            return JournalCard(item: task);
          },
        ),
      ],
    );
  }
}
