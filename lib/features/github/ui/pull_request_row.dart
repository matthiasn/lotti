import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/pull_request_data.dart';
import 'package:lotti/features/design_system/components/lists/design_system_list_item.dart';
import 'package:lotti/features/design_system/components/spinners/design_system_spinner.dart';
import 'package:lotti/features/design_system/components/toasts/design_system_toast.dart';
import 'package:lotti/features/design_system/components/toasts/toast_messenger.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/github/domain/open_pull_request.dart';
import 'package:lotti/features/github/service/pull_request_service.dart';
import 'package:lotti/features/github/state/github_providers.dart';
import 'package:lotti/features/github/ui/github_failure_message.dart';
import 'package:lotti/features/github/ui/linked_elsewhere.dart';
import 'package:lotti/features/github/ui/pull_request_details_modal.dart';
import 'package:lotti/features/github/ui/pull_request_glyph.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/utils/relative_age_label.dart';
import 'package:lotti/widgets/markdown_link_utils.dart';
import 'package:material_ui/material_ui.dart';

/// How a part of the status line reads: its colour backs up a word, never
/// replaces one. [added] and [removed] are the two halves of the size,
/// `+444 −221`, which read as one part.
enum PullRequestTone { neutral, good, attention, bad, added, removed }

/// The words of a pull request's status line, in reading order: its state,
/// how long it has been in it — next to it, so a narrow row that runs out of
/// room never cuts the age off — its size, then its checks, what keeps it
/// from merging and its reviews.
///
/// The age is GitHub's, not Lotti's: since it was opened, merged or closed
/// ([pullRequestStateTime]), never since it was linked or last read. Merge
/// conflicts and a branch behind its base always show; "blocked" only when
/// the line does not already explain it — checks failing or running, or a
/// review requested or changes requested, are what usually block, and are
/// shown. Otherwise a branch rule the line cannot name (resolved
/// conversations, signed commits, a merge queue) is in the way, and "blocked"
/// is the only sign of it.
///
/// [snapshot] is null before the first successful refresh. [failure] is the
/// last refresh's failure on this device, if it failed. [alsoLinkedTo] are
/// the other tasks that hold the pull request too, by title — null for one
/// the viewer may not see. They come first: a pull request serving two tasks
/// is often meant, after the user confirmed it, but two devices that linked
/// it before they synced did it by accident, and only the user can tell.
List<(String, PullRequestTone)> pullRequestStatusParts(
  AppLocalizations messages, {
  required PullRequestSnapshot? snapshot,
  required PullRequestRefreshFailed? failure,
  required DateTime now,
  List<String?> alsoLinkedTo = const [],
}) {
  const neutral = PullRequestTone.neutral;
  final title = soleLinkedElsewhereTitle(alsoLinkedTo);
  final elsewhere = [
    if (alsoLinkedTo.isNotEmpty)
      (
        title != null
            ? messages.githubAlsoLinkedTo(title)
            : messages.githubAlsoLinkedElsewhere(alsoLinkedTo.length),
        PullRequestTone.attention,
      ),
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
      // Red, as GitHub inks it: closed unmerged is the state a user most
      // needs to tell apart from merged, and a neutral word hid it.
      PullRequestStatus.closed => (
        messages.githubStatusClosed,
        PullRequestTone.bad,
      ),
    },
    if (pullRequestStateTime(snapshot) case final at?)
      (
        relativeAgeOrDateLabel(messages, at: at, now: now, withWeekday: true),
        neutral,
      ),
    if (failure != null) (messages.githubNotRefreshed, PullRequestTone.bad),
    if ((snapshot.additions, snapshot.deletions) case (
      final added?,
      final removed?,
    )) ...[
      ('+$added', PullRequestTone.added),
      ('−$removed', PullRequestTone.removed),
    ],
    if (open)
      ...switch (checks.rollup) {
        // Neutral: colour on this line marks what needs a look. Passing
        // checks in green beside the teal one-liner made a row of hues
        // where nothing was wrong.
        PullRequestCheckRollup.passing => [
          (messages.githubChecksPassing, neutral),
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
        PullRequestMergeability.blocked when !_blockExplained(snapshot) => [
          (messages.githubMergeBlocked, PullRequestTone.attention),
        ],
        PullRequestMergeability.blocked ||
        PullRequestMergeability.clean ||
        PullRequestMergeability.unknown => const <(String, PullRequestTone)>[],
      },
    if (open)
      ...switch (snapshot.reviews.decision) {
        PullRequestReviewDecision.approved => [
          (messages.githubReviewApproved, neutral),
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

/// The words of an open pull request's line in the picker, in the order of
/// a linked one's status line: draft first when it is one, then its author,
/// its age and its size — once [size] is known.
List<(String, PullRequestTone)> openPullRequestParts(
  AppLocalizations messages, {
  required OpenPullRequest pr,
  required DateTime now,
  PullRequestSize? size,
}) => [
  if (pr.draft) (messages.githubStatusDraft, PullRequestTone.neutral),
  if (pr.authorLogin case final login?) ('@$login', PullRequestTone.neutral),
  (
    relativeAgeOrDateLabel(
      messages,
      at: pr.createdAt,
      now: now,
      withWeekday: true,
    ),
    PullRequestTone.neutral,
  ),
  if (size case (:final additions, :final deletions)) ...[
    ('+$additions', PullRequestTone.added),
    ('−$deletions', PullRequestTone.removed),
  ],
];

/// Whether the status line already shows what usually blocks a merge:
/// checks failing or still running, or a review outstanding.
bool _blockExplained(PullRequestSnapshot snapshot) =>
    switch (snapshot.checks.rollup) {
      PullRequestCheckRollup.failing || PullRequestCheckRollup.pending => true,
      PullRequestCheckRollup.passing || PullRequestCheckRollup.none => false,
    } ||
    switch (snapshot.reviews.decision) {
      PullRequestReviewDecision.pending ||
      PullRequestReviewDecision.changesRequested => true,
      PullRequestReviewDecision.approved ||
      PullRequestReviewDecision.none => false,
    };

/// [parts] as the spans of one line in the caption style, each in the ink of
/// its tone, separated by a dot — except the two halves of the size, which
/// read as one: `+444 −221`. The size carries a spoken label, so a screen
/// reader says what the signs mean.
///
/// The size ends the first line: what follows it — checks, what keeps the
/// pull request from merging, reviews — starts a second, so the line breaks
/// where its meaning does rather than wherever the width runs out. Should a
/// line still wrap, it breaks before a dot, never after one and never inside
/// the size: each dot is bound to the part it introduces.
List<TextSpan> pullRequestStatusSpans(
  BuildContext context,
  List<(String, PullRequestTone)> parts,
) {
  final tokens = context.designTokens;
  final caption = tokens.typography.styles.others.caption;
  Color colorOf(PullRequestTone tone) => switch (tone) {
    PullRequestTone.neutral => tokens.colors.text.mediumEmphasis,
    PullRequestTone.good ||
    PullRequestTone.added => tokens.colors.alert.success.ink,
    PullRequestTone.attention => tokens.colors.alert.warning.ink,
    PullRequestTone.bad ||
    PullRequestTone.removed => tokens.colors.alert.error.ink,
  };
  final separator = TextSpan(
    text: ' ·\u00A0',
    style: caption.copyWith(color: tokens.colors.text.lowEmphasis),
  );
  return [
    for (var i = 0; i < parts.length; i++) ...[
      if (i > 0 &&
          parts[i].$2 == PullRequestTone.removed &&
          parts[i - 1].$2 == PullRequestTone.added)
        const TextSpan(text: '\u00A0')
      else if (i > 0 && parts[i - 1].$2 == PullRequestTone.removed)
        const TextSpan(text: '\n')
      else if (i > 0)
        separator,
      TextSpan(
        text: parts[i].$1,
        style: caption.copyWith(color: colorOf(parts[i].$2)),
        semanticsLabel: switch (parts[i].$2) {
          PullRequestTone.added when i + 1 < parts.length =>
            context.messages.githubPullRequestSize(
              int.parse(parts[i].$1.substring(1)),
              int.parse(parts[i + 1].$1.substring(1)),
            ),
          PullRequestTone.removed => '',
          _ => null,
        },
      ),
    ],
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

/// One linked pull request: its number and title, the one-liner of its
/// summary once one is written, its status line, and the actions to refresh
/// it, open it on GitHub or unlink it. Tapping it opens its details.
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

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final entry = widget.entry;
    final refresh = ref.watch(pullRequestRefreshControllerProvider(entry.id));
    final snapshot = refresh.latest(entry.data.snapshot);
    final stateTime = snapshot == null ? null : pullRequestStateTime(snapshot);
    if (stateTime != null) _armAgeTick(stateTime);

    final oneLiner = ref
        .watch(pullRequestSummaryProvider(entry.id))
        .value
        ?.oneLiner;
    final holders =
        ref.watch(pullRequestHoldersProvider(entry.data.ref)).value ??
        const <String>{};
    final parts = pullRequestStatusParts(
      messages,
      snapshot: snapshot,
      failure: refresh.failure,
      now: clock.now(),
      alsoLinkedTo: watchLinkedElsewhereTitles(
        ref,
        holders.where((task) => task != widget.taskId),
      ),
    );
    final caption = tokens.typography.styles.others.caption;
    final title = snapshot == null
        ? entry.data.ref.toString()
        : '#${entry.data.number} ${snapshot.title}';

    return DesignSystemListItem(
      key: ValueKey('pull-request-row-${entry.id}'),
      onTap: () => unawaited(
        showPullRequestDetailsModal(
          context,
          taskId: widget.taskId,
          entry: entry,
        ),
      ),
      borderRadius: BorderRadius.circular(tokens.radii.m),
      titleContent: PullRequestTitle(
        number: snapshot == null ? null : entry.data.number,
        title: snapshot?.title ?? title,
        style: pullRequestTitleStyle(context),
        maxLines: 3,
      ),
      // Three lines, three voices: the title, the one-liner in the teal of
      // agent-written text, then the status line. The one-liner keeps a line
      // of its own, so its teal never sits beside the green of an addition.
      subtitleSpans: [
        if (oneLiner != null)
          TextSpan(
            text: '$oneLiner\n',
            style: caption.copyWith(color: tokens.colors.aiCard.accent),
          ),
        ...pullRequestStatusSpans(context, parts),
      ],
      subtitleMaxLines: oneLiner == null ? 3 : 5,
      size: DesignSystemListItemSize.small,
      // Both rails at the title, as the details header holds them: centred
      // on a four-line row, the glyph sat beside the summary line instead.
      leading: Align(
        alignment: Alignment.topCenter,
        child: PullRequestGlyph(
          status: snapshot?.status,
          draft: snapshot?.draft ?? false,
        ),
      ),
      // Refresh lives in the menu: a stale pull request refreshes on its
      // own when the task opens, so the manual refresh is the row's least
      // frequent action, and on a phone its own button cost the title a
      // third of its width. A refresh shows in the menu's own slot, so the
      // row never reflows when one starts.
      // A glyph-tall slot, as the linked-tasks rows reserve: the menu's
      // dots centre on the state glyph rather than on its 48pt button box.
      trailingExtra: Align(
        alignment: Alignment.topCenter,
        child: SizedBox(
          height: tokens.spacing.step7,
          child: Center(
            child: _PullRequestMenu(
              entryId: entry.id,
              refreshing: refresh.refreshing,
              onRefresh: _refresh,
              onOpen: () =>
                  handleMarkdownLinkTap(pullRequestWebUrl(entry), title),
              onUnlink: () => ref
                  .read(pullRequestRepositoryProvider)
                  .unlink(taskId: widget.taskId, ref: entry.data.ref),
            ),
          ),
        ),
      ),
    );
  }
}

class _PullRequestMenu extends StatelessWidget {
  const _PullRequestMenu({
    required this.entryId,
    required this.refreshing,
    required this.onRefresh,
    required this.onOpen,
    required this.onUnlink,
  });

  final String entryId;

  /// A refresh is running: the menu shows it in place of its own glyph, and
  /// offers no second one meanwhile.
  final bool refreshing;
  final VoidCallback onRefresh;
  final VoidCallback onOpen;
  final Future<bool> Function() onUnlink;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;

    PopupMenuItem<String> item(
      String value,
      IconData icon,
      String label, {
      bool enabled = true,
    }) => PopupMenuItem<String>(
      value: value,
      enabled: enabled,
      child: Row(
        children: [
          Icon(icon, size: IconSizes.m),
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
        icon: refreshing
            ? DesignSystemSpinner(
                key: const Key('pull-request-refreshing'),
                size: IconSizes.m,
                semanticsLabel: messages.githubRefreshingPullRequest,
              )
            : Icon(
                LottiIcons.moreVertical,
                color: tokens.colors.text.mediumEmphasis,
                size: IconSizes.m,
              ),
        position: PopupMenuPosition.under,
        onSelected: (value) {
          switch (value) {
            case 'refresh':
              onRefresh();
            case 'open':
              onOpen();
            case 'unlink':
              unawaited(onUnlink());
          }
        },
        itemBuilder: (context) => [
          item(
            'refresh',
            LottiIcons.refresh,
            messages.githubRefreshPullRequest,
            enabled: !refreshing,
          ),
          item('open', LottiIcons.openExternal, messages.githubOpenOnGitHub),
          item('unlink', LottiIcons.linkOff, messages.githubUnlinkPullRequest),
        ],
      ),
    );
  }
}
