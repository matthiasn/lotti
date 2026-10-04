import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/design_system/components/action_modal/ds_action_row.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/github/state/github_providers.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/providers/task_focus_controller.dart';
import 'package:material_ui/material_ui.dart';

/// The "Add" sheet's row that turns pull request tracking on for task
/// [taskId]: it gives the task its Pull requests section, and scrolls the
/// page to it.
///
/// The sheet lists it only while the task has no such section and this
/// device may start tracking pull requests (`gitHubTrackingAvailableProvider`)
/// — once the section is there, the section itself is the way in.
class TrackPullRequestsItem extends ConsumerWidget {
  const TrackPullRequestsItem(this.taskId, {super.key});

  final String taskId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DsActionRow(
      tone: DsActionRowTone.accent,
      icon: LottiIcons.merge,
      title: context.messages.githubTrackPullRequests,
      subtitle: context.messages.githubTrackPullRequestsHint,
      trailing: DsActionRowTrailing.add,
      onTap: () async {
        final tracked = await ref
            .read(pullRequestRepositoryProvider)
            .track(taskId);
        if (!context.mounted) return;
        // Before the sheet closes, while this row's ref is still usable: the
        // page holds the intent and scrolls once the section has mounted.
        if (tracked) {
          ref
              .read(taskFocusControllerProvider(taskId).notifier)
              .publishPullRequestsFocus();
        }
        Navigator.of(context).pop();
      },
    );
  }
}

/// The github feature's create-entry action for a task (wired into
/// `JournalDetailSlots.taskCreateAction`): offers pull request tracking while
/// GitHub tracking is available and the task does not show its pull requests
/// yet. Once the section shows, the section is the way in and the row stands
/// down.
Widget? pullRequestTrackingAction(WidgetRef ref, String taskId) =>
    ref.watch(gitHubTrackingAvailableProvider) &&
        !ref.watch(taskShowsPullRequestsProvider(taskId))
    ? TrackPullRequestsItem(taskId)
    : null;
