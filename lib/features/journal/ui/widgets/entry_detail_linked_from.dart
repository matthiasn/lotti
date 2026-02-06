import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/journal/state/linked_from_entries_controller.dart';
import 'package:lotti/features/journal/ui/widgets/list_cards/journal_card.dart';
import 'package:lotti/features/journal/ui/widgets/list_cards/journal_image_card.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';

class LinkedFromEntriesWidget extends ConsumerStatefulWidget {
  const LinkedFromEntriesWidget(
    this.item, {
    this.hideTaskEntries = false,
    super.key,
  });

  final JournalEntity item;
  final bool hideTaskEntries;

  @override
  ConsumerState<LinkedFromEntriesWidget> createState() =>
      _LinkedFromEntriesWidgetState();
}

class _LinkedFromEntriesWidgetState
    extends ConsumerState<LinkedFromEntriesWidget> {
  bool _isExpanded = true;

  @override
  Widget build(BuildContext context) {
    final provider = linkedFromEntriesControllerProvider(id: widget.item.id);
    var items = ref.watch(provider).value ?? [];

    if (widget.hideTaskEntries) {
      items = items.where((e) => e is! Task).toList();
    }

    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    final color = context.colorScheme.outline;

    return Column(
      children: [
        GestureDetector(
          onTap: () => setState(() => _isExpanded = !_isExpanded),
          child: Column(
            children: [
              AnimatedRotation(
                turns: _isExpanded ? 0.0 : -0.25,
                duration: AppTheme.chevronRotationDuration,
                child: Icon(
                  Icons.expand_more,
                  size: AppTheme.chevronSize,
                  color: color,
                ),
              ),
              Text(
                context.messages.journalLinkedFromLabel,
                style: context.textTheme.titleSmall?.copyWith(color: color),
              ),
            ],
          ),
        ),
        AnimatedSize(
          duration: AppTheme.collapseAnimationDuration,
          curve: Curves.easeInOut,
          child: _isExpanded
              ? Column(
                  children: List.generate(
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
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}
