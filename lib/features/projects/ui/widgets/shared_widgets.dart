import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:lotti/classes/project_data.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/agents/ui/report_content_parser.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/projects/state/project_health_metrics.dart';
import 'package:lotti/features/projects/ui/widgets/project_health_indicator.dart';
import 'package:lotti/features/projects/ui/widgets/showcase/showcase_palette.dart';
import 'package:lotti/features/projects/ui/widgets/showcase/showcase_status_helpers.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:url_launcher/url_launcher.dart';

/// A small coloured tag displaying a category icon and label.
class CategoryTag extends StatelessWidget {
  const CategoryTag({
    required this.label,
    required this.icon,
    required this.color,
    this.onTap,
    super.key,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final child = _ShowcaseMetaTag(
      label: label,
      icon: icon,
      backgroundColor: color,
      foregroundColor: ShowcasePalette.tagText(context),
    );

    if (onTap == null) {
      return child;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(tokens.radii.xs),
        onTap: onTap,
        child: child,
      ),
    );
  }
}

class ProjectHealthBandTag extends StatelessWidget {
  const ProjectHealthBandTag({
    required this.band,
    super.key,
  });

  final ProjectHealthBand band;

  @override
  Widget build(BuildContext context) {
    final (label, color, icon) = projectHealthBandAttributes(context, band);

    return _ShowcaseMetaTag(
      label: label,
      icon: icon,
      backgroundColor: color.withValues(alpha: 0.24),
      foregroundColor: color,
      borderColor: color.withValues(alpha: 0.42),
    );
  }
}

/// A pill showing the project status icon and label, optionally larger with
/// an expand chevron.
class ProjectStatusPill extends StatelessWidget {
  const ProjectStatusPill({
    required this.status,
    this.large = false,
    this.onTap,
    super.key,
  });

  final ProjectStatus status;
  final bool large;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final statusColor = showcaseProjectStatusColor(context, status);
    final child = Container(
      constraints: BoxConstraints(
        minHeight: large
            ? tokens.typography.lineHeight.subtitle2 + tokens.spacing.step2
            : tokens.spacing.step5 + tokens.spacing.step1,
      ),
      padding: EdgeInsets.symmetric(
        horizontal: large ? tokens.spacing.step3 : tokens.spacing.step2,
        vertical: large ? tokens.spacing.step2 : tokens.spacing.step1,
      ),
      decoration: BoxDecoration(
        color: ShowcasePalette.subtleFill(context),
        borderRadius: BorderRadius.circular(tokens.radii.badgesPills),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ProjectStatusIcon(
            status: status,
            size: large
                ? tokens.typography.lineHeight.caption
                : tokens.typography.size.caption,
            color: statusColor,
          ),
          SizedBox(width: tokens.spacing.step1),
          Text(
            showcaseProjectStatusLabel(context, status),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            softWrap: false,
            style:
                (large
                        ? tokens.typography.styles.subtitle.subtitle2
                        : tokens.typography.styles.others.caption)
                    .copyWith(
                      color: ShowcasePalette.highText(context),
                      height: 1,
                    ),
          ),
          if (large) ...[
            SizedBox(width: tokens.spacing.step1),
            Icon(
              Icons.unfold_more_rounded,
              size: tokens.typography.lineHeight.caption,
              color: ShowcasePalette.mediumText(context),
            ),
          ],
        ],
      ),
    );

    if (onTap == null) {
      return child;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(tokens.radii.badgesPills),
        onTap: onTap,
        child: child,
      ),
    );
  }
}

class _ShowcaseMetaTag extends StatelessWidget {
  const _ShowcaseMetaTag({
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
    this.icon,
    this.iconWidget,
    this.borderColor,
  }) : assert(
         icon != null || iconWidget != null,
         'Either icon or iconWidget must be provided.',
       );

  final String label;
  final Color backgroundColor;
  final Color foregroundColor;
  final IconData? icon;
  final Widget? iconWidget;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;

    return Container(
      constraints: BoxConstraints(
        minHeight: tokens.spacing.step5 + tokens.spacing.step1,
      ),
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.step2,
        vertical: tokens.spacing.step1,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(tokens.radii.xs),
        border: borderColor == null ? null : Border.all(color: borderColor!),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          iconWidget ??
              Icon(
                icon,
                size: tokens.typography.size.caption,
                color: foregroundColor,
              ),
          SizedBox(width: tokens.spacing.step1),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
              style: tokens.typography.styles.others.caption.copyWith(
                color: foregroundColor,
                height: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A compact status icon + label used in the project list row.
class ProjectStatusLabel extends StatelessWidget {
  const ProjectStatusLabel({required this.status, super.key});

  final ProjectStatus status;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ProjectStatusIcon(
          status: status,
          size: tokens.typography.lineHeight.caption,
          color: showcaseProjectStatusColor(context, status),
        ),
        SizedBox(width: tokens.spacing.step1),
        Text(
          showcaseProjectStatusLabel(context, status),
          style: tokens.typography.styles.body.bodySmall.copyWith(
            color: ShowcasePalette.highText(context),
          ),
        ),
      ],
    );
  }
}

class _ProjectStatusIcon extends StatelessWidget {
  const _ProjectStatusIcon({
    required this.status,
    required this.size,
    required this.color,
  });

  final ProjectStatus status;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final assetName = switch (status) {
      ProjectActive() => 'assets/design_system/project_status_active.svg',
      ProjectCompleted() => 'assets/design_system/project_status_completed.svg',
      ProjectArchived() => 'assets/design_system/project_status_archived.svg',
      _ => null,
    };

    if (assetName != null) {
      return SvgPicture.asset(
        assetName,
        width: size,
        height: size,
        colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      );
    }

    return Icon(
      showcaseProjectStatusIcon(status),
      size: size,
      color: color,
    );
  }
}

/// A pill showing a task's status icon and localised label.
class TaskStatePill extends StatelessWidget {
  const TaskStatePill({required this.status, super.key});

  final TaskStatus status;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final label = status.localizedLabel(context);
    final icon = switch (status) {
      TaskOpen() => Icons.radio_button_unchecked_rounded,
      TaskInProgress() => Icons.play_arrow_rounded,
      TaskGroomed() => Icons.circle_outlined,
      TaskBlocked() => Icons.warning_amber_rounded,
      TaskOnHold() => Icons.pause_circle_outline_rounded,
      TaskDone() => Icons.check_circle_outline_rounded,
      TaskRejected() => Icons.cancel_outlined,
    };

    return Container(
      constraints: BoxConstraints(
        minHeight: tokens.spacing.step5 + tokens.spacing.step1,
      ),
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.step2 + tokens.spacing.step1,
        vertical: tokens.spacing.step1,
      ),
      decoration: BoxDecoration(
        color: ShowcasePalette.subtleFill(context),
        borderRadius: BorderRadius.circular(tokens.radii.badgesPills),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: tokens.typography.lineHeight.caption,
            color: ShowcasePalette.mediumText(context),
          ),
          SizedBox(width: tokens.spacing.step1),
          Text(
            label,
            style: tokens.typography.styles.subtitle.subtitle2.copyWith(
              color: ShowcasePalette.mediumText(context),
            ),
          ),
        ],
      ),
    );
  }
}

/// A circular badge with a count, used in panel headers.
class CountDotBadge extends StatelessWidget {
  const CountDotBadge({required this.count, super.key});

  final int count;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;

    return Container(
      width: tokens.spacing.step5 + tokens.spacing.step1,
      height: tokens.spacing.step5 + tokens.spacing.step1,
      decoration: BoxDecoration(
        color: ShowcasePalette.infoBlue(context),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        '$count',
        style: tokens.typography.styles.others.caption.copyWith(
          color: ShowcasePalette.tagText(context),
        ),
      ),
    );
  }
}

/// A floating add-project action matching the Widgetbook mobile reference.
class ProjectCreateFab extends StatelessWidget {
  const ProjectCreateFab({
    required this.semanticLabel,
    this.onPressed,
    super.key,
  });

  final String semanticLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(24);

    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: semanticLabel,
      child: Material(
        color: Colors.transparent,
        borderRadius: borderRadius,
        child: Ink(
          decoration: BoxDecoration(
            color: ShowcasePalette.teal(context),
            borderRadius: borderRadius,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.22),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: InkWell(
            borderRadius: borderRadius,
            onTap: onPressed,
            child: const SizedBox.square(
              dimension: 56,
              child: Center(
                child: Icon(
                  Icons.add_rounded,
                  size: 24,
                  color: Colors.black,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A bordered panel with a header row, divider, and a list of children
/// separated by dividers.
class ShowcasePanel extends StatelessWidget {
  const ShowcasePanel({
    required this.header,
    required this.itemCount,
    required this.itemBuilder,
    super.key,
  });

  final Widget header;
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;

    return Container(
      decoration: BoxDecoration(
        color: ShowcasePalette.surface(context),
        borderRadius: BorderRadius.circular(tokens.radii.sectionCards),
        border: Border.all(color: ShowcasePalette.border(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              tokens.spacing.step5,
              tokens.spacing.step3 + tokens.spacing.step1,
              tokens.spacing.step5,
              tokens.spacing.step3 + tokens.spacing.step1,
            ),
            child: header,
          ),
          Divider(
            height: 1,
            thickness: 1,
            color: ShowcasePalette.border(context),
          ),
          for (var index = 0; index < itemCount; index++) ...[
            itemBuilder(context, index),
            if (index < itemCount - 1)
              Divider(
                height: 1,
                thickness: 1,
                color: ShowcasePalette.border(context),
              ),
          ],
        ],
      ),
    );
  }
}

/// A centred "no results" message.
class NoResultsPane extends StatelessWidget {
  const NoResultsPane({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;

    return Center(
      child: Text(
        context.messages.projectShowcaseNoResults,
        style: tokens.typography.styles.body.bodyMedium.copyWith(
          color: ShowcasePalette.mediumText(context),
        ),
      ),
    );
  }
}

/// A titled text block with an optional trailing label (e.g. "Updated 2h ago").
class TextSection extends StatelessWidget {
  const TextSection({
    required this.title,
    required this.body,
    this.trailingLabel,
    super.key,
  });

  final String title;
  final String body;
  final String? trailingLabel;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 36,
          child: Row(
            children: [
              Text(
                title,
                style: tokens.typography.styles.subtitle.subtitle2.copyWith(
                  color: ShowcasePalette.highText(context),
                ),
              ),
              const Spacer(),
              if (trailingLabel case final trailingLabel?)
                Text(
                  trailingLabel,
                  style: tokens.typography.styles.others.caption.copyWith(
                    color: ShowcasePalette.mediumText(context),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          body,
          style: tokens.typography.styles.body.bodyMedium.copyWith(
            color: ShowcasePalette.highText(context),
          ),
        ),
      ],
    );
  }
}

class ExpandableReportSection extends StatefulWidget {
  const ExpandableReportSection({
    required this.title,
    required this.body,
    required this.fullContent,
    required this.recommendations,
    this.trailingLabel,
    this.initiallyExpanded = false,
    this.nextWakeAt,
    this.onRefresh,
    this.isRefreshing = false,
    super.key,
  });

  final String title;
  final String body;
  final String fullContent;
  final List<String> recommendations;
  final String? trailingLabel;
  final bool initiallyExpanded;
  final DateTime? nextWakeAt;
  final VoidCallback? onRefresh;
  final bool isRefreshing;

  @override
  State<ExpandableReportSection> createState() =>
      _ExpandableReportSectionState();
}

class _ExpandableReportSectionState extends State<ExpandableReportSection> {
  late bool _expanded = widget.initiallyExpanded;
  Timer? _countdownTimer;
  int _countdownSeconds = 0;

  @override
  void initState() {
    super.initState();
    _syncCountdown();
  }

  @override
  void didUpdateWidget(covariant ExpandableReportSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.nextWakeAt != widget.nextWakeAt ||
        oldWidget.isRefreshing != widget.isRefreshing) {
      _syncCountdown();
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  int _remainingSeconds(DateTime? nextWakeAt) {
    if (nextWakeAt == null) {
      return 0;
    }

    final remaining = nextWakeAt.difference(DateTime.now());
    if (remaining <= Duration.zero) {
      return 0;
    }

    return remaining.inSeconds;
  }

  void _syncCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = null;

    if (widget.isRefreshing) {
      if (mounted) {
        setState(() => _countdownSeconds = 0);
      } else {
        _countdownSeconds = 0;
      }
      return;
    }

    final remaining = _remainingSeconds(widget.nextWakeAt);
    if (remaining <= 0) {
      if (mounted) {
        setState(() => _countdownSeconds = 0);
      } else {
        _countdownSeconds = 0;
      }
      return;
    }

    if (mounted) {
      setState(() => _countdownSeconds = remaining);
    } else {
      _countdownSeconds = remaining;
    }

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      final updated = _remainingSeconds(widget.nextWakeAt);
      setState(() => _countdownSeconds = updated);
      if (updated <= 0) {
        timer.cancel();
      }
    });
  }

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
      final stripped = trimmedContent.replaceFirst(
        RegExp(r'^\s*# [^\n]+\n+'),
        '',
      );
      return stripped.trim().isEmpty ? null : stripped.trim();
    }

    final trimmedAdditional = parsedAdditional?.trim();
    return trimmedAdditional == null || trimmedAdditional.isEmpty
        ? null
        : trimmedAdditional;
  }

  Future<void> _handleLinkTap(String url, String title) async {
    final uri = Uri.tryParse(url);
    if (uri != null) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Widget _buildLink(
    BuildContext context,
    InlineSpan text,
    String url,
    TextStyle style,
  ) {
    final linkColor = ShowcasePalette.teal(context);
    return Semantics(
      link: true,
      child: InkWell(
        onTap: () => _handleLinkTap(url, ''),
        mouseCursor: SystemMouseCursors.click,
        child: Text.rich(
          TextSpan(
            children: [text],
            style: style.copyWith(
              color: linkColor,
              decoration: TextDecoration.underline,
              decorationColor: linkColor,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final parsed = _parseContent();
    final hasAdditionalContent =
        parsed.additional != null && parsed.additional!.trim().isNotEmpty;
    final canExpand = hasAdditionalContent;
    final showCountdown = !widget.isRefreshing && _countdownSeconds > 0;

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
                    if (showCountdown)
                      Padding(
                        padding: EdgeInsets.only(right: tokens.spacing.step2),
                        child: Tooltip(
                          message: context.messages.taskAgentCountdownTooltip(
                            formatCountdown(_countdownSeconds),
                          ),
                          child: ShowcaseCountdownPill(
                            countdownText: formatCountdown(_countdownSeconds),
                          ),
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
                              ? Icons.expand_less_rounded
                              : Icons.expand_more_rounded,
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
                        onLinkTap: _handleLinkTap,
                        linkBuilder: _buildLink,
                      ),
                    ),
                    if (hasAdditionalContent) ...[
                      SizedBox(height: tokens.spacing.step4),
                      SelectionArea(
                        child: GptMarkdown(
                          parsed.additional!,
                          onLinkTap: _handleLinkTap,
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
                    onLinkTap: _handleLinkTap,
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

/// Formats a countdown as `m:ss` for display.
String formatCountdown(int totalSeconds) {
  final minutes = totalSeconds ~/ 60;
  final seconds = totalSeconds % 60;
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}

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

/// A bullet-point list of recommendation strings.
class RecommendationsList extends StatelessWidget {
  const RecommendationsList({required this.items, super.key});

  final List<String> items;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items
          .map(
            (item) => Padding(
              padding: EdgeInsets.only(bottom: tokens.spacing.step1),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '•',
                    style: tokens.typography.styles.others.caption.copyWith(
                      color: ShowcasePalette.teal(context),
                    ),
                  ),
                  SizedBox(width: tokens.spacing.step3),
                  Expanded(
                    child: Text(
                      item,
                      style: tokens.typography.styles.others.caption.copyWith(
                        color: ShowcasePalette.mediumText(context),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}
