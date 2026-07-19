import 'package:flutter/material.dart';
import 'package:lotti/features/agents/ui/widgets/agent_markdown_view.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// Calm identity header for the task-agent report.
///
/// Report freshness and wake controls live in the stale strip and the card
/// footer; the header keeps only the report identity and optional playback
/// control. The whole badge + title + agent-name block is one tap target that
/// opens the agent internals, so the name no longer needs its own oversized
/// touch area.
class TldrHeader extends StatelessWidget {
  const TldrHeader({
    required this.agentName,
    required this.onAgentTap,
    this.playbackControl,
    super.key,
  });

  final String? agentName;
  final VoidCallback onAgentTap;

  /// Riverpod-aware playback control injected by the parent card.
  final Widget? playbackControl;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final ai = tokens.colors.aiCard;
    final messages = context.messages;
    final displayName = agentName?.trim();
    final hasName = displayName != null && displayName.isNotEmpty;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        tokens.spacing.cardPadding,
        tokens.spacing.step4,
        tokens.spacing.cardPadding,
        tokens.spacing.step4,
      ),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              button: true,
              label: hasName
                  ? '${messages.aiCardTitle}. $displayName'
                  : messages.aiCardTitle,
              excludeSemantics: true,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onAgentTap,
                  borderRadius: BorderRadius.circular(tokens.radii.m),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      minHeight: kMinInteractiveDimension,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: tokens.spacing.step8,
                          height: tokens.spacing.step8,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: ai.accentSoft,
                            borderRadius: BorderRadius.circular(tokens.radii.m),
                            border: Border.all(color: ai.border),
                          ),
                          child: Icon(
                            Icons.auto_awesome_rounded,
                            size: tokens.spacing.step6,
                            color: ai.accent,
                          ),
                        ),
                        SizedBox(width: tokens.spacing.step3),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                messages.aiCardTitle,
                                style: tokens
                                    .typography
                                    .styles
                                    .subtitle
                                    .subtitle1
                                    .copyWith(color: ai.titleText),
                              ),
                              if (hasName)
                                Text(
                                  displayName,
                                  style: tokens.typography.styles.others.caption
                                      .copyWith(color: ai.metaText),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (playbackControl != null) ...[
            SizedBox(width: tokens.spacing.step3),
            playbackControl!,
          ],
        ],
      ),
    );
  }
}

/// Report body with its disclosure control placed after the content it owns.
class TldrBody extends StatelessWidget {
  const TldrBody({
    required this.tldr,
    required this.expanded,
    required this.additionalReport,
    required this.onToggle,
    required this.onOpenInternals,
    super.key,
  });

  final String tldr;
  final bool expanded;
  final String? additionalReport;
  final VoidCallback onToggle;
  final VoidCallback onOpenInternals;

  /// Reading-measure cap for the report prose. The card itself stays
  /// full-width, but body lines must not — unbounded desktop widths produce
  /// 150+ character lines. A fixed layout constraint in the tradition of
  /// `SettingsPageLayout.maxContentWidth` / the Daily OS drafting modal;
  /// ~75 characters at the bodySmall size. Public so the freshness strip
  /// below the summary can share the same measure instead of stretching the
  /// full card width.
  static const double maxReadingWidth = 720;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final ai = tokens.colors.aiCard;
    final messages = context.messages;
    // Match entry-editor prose and compact card summaries; the header and
    // card treatment provide the hierarchy without enlarging report text.
    final bodyStyle = tokens.typography.styles.body.bodySmall.copyWith(
      color: ai.bodyText,
    );
    final hasMore = additionalReport?.trim().isNotEmpty ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (tldr.trim().isNotEmpty)
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: maxReadingWidth),
            child: SelectionArea(
              child: AgentMarkdownView(tldr, style: bodyStyle),
            ),
          ),
        if (expanded && hasMore) ...[
          SizedBox(height: tokens.spacing.sectionGap),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: maxReadingWidth),
            child: SelectionArea(
              child: AgentMarkdownView(additionalReport!, style: bodyStyle),
            ),
          ),
        ],
        if (hasMore || expanded) ...[
          SizedBox(height: tokens.spacing.step1),
          Wrap(
            spacing: tokens.spacing.step4,
            runSpacing: tokens.spacing.step2,
            children: [
              if (hasMore)
                _QuietDisclosureLink(
                  key: const ValueKey('taskAgentReportDisclosure'),
                  label: expanded
                      ? messages.aiCardShowLess
                      : messages.aiCardReadMore,
                  icon: expanded
                      ? Icons.expand_less_rounded
                      : Icons.expand_more_rounded,
                  expanded: expanded,
                  onPressed: onToggle,
                ),
              if (expanded)
                _QuietDisclosureLink(
                  label: messages.aiCardOpenAgentInternals,
                  icon: Icons.tune_rounded,
                  onPressed: onOpenInternals,
                ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Quiet text-link disclosure matching the proposals section's History
/// toggle: caption meta-gray with a leading glyph. Disclosures don't spend
/// the accent — the summary they reveal is the hero, not the link.
class _QuietDisclosureLink extends StatelessWidget {
  const _QuietDisclosureLink({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.expanded,
    super.key,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool? expanded;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final ai = tokens.colors.aiCard;
    return MergeSemantics(
      child: Semantics(
        button: true,
        expanded: expanded,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(tokens.radii.s),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: tokens.spacing.step8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: tokens.spacing.step5, color: ai.metaText),
                  SizedBox(width: tokens.spacing.step2),
                  Text(
                    label,
                    style: tokens.typography.styles.others.caption.copyWith(
                      color: ai.metaText,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
