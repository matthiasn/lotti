import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/labels/state/labels_list_controller.dart';
import 'package:lotti/features/labels/ui/widgets/label_chip.dart';
import 'package:lotti/features/tasks/ui/labels/label_selection_modal_content.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';
import 'package:lotti/widgets/search/index.dart';

/// Displays assigned labels for any journal entry type.
///
/// Uses [EntitiesCacheService] for fast label lookups. Supports:
/// - Display mode: Shows labels as chips (for list cards)
/// - Interactive mode: Includes edit button to open label selector
class EntryLabelsDisplay extends ConsumerWidget {
  const EntryLabelsDisplay({
    required this.entryId,
    this.showEditButton = false,
    this.showHeader = false,
    this.bottomPadding = 0,
    super.key,
  });

  final String entryId;

  /// Whether to show the edit button for opening the label selector.
  final bool showEditButton;

  /// Whether to show the "Labels" header text.
  final bool showHeader;

  /// Bottom padding to apply when labels are displayed (not when empty).
  final double bottomPadding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch label stream to rebuild when labels change globally
    ref.watch(labelsStreamProvider);

    final entryState = ref.watch(entryControllerProvider(id: entryId)).value;
    final entry = entryState?.entry;

    if (entry == null) {
      return const SizedBox.shrink();
    }

    final cache = getIt<EntitiesCacheService>();
    final labelIds = entry.meta.labelIds ?? <String>[];
    final showPrivate = cache.showPrivateEntries;

    // Use cache for fast label lookups
    final labels = labelIds
        .map(cache.getLabelById)
        .whereType<LabelDefinition>()
        .where((label) => showPrivate || !(label.private ?? false))
        .toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    if (labels.isEmpty && !showEditButton) {
      return const SizedBox.shrink();
    }

    if (showHeader) {
      return _buildWithHeader(context, ref, labels, entry);
    }

    return _buildLabelsWrap(context, labels);
  }

  Widget _buildWithHeader(
    BuildContext context,
    WidgetRef ref,
    List<LabelDefinition> labels,
    JournalEntity entry,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final headerStyle = theme.textTheme.titleSmall?.copyWith(
      color: colorScheme.outline,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              context.messages.entryLabelsHeaderTitle,
              style: headerStyle,
            ),
            if (showEditButton)
              IconButton(
                tooltip: context.messages.entryLabelsEditTooltip,
                onPressed: () => _openSelector(
                  context,
                  ref,
                  entry.meta.labelIds ?? [],
                  entry.meta.categoryId,
                ),
                icon: Icon(
                  Icons.edit_outlined,
                  size: 18,
                  color: colorScheme.outline,
                ),
              ),
          ],
        ),
        if (labels.isEmpty)
          Text(
            context.messages.entryLabelsNoLabels,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.6),
            ),
          )
        else
          _buildLabelsWrap(context, labels),
      ],
    );
  }

  Widget _buildLabelsWrap(BuildContext context, List<LabelDefinition> labels) {
    if (labels.isEmpty) {
      return const SizedBox.shrink();
    }

    final wrap = Wrap(
      spacing: 6,
      runSpacing: 6,
      children: labels.map((label) => LabelChip(label: label)).toList(),
    );

    if (bottomPadding > 0) {
      return Padding(
        padding: EdgeInsets.only(bottom: bottomPadding),
        child: wrap,
      );
    }

    return wrap;
  }

  Future<void> _openSelector(
    BuildContext context,
    WidgetRef ref,
    List<String> assignedIds,
    String? categoryId,
  ) async {
    final applyController = ValueNotifier<Future<bool> Function()?>(null);
    final searchNotifier = ValueNotifier<String>('');
    final searchController = TextEditingController();

    try {
      await ModalUtils.showSinglePageModal<List<String>>(
        context: context,
        titleWidget: Padding(
          padding:
              const EdgeInsets.only(top: 8, left: 20, right: 20, bottom: 8),
          child: LottiSearchBar(
            hintText: context.messages.tasksLabelsSheetSearchHint,
            controller: searchController,
            useGradientInDark: false,
            onChanged: (value) => searchNotifier.value = value,
            onClear: () {
              searchNotifier.value = '';
              searchController.clear();
            },
            textCapitalization: TextCapitalization.words,
          ),
        ),
        navBarHeight: 80,
        stickyActionBar: _buildStickyActionBar(context, applyController),
        padding: const EdgeInsets.fromLTRB(0, 0, 0, 100),
        builder: (ctx) {
          final minHeight = MediaQuery.of(ctx).size.height * 0.5;
          return ConstrainedBox(
            constraints: BoxConstraints(minHeight: minHeight),
            child: LabelSelectionModalContent(
              entryId: entryId,
              initialLabelIds: assignedIds,
              categoryId: categoryId,
              applyController: applyController,
              searchQuery: searchNotifier,
            ),
          );
        },
      );
    } finally {
      applyController.dispose();
      searchNotifier.dispose();
      searchController.dispose();
    }
  }

  Widget _buildStickyActionBar(
    BuildContext context,
    ValueNotifier<Future<bool> Function()?> applyController,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHigh,
          border: Border(
            top: BorderSide(
              color: colorScheme.outline.withValues(alpha: 0.12),
            ),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(context.messages.cancelButton),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ValueListenableBuilder<Future<bool> Function()?>(
                valueListenable: applyController,
                builder: (context, applyFn, _) {
                  return FilledButton(
                    onPressed: applyFn == null
                        ? null
                        : () async {
                            final ok = await applyFn();
                            if (!context.mounted) return;
                            if (ok) {
                              Navigator.of(context).pop();
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    context.messages.tasksLabelsUpdateFailed,
                                  ),
                                ),
                              );
                            }
                          },
                    child: Text(context.messages.tasksLabelsSheetApply),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact version of [EntryLabelsDisplay] for use in list cards.
///
/// Only displays labels, no header or edit button.
class EntryLabelsDisplayCompact extends ConsumerWidget {
  const EntryLabelsDisplayCompact({
    required this.entryId,
    super.key,
  });

  final String entryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return EntryLabelsDisplay(
      entryId: entryId,
    );
  }
}
