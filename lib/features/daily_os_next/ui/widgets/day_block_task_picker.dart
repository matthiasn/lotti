import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/tasks/ui/linked_tasks/task_search_picker_body.dart';
import 'package:lotti/features/tasks/ui/utils.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';
import 'package:material_ui/material_ui.dart';

/// Picks the task a planned block should carry: the tasks feature's own
/// search-and-pick body, over open tasks only — a finished task is not work
/// to plan time for. Resolves with the picked task, or null when dismissed.
Future<Task?> showDayBlockTaskPicker(BuildContext context) {
  return ModalUtils.showSinglePageModal<Task>(
    context: context,
    title: context.messages.dailyOsNextBlockLinkTask,
    padding: EdgeInsets.zero,
    builder: (modalContext) => TaskSearchPickerBody(
      taskStatuses: openTaskStatuses,
      excludeIds: const {},
      onTaskSelected: (task) => Navigator.of(modalContext).pop(task),
    ),
  );
}

/// The picker the Day surface opens to link a block — a seam so the Day
/// page's link flow is testable without the task search's databases.
final dayBlockTaskPickerProvider =
    Provider<Future<Task?> Function(BuildContext context)>(
      (ref) => showDayBlockTaskPicker,
      name: 'dayBlockTaskPickerProvider',
    );
