import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/journal/state/journal_page_scope.dart';
import 'package:lotti/features/tasks/ui/filtering/task_filter_content.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';

void showTaskFilterModal(
  BuildContext context, {
  required bool showTasks,
}) {
  final container = ProviderScope.containerOf(context);

  ModalUtils.showSinglePageModal<void>(
    context: context,
    title: context.messages.tasksFilterTitle,
    builder: (_) => const TaskFilterContent(),
    modalDecorator: (child) {
      return UncontrolledProviderScope(
        container: container,
        child: ProviderScope(
          overrides: [
            journalPageScopeProvider.overrideWithValue(showTasks),
          ],
          child: child,
        ),
      );
    },
  );
}
