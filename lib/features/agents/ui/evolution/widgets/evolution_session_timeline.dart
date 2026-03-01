import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/ui/agent_date_format.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/gamey/colors.dart';

/// Vertical timeline of [EvolutionSessionEntity] records.
///
/// Each node shows session number, status badge, date, and optional feedback
/// summary excerpt.
class EvolutionSessionTimeline extends ConsumerWidget {
  const EvolutionSessionTimeline({
    required this.templateId,
    super.key,
  });

  final String templateId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(evolutionSessionsProvider(templateId));

    return sessionsAsync.when(
      data: (sessions) {
        final typed = sessions.whereType<EvolutionSessionEntity>().toList();
        if (typed.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                context.messages.agentEvolutionNoSessions,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 14,
                ),
              ),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < typed.length; i++)
              _TimelineNode(
                session: typed[i],
                isLast: i == typed.length - 1,
              ),
          ],
        );
      },
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _TimelineNode extends StatelessWidget {
  const _TimelineNode({
    required this.session,
    required this.isLast,
  });

  final EvolutionSessionEntity session;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(session.status);
    final messages = context.messages;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline rail
          SizedBox(
            width: 32,
            child: Column(
              children: [
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: statusColor,
                    border: Border.all(
                      color: statusColor.withValues(alpha: 0.4),
                      width: 2,
                    ),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        messages.agentEvolutionSessionTitle(
                          session.sessionNumber,
                        ),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _StatusBadge(status: session.status),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    formatAgentDateTime(session.createdAt),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 12,
                    ),
                  ),
                  if (session.status == EvolutionSessionStatus.completed &&
                      session.proposedVersionId != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      context.messages.agentEvolutionVersionProposed,
                      style: TextStyle(
                        color: GameyColors.primaryGreen.withValues(alpha: 0.7),
                        fontSize: 12,
                      ),
                    ),
                  ],
                  if (session.feedbackSummary != null &&
                      session.feedbackSummary!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      session.feedbackSummary!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Color _statusColor(EvolutionSessionStatus status) {
  return switch (status) {
    EvolutionSessionStatus.completed => GameyColors.primaryGreen,
    EvolutionSessionStatus.abandoned => GameyColors.primaryRed,
    EvolutionSessionStatus.active => GameyColors.primaryBlue,
  };
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final EvolutionSessionStatus status;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(status);

    final label = switch (status) {
      EvolutionSessionStatus.completed =>
        context.messages.agentEvolutionStatusCompleted,
      EvolutionSessionStatus.abandoned =>
        context.messages.agentEvolutionStatusAbandoned,
      EvolutionSessionStatus.active =>
        context.messages.agentEvolutionStatusActive,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
