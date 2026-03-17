import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/database/state/config_flag_provider.dart';
import 'package:lotti/features/journal/state/journal_page_controller.dart';
import 'package:lotti/features/journal/state/journal_page_scope.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/utils/consts.dart';

/// Toggle for showing/hiding the projects header on the tasks page.
/// Only rendered when the [enableProjectsFlag] feature flag is enabled.
class TaskProjectsHeaderDisplayToggle extends ConsumerWidget {
  const TaskProjectsHeaderDisplayToggle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enableProjects =
        ref.watch(configFlagProvider(enableProjectsFlag)).value ?? false;
    if (!enableProjects) return const SizedBox.shrink();

    final showTasks = ref.watch(journalPageScopeProvider);
    final state = ref.watch(journalPageControllerProvider(showTasks));
    final controller = ref.read(
      journalPageControllerProvider(showTasks).notifier,
    );

    return Theme(
      data: Theme.of(context).copyWith(
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        hoverColor: Colors.transparent,
      ),
      child: SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(
          context.messages.tasksShowProjectsHeader,
          style: context.textTheme.bodySmall,
        ),
        value: state.showProjectsHeader,
        onChanged: (value) {
          controller.setShowProjectsHeader(show: value);
          HapticFeedback.selectionClick();
        },
      ),
    );
  }
}
