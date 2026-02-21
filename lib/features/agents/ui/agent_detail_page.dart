import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/ui/agent_activity_log.dart';
import 'package:lotti/features/agents/ui/agent_controls.dart';
import 'package:lotti/features/agents/ui/agent_date_format.dart';
import 'package:lotti/features/agents/ui/agent_report_section.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';

/// Detail page for a single agent.
///
/// Watches the agent's identity, state, and latest report, and renders them
/// in a scrollable layout with controls for lifecycle management.
class AgentDetailPage extends ConsumerWidget {
  const AgentDetailPage({
    required this.agentId,
    super.key,
  });

  final String agentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final identityAsync = ref.watch(agentIdentityProvider(agentId));
    final stateAsync = ref.watch(agentStateProvider(agentId));
    final reportAsync = ref.watch(agentReportProvider(agentId));

    return identityAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Text(
            context.messages.agentDetailErrorLoading(error.toString()),
            style: context.textTheme.bodyMedium?.copyWith(
              color: context.colorScheme.error,
            ),
          ),
        ),
      ),
      data: (identityEntity) {
        if (identityEntity == null) {
          return Scaffold(
            appBar: AppBar(),
            body: Center(
              child: Text(
                context.messages.agentDetailNotFound,
                style: context.textTheme.bodyLarge,
              ),
            ),
          );
        }

        final identity = identityEntity.mapOrNull(agent: (e) => e);
        if (identity == null) {
          return Scaffold(
            appBar: AppBar(),
            body: Center(
              child: Text(
                context.messages.agentDetailUnexpectedType,
                style: context.textTheme.bodyLarge,
              ),
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Row(
              children: [
                Flexible(
                  child: Text(
                    identity.displayName,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: AppTheme.spacingSmall),
                _LifecycleBadge(lifecycle: identity.lifecycle),
              ],
            ),
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(
                bottom: AppTheme.spacingLarge,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Report section
                  _buildReportSection(context, reportAsync),

                  // Activity log heading
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.cardPadding,
                      vertical: AppTheme.spacingSmall,
                    ),
                    child: Text(
                      context.messages.agentActivityLogHeading,
                      style: context.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  AgentActivityLog(agentId: agentId),

                  const Divider(indent: 16, endIndent: 16),

                  // Controls
                  AgentControls(
                    agentId: agentId,
                    lifecycle: identity.lifecycle,
                  ),

                  const Divider(indent: 16, endIndent: 16),

                  // State info
                  _buildStateInfo(context, stateAsync),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildReportSection(
    BuildContext context,
    AsyncValue<AgentDomainEntity?> reportAsync,
  ) {
    return reportAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(AppTheme.cardPadding),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Padding(
        padding: const EdgeInsets.all(AppTheme.cardPadding),
        child: Text(
          context.messages.agentReportErrorLoading(error.toString()),
          style: context.textTheme.bodySmall?.copyWith(
            color: context.colorScheme.error,
          ),
        ),
      ),
      data: (reportEntity) {
        if (reportEntity == null) {
          return Padding(
            padding: const EdgeInsets.all(AppTheme.cardPadding),
            child: Text(
              context.messages.agentReportNone,
              style: context.textTheme.bodyMedium?.copyWith(
                color: context.colorScheme.onSurfaceVariant,
              ),
            ),
          );
        }

        final report = reportEntity.mapOrNull(agentReport: (e) => e);
        if (report == null) return const SizedBox.shrink();

        return AgentReportSection(content: report.content);
      },
    );
  }

  Widget _buildStateInfo(
    BuildContext context,
    AsyncValue<AgentDomainEntity?> stateAsync,
  ) {
    return stateAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(AppTheme.cardPadding),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Padding(
        padding: const EdgeInsets.all(AppTheme.cardPadding),
        child: Text(
          context.messages.agentStateErrorLoading(error.toString()),
          style: context.textTheme.bodySmall?.copyWith(
            color: context.colorScheme.error,
          ),
        ),
      ),
      data: (stateEntity) {
        if (stateEntity == null) return const SizedBox.shrink();

        final state = stateEntity.mapOrNull(agentState: (e) => e);
        if (state == null) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.cardPadding,
            vertical: AppTheme.spacingSmall,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.messages.agentStateHeading,
                style: context.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppTheme.spacingSmall),
              _StateRow(
                label: context.messages.agentStateRevision,
                value: state.revision.toString(),
              ),
              _StateRow(
                label: context.messages.agentStateWakeCount,
                value: state.wakeCounter.toString(),
              ),
              _StateRow(
                label: context.messages.agentStateConsecutiveFailures,
                value: state.consecutiveFailureCount.toString(),
              ),
              if (state.lastWakeAt != null)
                _StateRow(
                  label: context.messages.agentStateLastWake,
                  value: formatAgentDateTime(state.lastWakeAt!),
                ),
              if (state.nextWakeAt != null)
                _StateRow(
                  label: context.messages.agentStateNextWake,
                  value: formatAgentDateTime(state.nextWakeAt!),
                ),
              if (state.sleepUntil != null)
                _StateRow(
                  label: context.messages.agentStateSleepingUntil,
                  value: formatAgentDateTime(state.sleepUntil!),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _LifecycleBadge extends StatelessWidget {
  const _LifecycleBadge({required this.lifecycle});

  final AgentLifecycle lifecycle;

  @override
  Widget build(BuildContext context) {
    final (label, color) = _lifecycleStyle(context, lifecycle);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingSmall,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppTheme.spacingXSmall),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: context.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  (String, Color) _lifecycleStyle(
    BuildContext context,
    AgentLifecycle lifecycle,
  ) {
    final scheme = context.colorScheme;
    final l10n = context.messages;
    return switch (lifecycle) {
      AgentLifecycle.created => (l10n.agentLifecycleCreated, scheme.tertiary),
      AgentLifecycle.active => (l10n.agentLifecycleActive, scheme.primary),
      AgentLifecycle.dormant => (l10n.agentLifecyclePaused, scheme.secondary),
      AgentLifecycle.destroyed => (l10n.agentLifecycleDestroyed, scheme.error),
    };
  }
}

class _StateRow extends StatelessWidget {
  const _StateRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacingXSmall),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: context.textTheme.bodySmall?.copyWith(
              color: context.colorScheme.onSurfaceVariant,
            ),
          ),
          Text(
            value,
            style: context.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
