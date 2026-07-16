import 'package:flutter/material.dart';
import 'package:lotti/features/agents/ui/widgets/agent_markdown_view.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// Calm identity header for the task-agent report.
///
/// Report freshness and wake controls live in the dedicated automation panel;
/// the header keeps only the report identity and optional playback control.
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

    return Padding(
      padding: EdgeInsets.all(tokens.spacing.cardPadding),
      child: Row(
        children: [
          Container(
            width: tokens.spacing.step9,
            height: tokens.spacing.step9,
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
          SizedBox(width: tokens.spacing.step4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  messages.aiCardTitle,
                  style: tokens.typography.styles.subtitle.subtitle1.copyWith(
                    color: ai.titleText,
                  ),
                ),
                if (displayName != null && displayName.isNotEmpty) ...[
                  SizedBox(height: tokens.spacing.step1),
                  Semantics(
                    button: true,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: onAgentTap,
                        borderRadius: BorderRadius.circular(tokens.radii.s),
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            vertical: tokens.spacing.step1,
                          ),
                          child: Text(
                            displayName,
                            style: tokens.typography.styles.others.caption
                                .copyWith(color: ai.metaText),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (playbackControl != null) ...[
            SizedBox(width: tokens.spacing.step4),
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

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final ai = tokens.colors.aiCard;
    final messages = context.messages;
    final bodyStyle = tokens.typography.styles.body.bodySmall.copyWith(
      color: ai.bodyText,
    );
    final hasMore = additionalReport?.trim().isNotEmpty ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (tldr.trim().isNotEmpty)
          SelectionArea(child: AgentMarkdownView(tldr, style: bodyStyle)),
        if (expanded && hasMore) ...[
          SizedBox(height: tokens.spacing.sectionGap),
          SelectionArea(
            child: AgentMarkdownView(additionalReport!, style: bodyStyle),
          ),
        ],
        if (hasMore || expanded) ...[
          SizedBox(height: tokens.spacing.step4),
          Wrap(
            spacing: tokens.spacing.step3,
            runSpacing: tokens.spacing.step3,
            children: [
              if (hasMore)
                DesignSystemButton(
                  key: const ValueKey('taskAgentReportDisclosure'),
                  label: expanded
                      ? messages.aiCardShowLess
                      : messages.aiCardReadMore,
                  trailingIcon: expanded
                      ? Icons.expand_less_rounded
                      : Icons.expand_more_rounded,
                  variant: DesignSystemButtonVariant.tertiary,
                  onPressed: onToggle,
                ),
              if (expanded)
                DesignSystemButton(
                  label: messages.aiCardOpenAgentInternals,
                  leadingIcon: Icons.tune_rounded,
                  variant: DesignSystemButtonVariant.tertiary,
                  onPressed: onOpenInternals,
                ),
            ],
          ),
        ],
      ],
    );
  }
}
