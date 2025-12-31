import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/journal/state/journal_page_controller.dart';
import 'package:lotti/features/journal/state/journal_page_scope.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';

class TaskCoverArtDisplayToggle extends ConsumerWidget {
  const TaskCoverArtDisplayToggle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showTasks = ref.watch(journalPageScopeProvider);
    final state = ref.watch(journalPageControllerProvider(showTasks));
    final controller =
        ref.read(journalPageControllerProvider(showTasks).notifier);

    return Theme(
      data: Theme.of(context).copyWith(
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        hoverColor: Colors.transparent,
      ),
      child: SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(
          context.messages.tasksShowCoverArt,
          style: context.textTheme.bodySmall,
        ),
        value: state.showCoverArt,
        onChanged: (value) {
          controller.setShowCoverArt(show: value);
          HapticFeedback.selectionClick();
        },
      ),
    );
  }
}
