import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/dividers/design_system_divider.dart';
import 'package:lotti/features/design_system/components/lists/design_system_list_item.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/github/state/github_providers.dart';
import 'package:lotti/features/github/ui/link_pull_request_modal.dart';
import 'package:lotti/features/github/ui/pull_request_row.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_ui/material_ui.dart';

/// The task's pull requests, in their own card beside its linked tasks.
///
/// `TaskForm` includes it once the task tracks pull requests, or while one
/// is linked (`taskShowsPullRequestsProvider`). With none linked, the card is a worded action to link one; otherwise each pull
/// request is a [PullRequestRow] and the header carries the action to link
/// another.
class TaskPullRequestsSection extends ConsumerWidget {
  const TaskPullRequestsSection({required this.taskId, super.key});

  final String taskId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(taskPullRequestsProvider(taskId));
    final tokens = context.designTokens;
    final messages = context.messages;
    final radius = BorderRadius.circular(tokens.radii.l);
    void link() => showLinkPullRequestModal(context, taskId: taskId);

    return Padding(
      padding: EdgeInsets.symmetric(vertical: tokens.spacing.step3),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: tokens.colors.background.level02,
          borderRadius: radius,
          border: Border.all(color: tokens.colors.decorative.level01),
        ),
        child: Material(
          type: MaterialType.transparency,
          borderRadius: radius,
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                // On the rows' content edges: their inset, their padding and
                // the focus border they reserve, so the title starts over the
                // row text and the + centres over the rows' menus.
                padding: EdgeInsets.only(
                  left: tokens.spacing.step2 + tokens.spacing.step5,
                  right:
                      tokens.spacing.step2 +
                      tokens.spacing.step5 +
                      tokens.spacing.step1,
                  top: tokens.spacing.step4,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        messages.githubPullRequestsTitle,
                        key: const ValueKey('pull-requests-card-title'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: tokens.typography.styles.subtitle.subtitle2
                            .copyWith(color: tokens.colors.text.highEmphasis),
                      ),
                    ),
                    if (entries.isNotEmpty)
                      // The menus' own width, the glyph centred in it, so the
                      // two share a centre line.
                      SizedBox(
                        width: tokens.spacing.step9,
                        child: Center(
                          child: DesignSystemButton(
                            key: const ValueKey('pull-requests-link'),
                            label: '',
                            semanticsLabel: messages.githubLinkPullRequestTitle,
                            variant: DesignSystemButtonVariant.tertiary,
                            leadingIcon: LottiIcons.add,
                            onPressed: link,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (entries.isEmpty)
                DesignSystemListItem(
                  key: const ValueKey('pull-requests-empty-action'),
                  onTap: link,
                  title: messages.githubLinkPullRequestTitle,
                  titleMaxLines: 2,
                  subtitle: messages.githubLinkPullRequestHint,
                  subtitleMaxLines: 2,
                  subtitleEmphasis: tokens.colors.text.lowEmphasis,
                  size: DesignSystemListItemSize.small,
                  leading: Icon(
                    LottiIcons.link,
                    size: IconSizes.m,
                    color: tokens.colors.interactive.enabled,
                  ),
                )
              else
                // Inset, so each row's rounded hover fill floats inside the
                // card's edge instead of running square into it.
                Padding(
                  padding: EdgeInsets.only(
                    left: tokens.spacing.step2,
                    right: tokens.spacing.step2,
                    bottom: tokens.spacing.step2,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0; i < entries.length; i++) ...[
                        // A hairline between rows, the linked-tasks card's
                        // separator, spanning the width a row's hover fill
                        // does; held a step off the rows so a fill's rounded
                        // corners never butt against it.
                        if (i > 0)
                          Padding(
                            padding: EdgeInsets.symmetric(
                              vertical: tokens.spacing.step1,
                            ),
                            child: const DesignSystemDivider(),
                          ),
                        PullRequestRow(
                          key: ValueKey(entries[i].id),
                          taskId: taskId,
                          entry: entries[i],
                        ),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
