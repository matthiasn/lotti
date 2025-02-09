import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/journal/state/linked_entries_controller.dart';
import 'package:lotti/features/journal/ui/widgets/entry_details_widget.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/utils/modals.dart';

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

    if (entryLinks.isEmpty) {
      return const SizedBox.shrink();
    }

    final color = context.colorScheme.outline;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              context.messages.journalLinkedEntriesLabel,
              style: TextStyle(color: color),
            ),
            IconButton(
              icon: Icon(Icons.filter_list, color: color),
              onPressed: () {
                ModalUtils.showSinglePageModal<void>(
                  context: context,
                  builder: (BuildContext _) =>
                      LinkedFilterModalContent(entryId: item.id),
                );
              },
            ),
          ],
        ),
        ...List.generate(
          entryLinks.length,
          (int index) {
            final link = entryLinks.elementAt(index);
            final toId = link.toId;

            return EntryDetailsWidget(
              key: Key('${item.id}-$toId'),
              itemId: toId,
              popOnDelete: false,
              parentTags: item.meta.tagIds?.toSet(),
              linkedFrom: item,
              link: link,
            );
          },
        ),
      ],
    );
  }
}

class LinkedFilterModalContent extends ConsumerWidget {
  const LinkedFilterModalContent({
    required this.entryId,
    super.key,
  });

  final String entryId;

  @override
  Widget build(
    BuildContext context,
    WidgetRef ref,
  ) {
    final provider = includeHiddenControllerProvider(id: entryId);
    final notifier = ref.read(provider.notifier);
    final includeHidden = ref.watch(provider);
    final color = context.colorScheme.outline;

    return Padding(
      padding: const EdgeInsets.only(bottom: 50, left: 20, right: 20),
      child: Row(
        children: [
          Text(
            context.messages.journalLinkedEntriesHiddenLabel,
            style: TextStyle(color: color),
          ),
          Checkbox(
            value: includeHidden,
            side: BorderSide(color: color),
            onChanged: (value) {
              notifier.includeHidden = value ?? false;
            },
          ),
        ],
      ),
    );
  }
}
