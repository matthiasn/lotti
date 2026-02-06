import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/journal/state/linked_entries_controller.dart';
import 'package:lotti/features/journal/ui/widgets/entry_details_widget.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';

class LinkedEntriesWidget extends ConsumerStatefulWidget {
  const LinkedEntriesWidget(
    this.item, {
    this.entryKeyBuilder,
    this.highlightedEntryId,
    this.activeTimerEntryId,
    this.hideTaskEntries = false,
    super.key,
  });

  final JournalEntity item;
  final GlobalKey Function(String entryId)? entryKeyBuilder;
  final String? highlightedEntryId;
  final String? activeTimerEntryId;
  final bool hideTaskEntries;

  @override
  ConsumerState<LinkedEntriesWidget> createState() =>
      _LinkedEntriesWidgetState();
}

class _LinkedEntriesWidgetState extends ConsumerState<LinkedEntriesWidget> {
  bool _isExpanded = true;

  @override
  Widget build(BuildContext context) {
    final provider = linkedEntriesControllerProvider(id: widget.item.id);
    final entryLinks = ref.watch(provider).value ?? [];

    final includeAiEntries =
        ref.watch(includeAiEntriesControllerProvider(id: widget.item.id));

    if (entryLinks.isEmpty) {
      return const SizedBox.shrink();
    }

    if (widget.hideTaskEntries) {
      final hasNonTaskEntries =
          ref.watch(hasNonTaskLinkedEntriesProvider(widget.item.id));
      if (!hasNonTaskEntries) {
        return const SizedBox.shrink();
      }
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
                      ModalUtils.showSinglePageModal<void>(
                        context: context,
                        builder: (BuildContext _) =>
                            LinkedFilterModalContent(entryId: widget.item.id),
                      );
                    },
                  ),
                ],
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
                    entryLinks.length,
                    (int index) {
                      final link = entryLinks.elementAt(index);
                      final toId = link.toId;

                      return RepaintBoundary(
                        child: EntryDetailsWidget(
                          key: widget.entryKeyBuilder != null
                              ? widget.entryKeyBuilder!(toId)
                              : Key('${widget.item.id}-$toId'),
                          itemId: toId,
                          parentTags: widget.item.meta.tagIds?.toSet(),
                          linkedFrom: widget.item,
                          link: link,
                          showAiEntry: includeAiEntries,
                          hideTaskEntries: widget.hideTaskEntries,
                          isHighlighted: widget.highlightedEntryId == toId,
                          isActiveTimer: widget.activeTimerEntryId == toId,
                        ),
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
