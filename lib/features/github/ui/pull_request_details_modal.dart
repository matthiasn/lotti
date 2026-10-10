import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/pull_request_data.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_modal_action_bar.dart';
import 'package:lotti/features/design_system/components/toasts/design_system_toast.dart';
import 'package:lotti/features/design_system/components/toasts/toast_messenger.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/github/domain/pull_request_summary.dart';
import 'package:lotti/features/github/service/pull_request_summarizer.dart';
import 'package:lotti/features/github/state/github_providers.dart';
import 'package:lotti/features/github/ui/linked_elsewhere.dart';
import 'package:lotti/features/github/ui/pull_request_glyph.dart';
import 'package:lotti/features/github/ui/pull_request_image.dart';
import 'package:lotti/features/github/ui/pull_request_row.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/markdown/agent_markdown_view.dart';
import 'package:lotti/widgets/markdown_link_utils.dart';
import 'package:lotti/widgets/misc/wolt_modal_config.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';
import 'package:lotti/widgets/modal/wide_wolt_dialog_type.dart';
import 'package:material_ui/material_ui.dart';
import 'package:wolt_modal_sheet/wolt_modal_sheet.dart';

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
      // Where the pull request lives, quietly; its number leads its title,
      // which opens the body as the heading.
      titleWidget: ModalUtils.modalTitle(
        context,
        '${entry.data.owner}/${entry.data.repo}',
        quiet: true,
      ),
      // Most of a desktop window: a description lays its screenshots side
      // by side, and in the standard column they stack, each clipped.
      modalTypeBuilderOverride: (modalContext) =>
          MediaQuery.sizeOf(modalContext).width < WoltModalConfig.pageBreakpoint
          ? WoltModalType.bottomSheet()
          : const WideWoltDialogType(),
      // Within reach however long the description runs; at its own width,
      // since a button the width of that dialog would be a band.
      stickyActionBar: DesignSystemModalActionBar(
        glass: true,
        layout: DesignSystemModalActionBarLayout.compactPrimary,
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
    PullRequestSummaryOutcome.coolingDown ||
    PullRequestSummaryOutcome.missing => null,
    PullRequestSummaryOutcome.busy => messages.githubSummaryBusy,
    PullRequestSummaryOutcome.noModel ||
    PullRequestSummaryOutcome.notAllowed => messages.githubSummaryNoModel,
    PullRequestSummaryOutcome.failed => messages.githubSummaryFailed,
  };

  /// Why there is no summary yet, as [blocker] says; null when there is
  /// nothing to tell.
  static String? _whyNoSummary(
    AppLocalizations messages,
    PullRequestSummaryOutcome? blocker,
  ) => switch (blocker) {
    null => messages.githubSummaryOnNextRefresh,
    PullRequestSummaryOutcome.notAllowed => messages.githubSummaryAutomaticOff,
    PullRequestSummaryOutcome.noModel => messages.githubSummaryNoModel,
    PullRequestSummaryOutcome.coolingDown => messages.githubSummaryFailed,
    PullRequestSummaryOutcome.stored ||
    PullRequestSummaryOutcome.upToDate ||
    PullRequestSummaryOutcome.failed ||
    PullRequestSummaryOutcome.busy ||
    PullRequestSummaryOutcome.missing => null,
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
    // One label style for both sections, one body style for all prose: a
    // small ramp — title, label, prose, caption — instead of a new treatment
    // per block.
    final label = styles.others.caption.copyWith(
      color: tokens.colors.text.mediumEmphasis,
    );
    final quiet = styles.body.bodySmall.copyWith(
      color: tokens.colors.text.mediumEmphasis,
    );
    final description = snapshot?.body?.trim() ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // The row's own anatomy, at the size of a heading: the state glyph,
        // the title with its quiet number, the status line under it.
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PullRequestGlyph(
              status: snapshot?.status,
              draft: snapshot?.draft ?? false,
            ),
            SizedBox(width: tokens.spacing.step3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (snapshot != null) ...[
                    PullRequestTitle(
                      number: entry.data.number,
                      title: snapshot.title,
                      // The largest type in the body, a step above the
                      // one-liner, at the semibold every row title carries.
                      style: styles.body.bodyLarge.copyWith(
                        color: tokens.colors.text.highEmphasis,
                        fontWeight: tokens.typography.weight.semiBold,
                      ),
                      maxLines: null,
                    ),
                    SizedBox(height: tokens.spacing.step1),
                  ],
                  Text.rich(
                    TextSpan(children: pullRequestStatusSpans(context, parts)),
                  ),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: tokens.spacing.step5),
        _SummaryCard(
          summary: summary,
          whyNone: summary != null
              ? null
              : ref
                    .watch(pullRequestAutomaticSummaryBlockerProvider(entry.id))
                    .whenData((blocker) => _whyNoSummary(messages, blocker))
                    .value,
          action: DesignSystemButton(
            key: PullRequestDetailsKeys.summarize,
            label: summary == null
                ? messages.githubSummarize
                : messages.githubSummarizeAgain,
            semanticsLabel: _summarizing ? messages.githubSummarizing : null,
            // Outlined: a button by its neutral frame, flush with the card's
            // text, while the card's teal stays with the one-liner.
            variant: DesignSystemButtonVariant.outlined,
            leadingIcon: LottiIcons.aiSpark,
            isLoading: _summarizing,
            onPressed: _summarizing || snapshot == null ? null : _summarize,
          ),
        ),
        SizedBox(height: tokens.spacing.step4),
        // Set apart, and labelled inside its frame as the summary is: this
        // is the pull request's own text, headings and all. Unfilled, so it
        // never reads as a field to type into.
        DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(tokens.radii.l),
            border: Border.all(color: tokens.colors.decorative.level01),
          ),
          child: Padding(
            padding: EdgeInsets.all(tokens.spacing.step4),
            child: Column(
              // Stretched: the card is as wide as the summary's, whatever
              // the description takes — a bounded table no longer fills it.
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(messages.githubDescriptionHeading, style: label),
                SizedBox(height: tokens.spacing.step2),
                if (description.isEmpty)
                  Text(messages.githubNoDescription, style: quiet)
                else
                  // Medium ink, as the summary's prose is: the agent's
                  // reading leads, the raw description supports it.
                  // Its images are loaded, unlike a model's: the text is
                  // the pull request's own, shown because the user opened
                  // it, and each image is what the "Add to task" action is
                  // offered on. None is shown wider than the text, which
                  // each image reads from here, as a table cell would not
                  // tell it.
                  LayoutBuilder(
                    builder: (context, constraints) =>
                        PullRequestDescriptionWidth(
                          maxWidth: constraints.maxWidth,
                          shares: tableSharesOf(description),
                          child: AgentMarkdownView(
                            description,
                            style: styles.body.bodySmall.copyWith(
                              color: tokens.colors.text.mediumEmphasis,
                            ),
                            subordinateHeadings: true,
                            imageBuilder: pullRequestImageBuilder(
                              widget.taskId,
                            ),
                          ),
                        ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// The summary an agent wrote of the pull request, on the surface the app
/// gives agent-written text: its one-liner in the agent teal, its TL;DR
/// below, and the action to write it again at its foot — or, before there
/// is one, why not yet and the action to write it.
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.summary,
    required this.whyNone,
    required this.action,
  });

  final PullRequestSummary? summary;
  final String? whyNone;
  final Widget action;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final styles = tokens.typography.styles;
    final ai = tokens.colors.aiCard;
    final body = styles.body.bodySmall.copyWith(color: ai.bodyText);
    final summary = this.summary;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: ai.background,
        borderRadius: BorderRadius.circular(tokens.radii.l),
        border: Border.all(color: ai.border),
      ),
      child: Padding(
        // The description card's inset, so the two read as one pair.
        padding: EdgeInsets.all(tokens.spacing.step4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(LottiIcons.aiSpark, size: IconSizes.xs, color: ai.accent),
                SizedBox(width: tokens.spacing.step2),
                Expanded(
                  child: Text(
                    context.messages.githubSummaryHeading,
                    style: styles.others.caption.copyWith(color: ai.metaText),
                  ),
                ),
              ],
            ),
            if (summary != null) ...[
              if (summary.oneLiner case final oneLiner?) ...[
                SizedBox(height: tokens.spacing.step2),
                Text(
                  oneLiner,
                  style: styles.body.bodyMedium.copyWith(color: ai.accent),
                ),
              ],
              SizedBox(height: tokens.spacing.step2),
              SelectableText(summary.tldr, style: body),
            ] else ...[
              SizedBox(height: tokens.spacing.step2),
              Text(context.messages.githubNoSummaryYet, style: body),
              if (whyNone case final why?)
                Text(
                  why,
                  style: styles.others.caption.copyWith(color: ai.metaText),
                ),
            ],
            // After the text it would rewrite, so both cards open on their
            // label at the same inset.
            SizedBox(height: tokens.spacing.step4),
            action,
          ],
        ),
      ),
    );
  }
}
