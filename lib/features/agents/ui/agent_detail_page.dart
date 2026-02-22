import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/ui/agent_activity_log.dart';
import 'package:lotti/features/agents/ui/agent_controls.dart';
import 'package:lotti/features/agents/ui/agent_conversation_log.dart';
import 'package:lotti/features/agents/ui/agent_date_format.dart';
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

    // Use .value to preserve previous data during stream-triggered reloads,
    // preventing a flash-to-empty while the provider re-fetches.
    final identityEntity = identityAsync.value;

    // Still show initial loading spinner on first load.
    if (identityAsync.isLoading && identityEntity == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (identityAsync.hasError && identityEntity == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Text(
            context.messages.agentDetailErrorLoading(
              identityAsync.error.toString(),
            ),
            style: context.textTheme.bodyMedium?.copyWith(
              color: context.colorScheme.error,
            ),
          ),
        ),
      );
    }

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

    final isRunning =
        ref.watch(agentIsRunningProvider(identity.agentId)).value ?? false;

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
            if (isRunning) ...[
              const SizedBox(width: AppTheme.spacingMedium),
              Tooltip(
                message: context.messages.agentRunningIndicator,
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: context.colorScheme.primary,
                  ),
                ),
              ),
            ],
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
              // Messages (tabbed: Activity, Reports, Conversations, Observations)
              _AgentMessagesSection(agentId: agentId),

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
  }

  Widget _buildStateInfo(
    BuildContext context,
    AsyncValue<AgentDomainEntity?> stateAsync,
  ) {
    // Use .value to preserve previous data during reloads.
    final stateEntity = stateAsync.value;

    if (stateAsync.hasError && stateEntity == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.cardPadding,
          vertical: AppTheme.spacingSmall,
        ),
        child: Text(
          context.messages.agentStateErrorLoading(stateAsync.error.toString()),
          style: context.textTheme.bodyMedium?.copyWith(
            color: context.colorScheme.error,
          ),
        ),
      );
    }

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
  }
}

/// Tabbed section showing agent messages in four views:
/// - Activity: flat chronological log
/// - Reports: report history snapshots
/// - Conversations: grouped by thread (wake cycle)
/// - Observations: observation-only entries, expanded by default
class _AgentMessagesSection extends StatefulWidget {
  const _AgentMessagesSection({required this.agentId});

  final String agentId;

  @override
  State<_AgentMessagesSection> createState() => _AgentMessagesSectionState();
}

class _AgentMessagesSectionState extends State<_AgentMessagesSection>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.cardPadding,
          ),
          child: TabBar(
            controller: _tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: context.messages.agentTabActivity),
              Tab(text: context.messages.agentTabReports),
              Tab(text: context.messages.agentTabConversations),
              Tab(text: context.messages.agentTabObservations),
            ],
          ),
        ),
        const SizedBox(height: AppTheme.spacingSmall),
        IndexedStack(
          index: _tabController.index,
          children: [
            AgentActivityLog(agentId: widget.agentId),
            AgentReportHistoryLog(agentId: widget.agentId),
            AgentConversationLog(agentId: widget.agentId),
            AgentObservationLog(agentId: widget.agentId),
          ],
        ),
      ],
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
