import 'package:flutter/material.dart';
import 'package:flutter_material_design_icons/flutter_material_design_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/journal/state/journal_page_scope.dart';
import 'package:lotti/features/tasks/ui/filtering/task_filter_modal.dart';
import 'package:lotti/themes/theme.dart';

/// Toolbar icon button that opens the task filter modal via
/// `showTaskFilterModal` for the current journal page scope.
class TaskFilterIcon extends ConsumerWidget {
  const TaskFilterIcon({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showTasks = ref.watch(journalPageScopeProvider);

    return Padding(
      padding: const EdgeInsets.only(right: AppTheme.spacingSmall),
      child: IconButton(
        onPressed: () => showTaskFilterModal(context, showTasks: showTasks),
        icon: const Icon(MdiIcons.filterVariant),
      ),
    );
  }
}
