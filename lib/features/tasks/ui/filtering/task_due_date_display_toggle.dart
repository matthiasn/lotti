import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/journal/state/journal_page_controller.dart';
import 'package:lotti/features/journal/state/journal_page_scope.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';

class TaskDueDateDisplayToggle extends ConsumerWidget {
  const TaskDueDateDisplayToggle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showTasks = ref.watch(journalPageScopeProvider);
    final state = ref.watch(journalPageControllerProvider(showTasks));
    final controller =
        ref.read(journalPageControllerProvider(showTasks).notifier);

    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(
        context.messages.tasksShowDueDate,
        style: context.textTheme.bodySmall,
      ),
      value: state.showDueDate,
      onChanged: (value) {
        controller.setShowDueDate(show: value);
        HapticFeedback.selectionClick();
      },
    );
  }
}
