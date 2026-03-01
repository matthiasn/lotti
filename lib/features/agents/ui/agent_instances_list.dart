import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/ui/agent_badge_widgets.dart';
import 'package:lotti/features/agents/ui/agent_date_format.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/cards/index.dart';

/// Kind filter for the instances list.
enum _InstanceKind { all, taskAgent, evolution }

/// Filterable list of agent instances (task agents + evolution sessions).
///
/// Provides two filter rows:
/// - **Kind filter**: All | Task Agent | Evolution
/// - **Lifecycle filter**: All | Active | Dormant | Destroyed
///   (only applies to task agents)
class AgentInstancesList extends ConsumerStatefulWidget {
  const AgentInstancesList({super.key});

  @override
  ConsumerState<AgentInstancesList> createState() => _AgentInstancesListState();
}

class _AgentInstancesListState extends ConsumerState<AgentInstancesList> {
  _InstanceKind _kindFilter = _InstanceKind.all;
  AgentLifecycle? _lifecycleFilter;

  @override
  Widget build(BuildContext context) {
    final agentsAsync = ref.watch(allAgentInstancesProvider);
    final evolutionAsync = ref.watch(allEvolutionSessionsProvider);

    return Column(
      children: [
        _buildFilters(context),
        Expanded(
          child: _buildContent(context, agentsAsync, evolutionAsync),
        ),
      ],
    );
  }

  Widget _buildFilters(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          // Kind filter
          SegmentedButton<_InstanceKind>(
            segments: [
              ButtonSegment(
                value: _InstanceKind.all,
                label: Text(context.messages.agentInstancesKindAll),
              ),
              ButtonSegment(
                value: _InstanceKind.taskAgent,
                label: Text(context.messages.agentInstancesKindTaskAgent),
              ),
              ButtonSegment(
                value: _InstanceKind.evolution,
                label: Text(context.messages.agentInstancesKindEvolution),
              ),
            ],
            selected: {_kindFilter},
            onSelectionChanged: (selection) {
              setState(() {
                _kindFilter = selection.first;
                // Clear lifecycle filter when switching to evolution
                if (_kindFilter == _InstanceKind.evolution) {
                  _lifecycleFilter = null;
                }
              });
            },
          ),
          if (_kindFilter != _InstanceKind.evolution) ...[
            const SizedBox(height: 8),
            // Lifecycle filter (task agents only)
            SegmentedButton<AgentLifecycle?>(
              segments: [
                ButtonSegment<AgentLifecycle?>(
                  value: null,
                  label: Text(context.messages.agentInstancesFilterAll),
                ),
                ButtonSegment(
                  value: AgentLifecycle.active,
                  label: Text(context.messages.agentInstancesFilterActive),
                ),
                ButtonSegment(
                  value: AgentLifecycle.dormant,
                  label: Text(context.messages.agentInstancesFilterDormant),
                ),
                ButtonSegment(
                  value: AgentLifecycle.destroyed,
                  label: Text(context.messages.agentInstancesFilterDestroyed),
                ),
              ],
              selected: {_lifecycleFilter},
              onSelectionChanged: (selection) {
                setState(() => _lifecycleFilter = selection.first);
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    AsyncValue<List<AgentDomainEntity>> agentsAsync,
    AsyncValue<List<AgentDomainEntity>> evolutionAsync,
  ) {
    final needsAgents = _kindFilter != _InstanceKind.evolution;
    final needsEvolutions = _kindFilter != _InstanceKind.taskAgent;

    final agents = agentsAsync.value;
    final evolutions = evolutionAsync.value;

    if ((needsAgents && agentsAsync.isLoading && agents == null) ||
        (needsEvolutions && evolutionAsync.isLoading && evolutions == null)) {
      return const Center(child: CircularProgressIndicator());
    }

    if ((needsAgents && agentsAsync.hasError && agents == null) ||
        (needsEvolutions && evolutionAsync.hasError && evolutions == null)) {
      return Center(
        child: Text(
          context.messages.commonError,
          style: context.textTheme.bodyMedium?.copyWith(
            color: context.colorScheme.error,
          ),
        ),
      );
    }

    final items = <_InstanceItem>[];

    // Add task agents
    if (_kindFilter != _InstanceKind.evolution) {
      for (final entity in agents ?? <AgentDomainEntity>[]) {
        final agent = entity.mapOrNull(agent: (a) => a);
        if (agent == null) continue;
        if (_lifecycleFilter != null && agent.lifecycle != _lifecycleFilter) {
          continue;
        }
        items.add(_InstanceItem.taskAgent(agent));
      }
    }

    // Add evolution sessions
    if (_kindFilter != _InstanceKind.taskAgent) {
      for (final entity in evolutions ?? <AgentDomainEntity>[]) {
        final session = entity.mapOrNull(evolutionSession: (s) => s);
        if (session == null) continue;
        items.add(_InstanceItem.evolution(session));
      }
    }

    // Sort by most recent activity
    items.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.smart_toy_outlined,
              size: 64,
              color: Theme.of(context).disabledColor,
            ),
            const SizedBox(height: 16),
            Text(
              context.messages.agentInstancesEmptyList,
              style: context.textTheme.titleMedium?.copyWith(
                color: Theme.of(context).disabledColor,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: item.map(
            taskAgent: (agent) => _TaskAgentCard(agent: agent),
            evolution: (session) => _EvolutionSessionCard(session: session),
          ),
        );
      },
    );
  }
}

/// Unified instance item for sorting across kinds.
sealed class _InstanceItem {
  factory _InstanceItem.taskAgent(AgentIdentityEntity agent) = _TaskAgentItem;
  factory _InstanceItem.evolution(EvolutionSessionEntity session) =
      _EvolutionItem;

  DateTime get updatedAt;

  T map<T>({
    required T Function(AgentIdentityEntity agent) taskAgent,
    required T Function(EvolutionSessionEntity session) evolution,
  });
}

class _TaskAgentItem implements _InstanceItem {
  _TaskAgentItem(this.agent);
  final AgentIdentityEntity agent;

  @override
  DateTime get updatedAt => agent.updatedAt;

  @override
  T map<T>({
    required T Function(AgentIdentityEntity agent) taskAgent,
    required T Function(EvolutionSessionEntity session) evolution,
  }) =>
      taskAgent(agent);
}

class _EvolutionItem implements _InstanceItem {
  _EvolutionItem(this.session);
  final EvolutionSessionEntity session;

  @override
  DateTime get updatedAt => session.updatedAt;

  @override
  T map<T>({
    required T Function(AgentIdentityEntity agent) taskAgent,
    required T Function(EvolutionSessionEntity session) evolution,
  }) =>
      evolution(session);
}

class _TaskAgentCard extends ConsumerWidget {
  const _TaskAgentCard({required this.agent});

  final AgentIdentityEntity agent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isRunningAsync = ref.watch(agentIsRunningProvider(agent.agentId));
    final isRunning = isRunningAsync.value ?? false;
    final templateAsync = ref.watch(templateForAgentProvider(agent.agentId));
    final templateName =
        templateAsync.value?.mapOrNull(agentTemplate: (t) => t.displayName);

    return ModernBaseCard(
      onTap: () => beamToNamed('/settings/agents/instances/${agent.agentId}'),
      padding: EdgeInsets.zero,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Icon(
          Icons.smart_toy_outlined,
          size: 32,
          color: isRunning
              ? context.colorScheme.primary
              : context.colorScheme.onSurfaceVariant,
        ),
        title: Text(
          agent.displayName,
          style: context.textTheme.titleMedium,
        ),
        subtitle: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: AppTheme.spacingSmall,
          runSpacing: AppTheme.spacingXSmall,
          children: [
            AgentBadge(
              label: context.messages.agentInstancesKindTaskAgent,
              color: context.colorScheme.primary,
            ),
            AgentLifecycleBadge(lifecycle: agent.lifecycle),
            if (templateName != null)
              Text(
                templateName,
                style: context.textTheme.bodySmall?.copyWith(
                  color: context.colorScheme.onSurfaceVariant,
                ),
              ),
            Text(
              formatAgentDateTime(agent.updatedAt),
              style: context.textTheme.bodySmall?.copyWith(
                color: context.colorScheme.outline,
              ),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isRunning)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: context.colorScheme.primary,
                  ),
                ),
              ),
            Icon(
              Icons.chevron_right,
              color: context.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

class _EvolutionSessionCard extends StatelessWidget {
  const _EvolutionSessionCard({required this.session});

  final EvolutionSessionEntity session;

  @override
  Widget build(BuildContext context) {
    return ModernBaseCard(
      onTap: () => beamToNamed(
        '/settings/agents/templates/${session.templateId}',
      ),
      padding: EdgeInsets.zero,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Icon(
          Icons.auto_awesome,
          size: 32,
          color: context.colorScheme.tertiary,
        ),
        title: Text(
          context.messages.agentEvolutionSessionTitle(session.sessionNumber),
          style: context.textTheme.titleMedium,
        ),
        subtitle: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: AppTheme.spacingSmall,
          runSpacing: AppTheme.spacingXSmall,
          children: [
            AgentBadge(
              label: context.messages.agentInstancesKindEvolution,
              color: context.colorScheme.tertiary,
            ),
            AgentBadge(
              label: _evolutionStatusLabel(context, session.status),
              color: _evolutionStatusColor(context, session.status),
            ),
            Text(
              formatAgentDateTime(session.updatedAt),
              style: context.textTheme.bodySmall?.copyWith(
                color: context.colorScheme.outline,
              ),
            ),
          ],
        ),
        trailing: Icon(
          Icons.chevron_right,
          color: context.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  String _evolutionStatusLabel(
    BuildContext context,
    EvolutionSessionStatus status,
  ) {
    return switch (status) {
      EvolutionSessionStatus.active =>
        context.messages.agentEvolutionStatusActive,
      EvolutionSessionStatus.completed =>
        context.messages.agentEvolutionStatusCompleted,
      EvolutionSessionStatus.abandoned =>
        context.messages.agentEvolutionStatusAbandoned,
    };
  }

  Color _evolutionStatusColor(
    BuildContext context,
    EvolutionSessionStatus status,
  ) {
    return switch (status) {
      EvolutionSessionStatus.active => context.colorScheme.primary,
      EvolutionSessionStatus.completed => context.colorScheme.tertiary,
      EvolutionSessionStatus.abandoned => context.colorScheme.outline,
    };
  }
}
