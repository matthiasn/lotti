import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/labels/state/labels_list_controller.dart';
import 'package:lotti/features/labels/ui/widgets/label_chip.dart';
import 'package:lotti/features/labels/ui/widgets/label_selection_modal_utils.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/entities_cache_service.dart';

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
    List<String> assignedIds,
    String? categoryId,
  ) async {
    await LabelSelectionModalUtils.openLabelSelector(
      context: context,
      entryId: entryId,
      initialLabelIds: assignedIds,
      categoryId: categoryId,
    );
  }
}
