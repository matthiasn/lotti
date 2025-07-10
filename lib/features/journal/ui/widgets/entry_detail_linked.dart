import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/journal/state/linked_entries_controller.dart';
import 'package:lotti/features/journal/ui/widgets/entry_details_widget.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/modal/modern_modal_utils.dart';

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

    final includeAiEntries =
        ref.watch(includeAiEntriesControllerProvider(id: item.id));

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
              style: context.textTheme.titleSmall?.copyWith(color: color),
            ),
            IconButton(
              icon: Icon(Icons.filter_list, color: color),
              onPressed: () {
                ModernModalUtils.showSinglePageModal<void>(
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
              showAiEntry: includeAiEntries,
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
    final provider2 = includeAiEntriesControllerProvider(id: entryId);
    final notifier2 = ref.read(provider2.notifier);
    final includeHidden = ref.watch(provider);
    final includeAiEntries = ref.watch(provider2);
    final color = context.colorScheme.outline;

    return Padding(
      padding: const EdgeInsets.only(bottom: 50, left: 20, right: 20),
      child: Column(
        children: [
          Row(
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
          const SizedBox(height: 20),
          Row(
            children: [
              Text(
                context.messages.journalLinkedEntriesAiLabel,
                style: TextStyle(color: color),
              ),
              Checkbox(
                value: includeAiEntries,
                side: BorderSide(color: color),
                onChanged: (value) {
                  notifier2.includeAiEntries = value ?? false;
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
