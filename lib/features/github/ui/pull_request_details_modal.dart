import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/pull_request_data.dart';
import 'package:lotti/features/agents/ui/widgets/agent_markdown_view.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_modal_action_bar.dart';
import 'package:lotti/features/design_system/components/toasts/design_system_toast.dart';
import 'package:lotti/features/design_system/components/toasts/toast_messenger.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/github/service/pull_request_summarizer.dart';
import 'package:lotti/features/github/state/github_providers.dart';
import 'package:lotti/features/github/ui/linked_elsewhere.dart';
import 'package:lotti/features/github/ui/pull_request_row.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/utils/markdown_link_utils.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';
import 'package:material_ui/material_ui.dart';

/// Keys the tests and screenshots reach the details by.
abstract final class PullRequestDetailsKeys {
  static const summarize = Key('pull_request_details_summarize');
  static const openOnGitHub = Key('pull_request_details_open');
}

/// The pull request of [entry], linked from [taskId], in full: its status
/// line with its size, the one-liner and TL;DR of its summary — with the
/// action to summarise it, or summarise it again — and its own description,
/// with the way to open it on GitHub.
Future<void> showPullRequestDetailsModal(
  BuildContext context, {
  required String taskId,
  required PullRequestEntry entry,
}) =>
    // The bar holds one line: the reference fits it, a title may not, so the
    // title opens the body instead.
    ModalUtils.showSinglePageModal<void>(
      context: context,
      title: entry.data.ref.toString(),
      // Within reach however long the description runs.
      stickyActionBar: DesignSystemModalActionBar(
        glass: true,
        padding: EdgeInsets.all(context.designTokens.spacing.step5),
        primary: DesignSystemButton(
          key: PullRequestDetailsKeys.openOnGitHub,
          label: context.messages.githubOpenOnGitHub,
          leadingIcon: LottiIcons.openExternal,
          size: DesignSystemButtonSize.large,
          fullWidth: true,
          onPressed: () => handleMarkdownLinkTap(
            pullRequestWebUrl(entry),
            entry.data.ref.toString(),
          ),
        ),
      ),
      builder: (modalContext) =>
          PullRequestDetails(taskId: taskId, entry: entry),
    );

/// Where [entry]'s pull request lives on GitHub: the URL GitHub reported,
/// or the one its reference spells before the first read.
String pullRequestWebUrl(PullRequestEntry entry) {
  final data = entry.data;
  return data.snapshot?.htmlUrl ??
      'https://github.com/${data.owner}/${data.repo}/pull/${data.number}';
}

/// The body of [showPullRequestDetailsModal].
class PullRequestDetails extends ConsumerStatefulWidget {
  const PullRequestDetails({
    required this.taskId,
    required this.entry,
    super.key,
  });

  final String taskId;
  final PullRequestEntry entry;

  @override
  ConsumerState<PullRequestDetails> createState() => _PullRequestDetailsState();
}

class _PullRequestDetailsState extends ConsumerState<PullRequestDetails> {
  bool _summarizing = false;

  Future<void> _summarize() async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final messages = context.messages;
    setState(() => _summarizing = true);
    final outcome = await ref
        .read(pullRequestSummarizerProvider)
        .summarize(widget.entry.id, manual: true);
    if (!mounted) return;
    setState(() => _summarizing = false);
    final problem = _problem(messages, outcome);
    if (problem != null) {
      messenger?.showDesignSystemToast(
        tone: DesignSystemToastTone.error,
        title: problem,
        replaceCurrent: true,
      );
    }
  }

  /// What to tell the user when a summary they asked for was not stored;
  /// null when it was, or when there is nothing to say.
  static String? _problem(
    AppLocalizations messages,
    PullRequestSummaryOutcome outcome,
  ) => switch (outcome) {
    PullRequestSummaryOutcome.stored ||
    PullRequestSummaryOutcome.upToDate ||
    PullRequestSummaryOutcome.missing => null,
    PullRequestSummaryOutcome.busy => messages.githubSummaryBusy,
    PullRequestSummaryOutcome.noModel ||
    PullRequestSummaryOutcome.notAllowed => messages.githubSummaryNoModel,
    PullRequestSummaryOutcome.failed => messages.githubSummaryFailed,
  };

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final styles = tokens.typography.styles;
    final entry = widget.entry;
    final snapshot = ref
        .watch(pullRequestRefreshControllerProvider(entry.id))
        .latest(entry.data.snapshot);
    final summary = ref.watch(pullRequestSummaryProvider(entry.id)).value;
    final holders =
        ref.watch(pullRequestHoldersProvider(entry.data.ref)).value ??
        const <String>{};
    final parts = pullRequestStatusParts(
      messages,
      snapshot: snapshot,
      failure: null,
      now: clock.now(),
      alsoLinkedTo: watchLinkedElsewhereTitles(
        ref,
        holders.where((task) => task != widget.taskId),
      ),
    );
    final heading = styles.subtitle.subtitle2.copyWith(
      color: tokens.colors.text.highEmphasis,
    );
    final body = styles.body.bodySmall.copyWith(
      color: tokens.colors.text.highEmphasis,
    );
    final quiet = styles.body.bodySmall.copyWith(
      color: tokens.colors.text.mediumEmphasis,
    );
    final description = snapshot?.body?.trim() ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (snapshot != null) ...[
          Text(
            snapshot.title,
            style: styles.heading.heading3.copyWith(
              color: tokens.colors.text.highEmphasis,
            ),
          ),
          SizedBox(height: tokens.spacing.step2),
        ],
        Text.rich(TextSpan(children: pullRequestStatusSpans(context, parts))),
        if (summary?.oneLiner case final oneLiner?) ...[
          SizedBox(height: tokens.spacing.step4),
          Text(
            oneLiner,
            style: styles.subtitle.subtitle1.copyWith(
              color: tokens.colors.text.highEmphasis,
            ),
          ),
        ],
        SizedBox(height: tokens.spacing.step5),
        Text(messages.githubSummaryHeading, style: heading),
        SizedBox(height: tokens.spacing.step2),
        if (summary != null)
          SelectableText(summary.tldr, style: body)
        else
          Text(messages.githubNoSummaryYet, style: quiet),
        SizedBox(height: tokens.spacing.step3),
        DesignSystemButton(
          key: PullRequestDetailsKeys.summarize,
          label: summary == null
              ? messages.githubSummarize
              : messages.githubSummarizeAgain,
          semanticsLabel: _summarizing ? messages.githubSummarizing : null,
          variant: DesignSystemButtonVariant.secondary,
          leadingIcon: LottiIcons.aiSpark,
          isLoading: _summarizing,
          onPressed: _summarizing || snapshot == null ? null : _summarize,
        ),
        SizedBox(height: tokens.spacing.step5),
        Text(messages.githubDescriptionHeading, style: heading),
        SizedBox(height: tokens.spacing.step2),
        if (description.isEmpty)
          Text(messages.githubNoDescription, style: quiet)
        else
          // Set apart: this is the pull request's own text, headings and
          // all, not a section of the details.
          DecoratedBox(
            decoration: BoxDecoration(
              color: tokens.colors.background.level02,
              borderRadius: BorderRadius.circular(tokens.radii.m),
              border: Border.all(color: tokens.colors.decorative.level01),
            ),
            child: Padding(
              padding: EdgeInsets.all(tokens.spacing.step4),
              child: AgentMarkdownView(description),
            ),
          ),
      ],
    );
  }
}
