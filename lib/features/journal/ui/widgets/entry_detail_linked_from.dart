import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/journal/state/linked_from_entries_controller.dart';
import 'package:lotti/features/journal/ui/widgets/list_cards/modern_journal_card.dart';
import 'package:lotti/features/journal/ui/widgets/list_cards/modern_journal_image_card.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';

class LinkedFromEntriesWidget extends ConsumerWidget {
  const LinkedFromEntriesWidget(
    this.item, {
    super.key,
  });

  final JournalEntity item;

  @override
  Widget build(
    BuildContext context,
    WidgetRef ref,
  ) {
    final provider = linkedFromEntriesControllerProvider(id: item.id);
    final items = ref.watch(provider).valueOrNull ?? [];

    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        Text(
          context.messages.journalLinkedFromLabel,
          style: context.textTheme.titleSmall
              ?.copyWith(color: context.colorScheme.outline),
        ),
        ...List.generate(
          items.length,
          (int index) {
            final item = items.elementAt(index);
            return item.maybeMap(
              journalImage: (JournalImage image) {
                return ModernJournalImageCard(
                  item: image,
                  key: Key('${item.meta.id}-${item.meta.id}'),
                );
              },
              orElse: () {
                return ModernJournalCard(
                  item: item,
                  key: Key('${item.meta.id}-${item.meta.id}'),
                  showLinkedDuration: true,
                );
              },
            );
          },
        ),
      ],
    );
  }
}
