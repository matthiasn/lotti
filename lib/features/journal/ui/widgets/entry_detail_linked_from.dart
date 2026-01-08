import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/journal/state/linked_from_entries_controller.dart';
import 'package:lotti/features/journal/ui/widgets/list_cards/journal_card.dart';
import 'package:lotti/features/journal/ui/widgets/list_cards/journal_image_card.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';

class LinkedFromEntriesWidget extends ConsumerWidget {
  const LinkedFromEntriesWidget(
    this.item, {
    this.hideTaskEntries = false,
    super.key,
  });

  final JournalEntity item;
  final bool hideTaskEntries;

  @override
  Widget build(
    BuildContext context,
    WidgetRef ref,
  ) {
    final provider = linkedFromEntriesControllerProvider(id: item.id);
    var items = ref.watch(provider).value ?? [];

    // Filter out Task entries if requested (shown in dedicated Linked Tasks section)
    if (hideTaskEntries) {
      items = items.where((e) => e is! Task).toList();
    }

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
                return Padding(
                  padding: const EdgeInsets.only(
                    left: AppTheme.spacingXSmall,
                    right: AppTheme.spacingXSmall,
                    bottom: AppTheme.spacingXSmall,
                  ),
                  child: ModernJournalImageCard(
                    item: image,
                    key: ValueKey(image.meta.id),
                  ),
                );
              },
              orElse: () {
                return Padding(
                  padding: const EdgeInsets.only(
                    left: AppTheme.spacingXSmall,
                    right: AppTheme.spacingXSmall,
                    bottom: AppTheme.spacingXSmall,
                  ),
                  child: ModernJournalCard(
                    item: item,
                    key: ValueKey(item.meta.id),
                    showLinkedDuration: true,
                    removeHorizontalMargin: true,
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }
}
