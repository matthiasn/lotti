import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/journal/state/linked_entries_controller.dart';
import 'package:lotti/features/journal/ui/widgets/entry_details_widget.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';

class LinkedEntriesWidget extends ConsumerWidget {
  const LinkedEntriesWidget(
    this.item, {
    super.key,
  });

  final JournalEntity item;

  @override
  Widget build(
    BuildContext context,
    WidgetRef ref,
  ) {
    final provider = linkedEntriesControllerProvider(id: item.id);
    final entryLinks = ref.watch(provider).valueOrNull ?? [];

    final includeHiddenProvider = includeHiddenControllerProvider(id: item.id);
    final includeHiddenNotifier = ref.read(includeHiddenProvider.notifier);
    final includeHidden = ref.watch(includeHiddenProvider);

    final itemIds = entryLinks.map((link) => link.toId).toList();

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              context.messages.journalLinkedEntriesLabel,
              style: TextStyle(
                color: context.colorScheme.outline,
              ),
            ),
            const SizedBox(width: 40),
            Text(
              // TODO: l10n
              'hidden:',
              style: TextStyle(color: context.colorScheme.outline),
            ),
            Checkbox(
              value: includeHidden,
              onChanged: (value) {
                includeHiddenNotifier.includeHidden = value ?? false;
              },
            ),
          ],
        ),
        ...List.generate(
          itemIds.length,
          (int index) {
            final itemId = itemIds.elementAt(index);

            return EntryDetailWidget(
              key: Key('$itemId-$itemId'),
              itemId: itemId,
              popOnDelete: false,
              parentTags: item.meta.tagIds?.toSet(),
              linkedFrom: item,
            );
          },
        ),
      ],
    );
  }
}
