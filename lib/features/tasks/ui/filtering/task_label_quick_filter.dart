import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/journal/state/journal_page_controller.dart';
import 'package:lotti/features/journal/state/journal_page_scope.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/utils/color.dart';

class TaskLabelQuickFilter extends ConsumerWidget {
  const TaskLabelQuickFilter({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cache = getIt<EntitiesCacheService>();
    final showTasks = ref.watch(journalPageScopeProvider);
    final state = ref.watch(journalPageControllerProvider(showTasks));
    final controller =
        ref.read(journalPageControllerProvider(showTasks).notifier);

    final selected = state.selectedLabelIds;
    if (!state.showTasks || selected.isEmpty) {
      return const SizedBox.shrink();
    }

    final chips = <Widget>[];
    for (final labelId in selected) {
      if (labelId.isEmpty) {
        chips.add(
          _QuickFilterChip(
            label: context.messages.tasksQuickFilterUnassignedLabel,
            color: Theme.of(context).colorScheme.outlineVariant,
            onDeleted: () => controller.toggleSelectedLabelId(''),
          ),
        );
        continue;
      }

      final label = cache.getLabelById(labelId);
      if (label == null) continue;
      final color = colorFromCssHex(label.color, substitute: Colors.blueGrey);
      chips.add(
        _QuickFilterChip(
          label: label.name,
          color: color,
          onDeleted: () => controller.toggleSelectedLabelId(label.id),
        ),
      );
    }

    final theme = Theme.of(context);
    final count = selected.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.filter_alt_outlined,
              size: 16,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Text(
              '${context.messages.tasksQuickFilterLabelsActiveTitle} ($count)',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: controller.clearSelectedLabelIds,
              icon: const Icon(Icons.backspace_outlined, size: 16),
              label: Text(context.messages.tasksQuickFilterClear),
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                textStyle: theme.textTheme.labelSmall,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: chips,
        ),
      ],
    );
  }
}

class _QuickFilterChip extends StatelessWidget {
  const _QuickFilterChip({
    required this.label,
    required this.color,
    required this.onDeleted,
  });

  final String label;
  final Color color;
  final VoidCallback onDeleted;

  @override
  Widget build(BuildContext context) {
    return InputChip(
      label: Text(label),
      labelStyle: Theme.of(context).textTheme.labelSmall,
      backgroundColor: color.withValues(alpha: 0.18),
      visualDensity: VisualDensity.compact,
      onDeleted: onDeleted,
      deleteIcon: const Icon(Icons.close, size: 16),
      deleteIconColor: Theme.of(context).colorScheme.onSurfaceVariant,
    );
  }
}
