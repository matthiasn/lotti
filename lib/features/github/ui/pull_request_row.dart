import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/pull_request_data.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/lists/design_system_list_item.dart';
import 'package:lotti/features/design_system/components/spinners/design_system_spinner.dart';
import 'package:lotti/features/design_system/components/toasts/design_system_toast.dart';
import 'package:lotti/features/design_system/components/toasts/toast_messenger.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/github/service/pull_request_service.dart';
import 'package:lotti/features/github/state/github_providers.dart';
import 'package:lotti/features/github/ui/github_failure_message.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/utils/markdown_link_utils.dart';
import 'package:lotti/utils/relative_age_label.dart';
import 'package:material_ui/material_ui.dart';

/// How a part of the status line reads: its colour backs up a word, never
/// replaces one.
enum PullRequestTone { neutral, good, attention, bad }

/// The words of a pull request's status line, in reading order: its state,
/// how long it has been in it — next to it, so a narrow row that runs out of
/// room never cuts the age off — then its checks, what keeps it from merging
/// and its reviews.
///
/// The age is GitHub's, not Lotti's: since it was opened, merged or closed
/// ([pullRequestStateTime]), never since it was linked or last read. Only
/// what someone can act on is shown: merge conflicts and a branch behind its
/// base, not "blocked", which says only that a required review or check
/// (already on the line) is missing.
///
/// [snapshot] is null before the first successful refresh. [failure] is the
/// last refresh's failure on this device, if it failed. [alsoElsewhere] says
/// another task holds the pull request too — two devices linked it before
/// they synced — and comes first, since only the user can settle it.
List<(String, PullRequestTone)> pullRequestStatusParts(
  AppLocalizations messages, {
  required PullRequestSnapshot? snapshot,
  required PullRequestRefreshFailed? failure,
  required DateTime now,
  bool alsoElsewhere = false,
}) {
  const neutral = PullRequestTone.neutral;
  final elsewhere = [
    if (alsoElsewhere)
      (messages.githubAlsoLinkedElsewhere, PullRequestTone.bad),
  ];
  if (snapshot == null) {
    return [
      ...elsewhere,
      if (failure != null)
        (messages.githubNotRefreshed, PullRequestTone.bad)
      else
        (messages.githubNotRefreshedYet, neutral),
    ];
  }
  final open = snapshot.status == PullRequestStatus.open;
  final checks = snapshot.checks;
  return [
    ...elsewhere,
    switch (snapshot.status) {
      PullRequestStatus.open when snapshot.draft => (
        messages.githubStatusDraft,
        neutral,
      ),
      PullRequestStatus.open => (messages.githubStatusOpen, neutral),
      PullRequestStatus.merged => (
        messages.githubStatusMerged,
        PullRequestTone.good,
      ),
      PullRequestStatus.closed => (messages.githubStatusClosed, neutral),
    },
    if (pullRequestStateTime(snapshot) case final at?)
      (
        relativeAgeOrDateLabel(messages, at: at, now: now, withWeekday: true),
        neutral,
      ),
    if (failure != null) (messages.githubNotRefreshed, PullRequestTone.bad),
    if (open)
      ...switch (checks.rollup) {
        PullRequestCheckRollup.passing => [
          (messages.githubChecksPassing, PullRequestTone.good),
        ],
        PullRequestCheckRollup.failing => [
          (messages.githubChecksFailing(checks.failed), PullRequestTone.bad),
        ],
        PullRequestCheckRollup.pending => [
          (messages.githubChecksPending, PullRequestTone.attention),
        ],
        PullRequestCheckRollup.none => const <(String, PullRequestTone)>[],
      },
    if (open && (checks.checkRunsHidden ?? false))
      (messages.githubChecksHidden, PullRequestTone.attention),
    if (open)
      ...switch (snapshot.mergeability) {
        PullRequestMergeability.conflicting => [
          (messages.githubMergeConflicts, PullRequestTone.bad),
        ],
        PullRequestMergeability.behind => [
          (messages.githubMergeBehind, PullRequestTone.attention),
        ],
        PullRequestMergeability.blocked ||
        PullRequestMergeability.clean ||
        PullRequestMergeability.unknown => const <(String, PullRequestTone)>[],
      },
    if (open)
      ...switch (snapshot.reviews.decision) {
        PullRequestReviewDecision.approved => [
          (messages.githubReviewApproved, PullRequestTone.good),
        ],
        PullRequestReviewDecision.changesRequested => [
          (messages.githubReviewChangesRequested, PullRequestTone.bad),
        ],
        PullRequestReviewDecision.pending => [
          (messages.githubReviewPending, PullRequestTone.attention),
        ],
        PullRequestReviewDecision.none => const <(String, PullRequestTone)>[],
      },
  ];
}

/// When [snapshot]'s pull request entered its state: opened, merged or
/// closed. Null when the snapshot does not say — one stored before it
/// carried the opening reads none until its next refresh.
DateTime? pullRequestStateTime(PullRequestSnapshot snapshot) =>
    switch (snapshot.status) {
      PullRequestStatus.open => snapshot.createdAt,
      PullRequestStatus.merged => snapshot.mergedAt,
      PullRequestStatus.closed => snapshot.closedAt,
    };

/// One linked pull request: its number and title, its status line, and the
/// actions to refresh it, open it on GitHub or unlink it.
///
/// Opening a task refreshes a pull request whose snapshot is stale; the age
/// on its status line ticks on its own, so it never reads younger than the
/// pull request's state is.
class PullRequestRow extends ConsumerStatefulWidget {
  const PullRequestRow({required this.taskId, required this.entry, super.key});

  /// The task the pull request is linked from, which unlinking removes it
  /// from.
  final String taskId;
  final PullRequestEntry entry;

  @override
  ConsumerState<PullRequestRow> createState() => _PullRequestRowState();
}

class _PullRequestRowState extends ConsumerState<PullRequestRow> {
  Timer? _ageTick;
  DateTime? _ageTickFor;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(
        ref
            .read(
              pullRequestRefreshControllerProvider(widget.entry.id).notifier,
            )
            .refreshIfStale(widget.entry),
      );
    });
  }

  @override
  void dispose() {
    _ageTick?.cancel();
    super.dispose();
  }

  /// Re-renders when the age label next changes, once per state time.
  void _armAgeTick(DateTime at) {
    if (_ageTick != null && _ageTickFor == at) return;
    _ageTick?.cancel();
    _ageTickFor = at;
    _ageTick = Timer(
      untilNextAgeBucket(clock.now().difference(at)),
      () {
        _ageTick = null;
        _ageTickFor = null;
        if (mounted) setState(() {});
      },
    );
  }

  Future<void> _refresh() async {
    final controller = ref.read(
      pullRequestRefreshControllerProvider(widget.entry.id).notifier,
    );
    final messenger = ScaffoldMessenger.maybeOf(context);
    final messages = context.messages;
    await controller.refresh(widget.entry);
    if (!mounted) return;
    final failure = ref
        .read(pullRequestRefreshControllerProvider(widget.entry.id))
        .failure;
    if (failure != null) {
      messenger?.showDesignSystemToast(
        tone: DesignSystemToastTone.error,
        title: gitHubFailureMessage(
          messages,
          failure.kind,
          retryAt: failure.retryAt,
        ),
        replaceCurrent: true,
      );
    }
  }

  String _webUrl(PullRequestSnapshot? snapshot) =>
      snapshot?.htmlUrl ??
      'https://github.com/${widget.entry.data.owner}/'
          '${widget.entry.data.repo}/pull/${widget.entry.data.number}';

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final entry = widget.entry;
    final refresh = ref.watch(pullRequestRefreshControllerProvider(entry.id));
    final snapshot = refresh.latest(entry.data.snapshot);
    final stateTime = snapshot == null ? null : pullRequestStateTime(snapshot);
    if (stateTime != null) _armAgeTick(stateTime);

    Color colorOf(PullRequestTone tone) => switch (tone) {
      PullRequestTone.neutral => tokens.colors.text.mediumEmphasis,
      PullRequestTone.good => tokens.colors.alert.success.ink,
      PullRequestTone.attention => tokens.colors.alert.warning.ink,
      PullRequestTone.bad => tokens.colors.alert.error.ink,
    };
    final holders =
        ref.watch(pullRequestHoldersProvider(entry.data.ref)).value ??
        const <String>{};
    final parts = pullRequestStatusParts(
      messages,
      snapshot: snapshot,
      failure: refresh.failure,
      now: clock.now(),
      alsoElsewhere: holders.any((task) => task != widget.taskId),
    );
    // The list item's own subtitle style, recoloured per part: the spans keep
    // its type and change only the ink.
    final caption = tokens.typography.styles.others.caption;
    final separator = TextSpan(
      text: ' · ',
      style: caption.copyWith(color: tokens.colors.text.lowEmphasis),
    );
    final title = snapshot == null
        ? entry.data.ref.toString()
        : '#${entry.data.number} ${snapshot.title}';

    return DesignSystemListItem(
      key: ValueKey('pull-request-row-${entry.id}'),
      onTap: () => handleMarkdownLinkTap(_webUrl(snapshot), title),
      title: title,
      titleMaxLines: 2,
      subtitleSpans: [
        for (var i = 0; i < parts.length; i++) ...[
          if (i > 0) separator,
          TextSpan(
            text: parts[i].$1,
            style: caption.copyWith(color: colorOf(parts[i].$2)),
          ),
        ],
      ],
      subtitleMaxLines: 3,
      size: DesignSystemListItemSize.small,
      leading: Icon(
        LottiIcons.merge,
        size: IconSizes.m,
        color: switch (snapshot?.status) {
          PullRequestStatus.merged => tokens.colors.alert.success.ink,
          PullRequestStatus.closed => tokens.colors.text.lowEmphasis,
          PullRequestStatus.open || null => tokens.colors.interactive.enabled,
        },
      ),
      trailingExtra: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (refresh.refreshing)
            Padding(
              padding: EdgeInsets.all(tokens.spacing.step3),
              child: DesignSystemSpinner(
                key: const Key('pull-request-refreshing'),
                size: IconSizes.m,
                strokeWidth: BorderWidths.emphasis,
                semanticsLabel: messages.githubRefreshingPullRequest,
              ),
            )
          else
            DesignSystemButton(
              key: ValueKey('pull-request-refresh-${entry.id}'),
              label: '',
              semanticsLabel: messages.githubRefreshPullRequest,
              variant: DesignSystemButtonVariant.tertiary,
              leadingIcon: LottiIcons.refresh,
              onPressed: _refresh,
            ),
          _PullRequestMenu(
            entryId: entry.id,
            onOpen: () => handleMarkdownLinkTap(_webUrl(snapshot), title),
            onUnlink: () => ref
                .read(pullRequestRepositoryProvider)
                .unlink(taskId: widget.taskId, ref: entry.data.ref),
          ),
        ],
      ),
    );
  }
}

class _PullRequestMenu extends StatelessWidget {
  const _PullRequestMenu({
    required this.entryId,
    required this.onOpen,
    required this.onUnlink,
  });

  final String entryId;
  final VoidCallback onOpen;
  final Future<bool> Function() onUnlink;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;

    PopupMenuItem<String> item(String value, IconData icon, String label) =>
        PopupMenuItem<String>(
          value: value,
          child: Row(
            children: [
              Icon(icon, size: tokens.spacing.step5),
              SizedBox(width: tokens.spacing.step3),
              Flexible(child: Text(label)),
            ],
          ),
        );

    return Theme(
      data: Theme.of(context).copyWith(
        popupMenuTheme: PopupMenuThemeData(
          color: tokens.colors.background.level03,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(tokens.radii.m),
            side: BorderSide(color: tokens.colors.decorative.level01),
          ),
        ),
      ),
      child: PopupMenuButton<String>(
        key: ValueKey('pull-request-menu-$entryId'),
        tooltip: messages.githubPullRequestActions,
        icon: Icon(
          LottiIcons.moreVertical,
          color: tokens.colors.text.mediumEmphasis,
          size: tokens.spacing.step5,
        ),
        position: PopupMenuPosition.under,
        onSelected: (value) {
          switch (value) {
            case 'open':
              onOpen();
            case 'unlink':
              unawaited(onUnlink());
          }
        },
        itemBuilder: (context) => [
          item('open', LottiIcons.openExternal, messages.githubOpenOnGitHub),
          item('unlink', LottiIcons.linkOff, messages.githubUnlinkPullRequest),
        ],
      ),
    );
  }
}
