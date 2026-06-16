import 'package:flutter/material.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:lotti/features/agents/ui/report_content_parser.dart';
import 'package:lotti/features/agents/ui/wake_countdown_state.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/projects/ui/widgets/showcase/showcase_palette.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/utils/markdown_link_utils.dart';

/// Collapsible "AI report" block: an always-visible TLDR with an optional
/// expandable remainder, plus trailing report controls.
///
/// [body] is the short summary and [fullContent] the complete markdown report;
/// `_parseContent` splits them into a `tldr` and an `additional` section
/// (stripping a leading H1 project title and reconciling an explicit TLDR with
/// the parsed one). The chevron and expand affordance appear only when there is
/// additional content. The header may also show a "updated X ago"
/// [trailingLabel], a live wake countdown when [nextWakeAt] is set, a cancel-×
/// (see [onCancelScheduledWake]), and a refresh button / spinner driven by
/// [onRefresh] and [isRefreshing].
class ExpandableReportSection extends StatefulWidget {
  const ExpandableReportSection({
    required this.title,
    required this.body,
    required this.fullContent,
    this.trailingLabel,
    this.initiallyExpanded = false,
    this.nextWakeAt,
    this.onRefresh,
    this.onCancelScheduledWake,
    this.isRefreshing = false,
    super.key,
  });

  final String title;
  final String body;
  final String fullContent;
  final String? trailingLabel;
  final bool initiallyExpanded;
  final DateTime? nextWakeAt;
  final VoidCallback? onRefresh;

  /// Cancels the scheduled wake whose countdown is rendered next to the
  /// title. When provided alongside a non-null [nextWakeAt] (and the
  /// section is not currently refreshing), an `×` button is shown directly
  /// after the countdown pill — mirroring the task AI-summary cluster.
  final VoidCallback? onCancelScheduledWake;
  final bool isRefreshing;

  @override
  State<ExpandableReportSection> createState() =>
      _ExpandableReportSectionState();
}

class _ExpandableReportSectionState extends State<ExpandableReportSection> {
  late bool _expanded = widget.initiallyExpanded;

  ({String tldr, String? additional}) _parseContent() {
    final body = widget.body.trim();
    final content = widget.fullContent.trim();
    if (content.isEmpty) {
      return (
        tldr: body,
        additional: null,
      );
    }

    final parsed = parseReportContent(content);
    final hasExplicitTldr = body.isNotEmpty && body != content;
    final explicitTldr = hasExplicitTldr ? body : parsed.tldr.trim();
    if (explicitTldr.isEmpty) {
      return (
        tldr: parsed.tldr.trim(),
        additional: parsed.additional,
      );
    }

    if (hasExplicitTldr) {
      final additional = _expandedBody(content, parsed.additional);
      return (
        tldr: explicitTldr,
        additional: additional,
      );
    }

    return (
      tldr: explicitTldr,
      additional: parsed.additional,
    );
  }

  String? _expandedBody(String content, String? parsedAdditional) {
    final trimmedContent = content.trim();
    if (trimmedContent.isEmpty) {
      return null;
    }

    final containsTldrSection =
        RegExp(
          r'(^|\n)## 📋 TLDR\b',
          multiLine: true,
        ).hasMatch(trimmedContent) ||
        RegExp(r'^\*\*TLDR:\*\*', multiLine: true).hasMatch(trimmedContent);
    if (!containsTldrSection) {
      // Strip a leading H1 heading (the project title) that the UI already
      // renders, but preserve the rest of the content for the expanded view.
      final stripped = stripLeadingH1(trimmedContent);
      return stripped.trim().isEmpty ? null : stripped.trim();
    }

    final trimmedAdditional = parsedAdditional?.trim();
    return trimmedAdditional == null || trimmedAdditional.isEmpty
        ? null
        : trimmedAdditional;
  }

  Widget _buildLink(
    BuildContext context,
    InlineSpan text,
    String url,
    TextStyle style,
  ) => buildMarkdownLink(
    context,
    text,
    url,
    style,
    linkColor: ShowcasePalette.teal(context),
  );

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final parsed = _parseContent();
    final hasAdditionalContent =
        parsed.additional != null && parsed.additional!.trim().isNotEmpty;
    final canExpand = hasAdditionalContent;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(tokens.radii.s),
          onTap: canExpand
              ? () => setState(() => _expanded = !_expanded)
              : null,
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: tokens.spacing.step2),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tokens.typography.styles.subtitle.subtitle2.copyWith(
                      color: ShowcasePalette.highText(context),
                    ),
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.trailingLabel case final trailingLabel?)
                      Padding(
                        padding: EdgeInsets.only(right: tokens.spacing.step2),
                        child: Text(
                          trailingLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.right,
                          style: tokens.typography.styles.others.caption
                              .copyWith(
                                color: ShowcasePalette.mediumText(context),
                              ),
                        ),
                      ),
                    if (!widget.isRefreshing && widget.nextWakeAt != null)
                      Padding(
                        padding: EdgeInsets.only(right: tokens.spacing.step2),
                        child: _ReportCountdownPill(
                          nextWakeAt: widget.nextWakeAt!,
                        ),
                      ),
                    if (!widget.isRefreshing &&
                        widget.nextWakeAt != null &&
                        widget.onCancelScheduledWake != null)
                      Padding(
                        padding: EdgeInsets.only(right: tokens.spacing.step1),
                        child: IconButton(
                          icon: Icon(
                            Icons.close_rounded,
                            size: tokens.typography.lineHeight.subtitle2,
                            color: ShowcasePalette.mediumText(context),
                          ),
                          tooltip: context.messages.taskAgentCancelTimerTooltip,
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: BoxConstraints(
                            minWidth: tokens.spacing.step6,
                            minHeight: tokens.spacing.step6,
                          ),
                          onPressed: widget.onCancelScheduledWake,
                        ),
                      ),
                    if (widget.onRefresh != null)
                      Padding(
                        padding: EdgeInsets.only(right: tokens.spacing.step1),
                        child: widget.isRefreshing
                            ? SizedBox.square(
                                dimension:
                                    tokens.typography.lineHeight.subtitle2,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: ShowcasePalette.mediumText(context),
                                ),
                              )
                            : IconButton(
                                icon: Icon(
                                  Icons.refresh_rounded,
                                  size: tokens.typography.lineHeight.subtitle2,
                                  color: ShowcasePalette.mediumText(context),
                                ),
                                tooltip:
                                    context.messages.taskAgentRunNowTooltip,
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                                constraints: BoxConstraints(
                                  minWidth: tokens.spacing.step6,
                                  minHeight: tokens.spacing.step6,
                                ),
                                onPressed: widget.onRefresh,
                              ),
                      ),
                    if (canExpand)
                      Padding(
                        padding: EdgeInsets.only(left: tokens.spacing.step2),
                        child: Icon(
                          _expanded
                              ? Icons.keyboard_arrow_down_rounded
                              : Icons.chevron_right_rounded,
                          size: tokens.typography.lineHeight.bodySmall,
                          color: ShowcasePalette.mediumText(context),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: tokens.spacing.step2),
        AnimatedSize(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeInOut,
          alignment: Alignment.topLeft,
          child: _expanded || !canExpand
              ? Column(
                  key: const ValueKey('expanded-report'),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SelectionArea(
                      child: GptMarkdown(
                        parsed.tldr,
                        onLinkTap: handleMarkdownLinkTap,
                        linkBuilder: _buildLink,
                      ),
                    ),
                    if (hasAdditionalContent) ...[
                      SizedBox(height: tokens.spacing.step4),
                      SelectionArea(
                        child: GptMarkdown(
                          parsed.additional!,
                          onLinkTap: handleMarkdownLinkTap,
                          linkBuilder: _buildLink,
                        ),
                      ),
                    ],
                  ],
                )
              : SelectionArea(
                  key: const ValueKey('collapsed-report'),
                  child: GptMarkdown(
                    parsed.tldr,
                    onLinkTap: handleMarkdownLinkTap,
                    linkBuilder: _buildLink,
                  ),
                ),
        ),
      ],
    );
  }
}

/// Formats a relative "Updated X ago" label from a pair of timestamps.
String showcaseUpdatedLabel(
  BuildContext context, {
  required DateTime updatedAt,
  required DateTime currentTime,
}) {
  final difference = currentTime.difference(updatedAt);

  if (difference.isNegative || difference.inHours < 1) {
    final minutes = difference.inMinutes < 1 ? 1 : difference.inMinutes;
    return context.messages
        .projectShowcaseUpdatedMinutesAgo(minutes)
        .replaceAll(
          ' ↻',
          '',
        );
  }

  return context.messages
      .projectShowcaseUpdatedHoursAgo(difference.inHours)
      .replaceAll(' ↻', '');
}

/// Formats a countdown as `m:ss` below one hour and `h:mm:ss` once an hour
/// cell is needed.
String formatCountdown(int totalSeconds) {
  final clamped = totalSeconds < 0 ? 0 : totalSeconds;
  final hours = clamped ~/ 3600;
  final minutes = (clamped % 3600) ~/ 60;
  final seconds = clamped % 60;
  final ss = seconds.toString().padLeft(2, '0');
  if (hours == 0) {
    return '$minutes:$ss';
  }
  return '$hours:${minutes.toString().padLeft(2, '0')}:$ss';
}

class _ReportCountdownPill extends StatefulWidget {
  const _ReportCountdownPill({
    required this.nextWakeAt,
  });

  final DateTime nextWakeAt;

  @override
  State<_ReportCountdownPill> createState() => _ReportCountdownPillState();
}

class _ReportCountdownPillState extends State<_ReportCountdownPill>
    with WakeCountdownState<_ReportCountdownPill> {
  @override
  DateTime get nextWakeAt => widget.nextWakeAt;

  @override
  void didUpdateWidget(covariant _ReportCountdownPill oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.nextWakeAt != widget.nextWakeAt) {
      resyncCountdown();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (countdownSeconds <= 0) {
      return const SizedBox.shrink();
    }

    final countdownText = formatCountdown(countdownSeconds);
    return Tooltip(
      message: context.messages.taskAgentCountdownTooltip(countdownText),
      child: ShowcaseCountdownPill(countdownText: countdownText),
    );
  }
}

/// Small rounded pill that displays a pre-formatted countdown string (see
/// [formatCountdown]); the live ticking is owned by the caller.
class ShowcaseCountdownPill extends StatelessWidget {
  const ShowcaseCountdownPill({
    required this.countdownText,
    super.key,
  });

  final String countdownText;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;

    return Container(
      constraints: const BoxConstraints(minWidth: 52),
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.step2,
        vertical: tokens.spacing.step1,
      ),
      decoration: BoxDecoration(
        color: ShowcasePalette.subtleFill(context),
        borderRadius: BorderRadius.circular(tokens.radii.badgesPills),
      ),
      child: Text(
        countdownText,
        textAlign: TextAlign.center,
        style: tokens.typography.styles.others.caption.copyWith(
          color: ShowcasePalette.mediumText(context),
          height: 1,
        ),
      ),
    );
  }
}
