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
      return _RecapCard(state: _RecapState.recap, body: fallback);
    }

    void refresh() =>
        ref.read(eventAgentServiceProvider).triggerReanalysis(agent.agentId);

    // unwrapPrevious() keeps the last recap during a background reload (after a
    // wake / sync) instead of dropping to a loading state — honoring the
    // "never flash established UI during background refresh" rule. Loading and
    // error are only ever surfaced on a genuine first load, and they render
    // distinctly so they never masquerade as the awaiting-content hint.
    return ref
        .watch(agentReportProvider(agent.agentId))
        .unwrapPrevious()
        .when(
          skipLoadingOnReload: true,
          data: (value) {
            final report = value?.mapOrNull(agentReport: (r) => r);
            final tldr = report?.tldr?.trim();
            final content = report?.content.trim();
            final body = (tldr != null && tldr.isNotEmpty)
                ? tldr
                : (content != null && content.isNotEmpty ? content : null);
            return _RecapCard(
              state: body != null ? _RecapState.recap : _RecapState.awaiting,
              body: body,
              onRefresh: refresh,
            );
          },
          loading: () =>
              _RecapCard(state: _RecapState.loading, onRefresh: refresh),
          error: (_, _) =>
              _RecapCard(state: _RecapState.error, onRefresh: refresh),
        );
  }
}

enum _RecapState { recap, awaiting, loading, error }

class _RecapCard extends StatelessWidget {
  const _RecapCard({required this.state, this.body, this.onRefresh});

  final _RecapState state;

  /// The recap text, present only when [state] is [_RecapState.recap].
  final String? body;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final cs = context.colorScheme;
    final styles = tokens.typography.styles;

    final bodyWidget = switch (state) {
      _RecapState.recap => Text(
        body!,
        style: styles.body.bodyLarge.copyWith(color: cs.onSurface),
      ),
      _RecapState.awaiting => Text(
        context.messages.eventsRecapAwaitingContent,
        style: styles.body.bodyMedium.copyWith(color: cs.onSurfaceVariant),
      ),
      _RecapState.error => Text(
        context.messages.eventsRecapUnavailable,
        style: styles.body.bodyMedium.copyWith(color: cs.onSurfaceVariant),
      ),
      _RecapState.loading => Padding(
        padding: EdgeInsets.symmetric(vertical: tokens.spacing.step2),
        child: SizedBox(
          width: tokens.spacing.step5,
          height: tokens.spacing.step5,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: cs.onSurfaceVariant,
          ),
        ),
      ),
    };

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
          bodyWidget,
        ],
      ),
    );
  }
}
