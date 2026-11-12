import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/pull_request_data.dart';
import 'package:lotti/features/design_system/components/lists/design_system_list_item.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/front_agent/model/front_pull_requests.dart';
import 'package:lotti/features/github/state/github_providers.dart';
import 'package:lotti/features/github/ui/pull_request_row.dart';
import 'package:lotti/features/github/ui/pull_requests_card.dart';
import 'package:lotti/features/tasks/state/task_preview_provider.dart';
import 'package:material_ui/material_ui.dart';

/// Keys the tests and screenshots reach the cards by.
abstract final class FrontPullRequestCardsKeys {
  /// The header of the card of task [taskId], which opens the task.
  static Key task(String taskId) => ValueKey('front-pull-requests-$taskId');
}

/// The pull requests her reply shows, each under the task holding it: one
/// task page pull request card per task, in the order she named them.
///
/// The rows are the task page's own ([PullRequestRow]) — title, the
/// one-liner of its summary, its status line; a tap opens its details, its
/// menu refreshes it, opens it on GitHub or unlinks it — read live from the
/// task, so a refresh, a summary or an unlink shows here too. The card's
/// header is the task, and opens it ([onOpenTask]). A pull request the task
/// no longer holds is left out, and a card with none, or whose task is
/// gone, is not drawn.
class FrontPullRequestCards extends StatelessWidget {
  const FrontPullRequestCards({
    required this.cards,
    required this.onOpenTask,
    super.key,
  });

  final List<FrontPullRequestCard> cards;
  final ValueChanged<String> onOpenTask;

  @override
  Widget build(BuildContext context) {
    final byTask = groupBy(cards, (FrontPullRequestCard card) => card.taskId);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: context.designTokens.spacing.step2,
      children: [
        for (final MapEntry(key: taskId, value: held) in byTask.entries)
          _TaskPullRequests(
            key: ValueKey(taskId),
            taskId: taskId,
            keys: [for (final card in held) card.key],
            onOpenTask: onOpenTask,
          ),
      ],
    );
  }
}

class _TaskPullRequests extends ConsumerWidget {
  const _TaskPullRequests({
    required this.taskId,
    required this.keys,
    required this.onOpenTask,
    super.key,
  });

  final String taskId;
  final List<String> keys;
  final ValueChanged<String> onOpenTask;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final held = ref.watch(taskPullRequestsProvider(taskId));
    final entries = [
      for (final key in keys) ?held.firstWhereOrNull((e) => e.data.key == key),
    ];
    final preview = ref.watch(taskPreviewProvider(taskId));
    final task = preview.value?.task;
    // Gone once the read says so; while it runs, the rows show without it.
    if (entries.isEmpty || (preview.hasValue && task == null)) {
      return const SizedBox.shrink();
    }
    return PullRequestsCard(
      children: [
        Padding(
          padding: EdgeInsets.only(
            left: tokens.spacing.step2,
            right: tokens.spacing.step2,
            top: tokens.spacing.step2,
          ),
          child: DesignSystemListItem(
            key: FrontPullRequestCardsKeys.task(taskId),
            title: task?.data.title ?? '',
            titleMaxLines: 2,
            size: DesignSystemListItemSize.small,
            borderRadius: BorderRadius.circular(tokens.radii.m),
            leading: Icon(
              LottiIcons.checkboxChecked,
              size: IconSizes.m,
              color: tokens.colors.text.mediumEmphasis,
            ),
            trailing: Icon(
              LottiIcons.chevronRight,
              size: IconSizes.m,
              color: tokens.colors.text.lowEmphasis,
            ),
            onTap: () => onOpenTask(taskId),
          ),
        ),
        PullRequestRowList(
          rows: [
            for (final entry in entries)
              PullRequestRow(
                key: ValueKey(entry.id),
                taskId: taskId,
                entry: entry,
              ),
          ],
        ),
      ],
    );
  }
}
