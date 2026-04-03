import 'package:flutter/material.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/ritual_summary.dart';
import 'package:lotti/features/agents/ui/agent_date_format.dart';
import 'package:lotti/features/agents/ui/evolution/widgets/feedback_helpers.dart';
import 'package:lotti/features/agents/ui/widgets/agent_markdown_view.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/cards/modern_base_card.dart';

class RitualSessionHistoryCard extends StatelessWidget {
  const RitualSessionHistoryCard({
    required this.entry,
    super.key,
  });

  final RitualSessionHistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final session = entry.session;
    final recap = entry.recap;
    final recapTldr = recap?.tldr.trim();
    final summary = (recapTldr != null && recapTldr.isNotEmpty)
        ? recapTldr
        : session.feedbackSummary?.trim();
    final recapMarkdown = recap?.recapMarkdown.trim();
    final approvedChangeSummary = recap?.approvedChangeSummary?.trim();

    return ModernBaseCard(
      margin: EdgeInsets.only(bottom: tokens.spacing.step4),
      padding: EdgeInsets.zero,
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
        ),
        child: ExpansionTile(
          tilePadding: EdgeInsets.symmetric(
            horizontal: tokens.spacing.step5,
            vertical: tokens.spacing.step3,
          ),
          childrenPadding: EdgeInsets.fromLTRB(
            tokens.spacing.step5,
            0,
            tokens.spacing.step5,
            tokens.spacing.step5,
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.messages.agentEvolutionSessionTitle(
                  session.sessionNumber,
                ),
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: tokens.spacing.step2),
              Text(
                formatAgentDateTime(session.completedAt ?? session.createdAt),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: context.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _StatusRow(status: session.status),
                if (summary != null && summary.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    summary,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
                if (recap != null && recap.categoryRatings.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: tokens.spacing.step3,
                    runSpacing: tokens.spacing.step3,
                    children: recap.categoryRatings.entries.map((entry) {
                      return _RatingChip(
                        label: _ratingLabelForKey(context, entry.key),
                        rating: entry.value,
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
          children: [
            if (recapMarkdown != null && recapMarkdown.isNotEmpty)
              _Section(
                title: context.messages.agentRitualSummaryRecapHeading,
                child: AgentMarkdownView(recapMarkdown),
              ),
            if (approvedChangeSummary != null &&
                approvedChangeSummary.isNotEmpty)
              _Section(
                title:
                    context.messages.agentRitualSummaryApprovedChangesHeading,
                child: AgentMarkdownView(approvedChangeSummary),
              ),
            if (recap != null && recap.transcript.isNotEmpty)
              _Section(
                title: context.messages.agentRitualSummaryConversationHeading,
                child: Column(
                  children: recap.transcript.map((turn) {
                    final role = turn['role'] ?? 'assistant';
                    final text = turn['text'] ?? '';
                    return Padding(
                      padding: EdgeInsets.only(bottom: tokens.spacing.step4),
                      child: _TranscriptTurn(
                        role: role,
                        text: text,
                      ),
                    );
                  }).toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

String _ratingLabelForKey(BuildContext context, String key) {
  for (final category in FeedbackCategory.values) {
    if (category.name == key) {
      return feedbackCategoryLabel(context, category);
    }
  }

  final normalized = key
      .replaceAllMapped(
        RegExp('([a-z0-9])([A-Z])'),
        (match) => '${match.group(1)} ${match.group(2)}',
      )
      .replaceAll(RegExp(r'[_\-]+'), ' ')
      .trim();

  if (normalized.isEmpty) {
    return feedbackCategoryLabel(context, FeedbackCategory.general);
  }

  return normalized
      .split(RegExp(r'\s+'))
      .map((word) {
        if (word.isEmpty) return word;
        return '${word[0].toUpperCase()}${word.substring(1)}';
      })
      .join(' ');
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.status});

  final EvolutionSessionStatus status;

  @override
  Widget build(BuildContext context) {
    final label = switch (status) {
      EvolutionSessionStatus.completed =>
        context.messages.agentEvolutionStatusCompleted,
      EvolutionSessionStatus.abandoned =>
        context.messages.agentEvolutionStatusAbandoned,
      EvolutionSessionStatus.active =>
        context.messages.agentEvolutionStatusActive,
    };

    final color = switch (status) {
      EvolutionSessionStatus.completed => context.colorScheme.primary,
      EvolutionSessionStatus.abandoned => context.colorScheme.error,
      EvolutionSessionStatus.active => context.colorScheme.tertiary,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _RatingChip extends StatelessWidget {
  const _RatingChip({
    required this.label,
    required this.rating,
  });

  final String label;
  final int rating;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: context.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.45,
        ),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label $rating/5',
        style: Theme.of(context).textTheme.labelMedium,
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;

    return Padding(
      padding: EdgeInsets.only(top: tokens.spacing.step5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: tokens.spacing.step3),
          child,
        ],
      ),
    );
  }
}

class _TranscriptTurn extends StatelessWidget {
  const _TranscriptTurn({
    required this.role,
    required this.text,
  });

  final String role;
  final String text;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final isUser = role == 'user';
    final accent = isUser
        ? context.colorScheme.tertiary
        : context.colorScheme.primary;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(tokens.spacing.step4),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(tokens.radii.m),
        border: Border.all(
          color: accent.withValues(alpha: 0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isUser
                ? context.messages.agentRitualSummaryRoleUser
                : context.messages.agentRitualSummaryRoleAssistant,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: accent,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          AgentMarkdownView(text),
        ],
      ),
    );
  }
}
