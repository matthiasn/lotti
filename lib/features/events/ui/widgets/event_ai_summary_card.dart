import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/state/event_agent_providers.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/cards/modern_base_card.dart';

/// Event-detail summary card backed by the event agent.
///
/// Shows the agent's living recap (its report `tldr`, falling back to the
/// report body) with a refresh control that re-wakes the agent. When no event
/// agent is attached it falls back to [fallbackSummary] (the legacy passive
/// summary), and renders nothing when there is neither an agent nor a fallback.
///
/// The event's **rating and cover are never shown or touched here** — the agent
/// has no authority over them, so this card never surfaces or edits them.
class EventAiSummaryCard extends ConsumerWidget {
  const EventAiSummaryCard({
    required this.eventId,
    this.fallbackSummary,
    super.key,
  });

  final String eventId;

  /// The legacy passive summary, shown only when no event agent is attached.
  final String? fallbackSummary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final agent = ref
        .watch(eventAgentProvider(eventId))
        .value
        ?.mapOrNull(agent: (a) => a);

    if (agent == null) {
      final fallback = fallbackSummary?.trim();
      if (fallback == null || fallback.isEmpty) {
        return const SizedBox.shrink();
      }
      return _RecapCard(body: fallback);
    }

    final report = ref
        .watch(agentReportProvider(agent.agentId))
        .value
        ?.mapOrNull(agentReport: (r) => r);

    final tldr = report?.tldr?.trim();
    final content = report?.content.trim();
    final body = (tldr != null && tldr.isNotEmpty)
        ? tldr
        : (content != null && content.isNotEmpty ? content : null);

    return _RecapCard(
      body: body,
      onRefresh: () =>
          ref.read(eventAgentServiceProvider).triggerReanalysis(agent.agentId),
    );
  }
}

class _RecapCard extends StatelessWidget {
  const _RecapCard({this.body, this.onRefresh});

  /// The recap text. When `null` the card shows the awaiting-content hint.
  final String? body;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final cs = context.colorScheme;
    final styles = tokens.typography.styles;
    final hasBody = body != null;

    return ModernBaseCard(
      isEnhanced: true,
      padding: EdgeInsets.all(tokens.spacing.step4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, size: 16, color: cs.primary),
              SizedBox(width: tokens.spacing.step2),
              Text(
                context.messages.eventsSummaryTitle,
                style: styles.subtitle.subtitle2.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              if (onRefresh != null)
                IconButton(
                  onPressed: onRefresh,
                  visualDensity: VisualDensity.compact,
                  iconSize: 18,
                  color: cs.onSurfaceVariant,
                  tooltip: context.messages.eventsRegenerateSummary,
                  icon: const Icon(Icons.refresh),
                ),
            ],
          ),
          SizedBox(height: tokens.spacing.step2),
          Text(
            hasBody ? body! : context.messages.eventsRecapAwaitingContent,
            style: hasBody
                ? styles.body.bodyLarge.copyWith(color: cs.onSurface)
                : styles.body.bodyMedium.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
