import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lotti/blocs/journal/journal_page_cubit.dart';
import 'package:lotti/blocs/journal/journal_page_state.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/utils/color.dart';

class TaskLabelQuickFilter extends StatelessWidget {
  const TaskLabelQuickFilter({super.key});

  @override
  Widget build(BuildContext context) {
    final cache = getIt<EntitiesCacheService>();
    return BlocBuilder<JournalPageCubit, JournalPageState>(
      builder: (context, state) {
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
                onDeleted: () =>
                    context.read<JournalPageCubit>().toggleSelectedLabelId(''),
              ),
            );
            continue;
          }

          final label = cache.getLabelById(labelId);
          if (label == null) continue;
          final color =
              colorFromCssHex(label.color, substitute: Colors.blueGrey);
          chips.add(
            _QuickFilterChip(
              label: label.name,
              color: color,
              onDeleted: () => context
                  .read<JournalPageCubit>()
                  .toggleSelectedLabelId(label.id),
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    context.messages.tasksQuickFilterLabelsActiveTitle,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed:
                        context.read<JournalPageCubit>().clearSelectedLabelIds,
                    child: Text(context.messages.tasksQuickFilterClear),
                  ),
                ],
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: chips,
              ),
            ],
          ),
        );
      },
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
      onDeleted: onDeleted,
      deleteIcon: const Icon(Icons.close, size: 16),
      deleteIconColor: Theme.of(context).colorScheme.onSurfaceVariant,
    );
  }
}
