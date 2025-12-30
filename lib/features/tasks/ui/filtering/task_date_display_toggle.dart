import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/journal/state/journal_page_controller.dart';
import 'package:lotti/features/journal/state/journal_page_scope.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';

class TaskDateDisplayToggle extends ConsumerWidget {
  const TaskDateDisplayToggle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showTasks = ref.watch(journalPageScopeProvider);
    final state = ref.watch(journalPageControllerProvider(showTasks));
    final controller =
        ref.read(journalPageControllerProvider(showTasks).notifier);

    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(
        context.messages.tasksShowCreationDate,
        style: context.textTheme.bodySmall,
      ),
      value: state.showCreationDate,
      onChanged: (value) {
        controller.setShowCreationDate(show: value);
        HapticFeedback.selectionClick();
      },
    );
  }
}
