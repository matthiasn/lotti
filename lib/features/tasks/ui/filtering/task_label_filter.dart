import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/journal/state/journal_page_controller.dart';
import 'package:lotti/features/journal/state/journal_page_scope.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/utils/color.dart';
import 'package:lotti/widgets/search/filter_choice_chip.dart';

class TaskLabelFilter extends ConsumerStatefulWidget {
  const TaskLabelFilter({super.key});

  @override
  ConsumerState<TaskLabelFilter> createState() => _TaskLabelFilterState();
}

class _TaskLabelFilterState extends ConsumerState<TaskLabelFilter> {
  bool _showAll = false;

  @override
  Widget build(BuildContext context) {
    final labels = getIt<EntitiesCacheService>().sortedLabels;

    if (labels.isEmpty) {
      return const SizedBox.shrink();
    }

    final showTasks = ref.watch(journalPageScopeProvider);
    final state = ref.watch(journalPageControllerProvider(showTasks));
    final controller =
        ref.read(journalPageControllerProvider(showTasks).notifier);

    var labelCandidates = _showAll
        ? labels
        : labels.where((label) {
            final isSelected = state.selectedLabelIds.contains(label.id);
            return isSelected;
          }).toList();

    if (!_showAll && labelCandidates.isEmpty) {
      labelCandidates = labels.take(8).toList();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Text(
          context.messages.tasksLabelFilterTitle,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 5),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ...labelCandidates.map((label) {
              final isSelected = state.selectedLabelIds.contains(label.id);
              final color = colorFromCssHex(
                label.color,
                substitute: Colors.blueGrey,
              );
              return FilterChoiceChip(
                label: label.name,
                selectedColor: color,
                isSelected: isSelected,
                onTap: () => controller.toggleSelectedLabelId(label.id),
              );
            }),
            FilterChoiceChip(
              label: context.messages.tasksLabelFilterUnlabeled,
              selectedColor: Colors.grey,
              isSelected: state.selectedLabelIds.contains(''),
              onTap: () => controller.toggleSelectedLabelId(''),
            ),
            FilterChoiceChip(
              label: context.messages.tasksLabelFilterAll,
              selectedColor: Colors.grey,
              isSelected: state.selectedLabelIds.isEmpty,
              onTap: controller.clearSelectedLabelIds,
            ),
            if (!_showAll)
              FilterChoiceChip(
                label: '...',
                selectedColor: Colors.grey,
                isSelected: _showAll,
                onTap: () => setState(() {
                  _showAll = true;
                }),
              ),
          ],
        ),
      ],
    );
  }
}
