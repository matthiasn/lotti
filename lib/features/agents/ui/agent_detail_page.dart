import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/ui/agent_activity_log.dart';
import 'package:lotti/features/agents/ui/agent_controls.dart';
import 'package:lotti/features/agents/ui/agent_conversation_log.dart';
import 'package:lotti/features/agents/ui/agent_date_format.dart';
import 'package:lotti/features/agents/ui/agent_template_detail_page.dart';
import 'package:lotti/features/agents/ui/agent_token_usage_section.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/themes/theme.dart';

/// Navigate back using Beamer if we're in the settings navigation stack,
/// otherwise use Flutter's pop (e.g. when pushed from task detail).
void _navigateBack(BuildContext context) {
  final navService = getIt<NavService>();
  if (navService.currentPath.startsWith('/settings/agents')) {
    navService.beamBack();
  } else {
    Navigator.of(context).pop();
  }
}

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
        appBar: AppBar(
          leading: IconButton(
            icon: Icon(
              Icons.chevron_left,
              size: 30,
              color: Theme.of(context).colorScheme.outline,
            ),
            onPressed: () => _navigateBack(context),
          ),
        ),
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
        appBar: AppBar(
          leading: IconButton(
            icon: Icon(
              Icons.chevron_left,
              size: 30,
              color: Theme.of(context).colorScheme.outline,
            ),
            onPressed: () => _navigateBack(context),
          ),
        ),
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
        appBar: AppBar(
          leading: IconButton(
            icon: Icon(
              Icons.chevron_left,
              size: 30,
              color: Theme.of(context).colorScheme.outline,
            ),
            onPressed: () => _navigateBack(context),
          ),
        ),
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
        leading: IconButton(
          icon: Icon(
            Icons.chevron_left,
            size: 30,
            color: Theme.of(context).colorScheme.outline,
          ),
          onPressed: () => _navigateBack(context),
        ),
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
          child: _AgentMessagesSection(
            agentId: agentId,
            lifecycle: identity.lifecycle,
            stateAsync: stateAsync,
          ),
        ),
      ),
    );
  }
}

/// Tabbed section showing agent data in five views:
/// - Stats: token usage, template, controls, state info (default)
/// - Reports: report history snapshots
/// - Conversations: grouped by thread (wake cycle)
/// - Observations: observation-only entries, expanded by default
/// - Activity: flat chronological log
class _AgentMessagesSection extends StatefulWidget {
  const _AgentMessagesSection({
    required this.agentId,
    required this.lifecycle,
    required this.stateAsync,
  });

  final String agentId;
  final AgentLifecycle lifecycle;
  final AsyncValue<AgentDomainEntity?> stateAsync;

  @override
  State<_AgentMessagesSection> createState() => _AgentMessagesSectionState();
}

class _AgentMessagesSectionState extends State<_AgentMessagesSection>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
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
              Tab(text: context.messages.agentTabStats),
              Tab(text: context.messages.agentTabReports),
              Tab(text: context.messages.agentTabConversations),
              Tab(text: context.messages.agentTabObservations),
              Tab(text: context.messages.agentTabActivity),
            ],
          ),
        ),
        const SizedBox(height: AppTheme.spacingSmall),
        IndexedStack(
          index: _tabController.index,
          children: [
            _StatsTab(
              agentId: widget.agentId,
              lifecycle: widget.lifecycle,
              stateAsync: widget.stateAsync,
            ),
            AgentReportHistoryLog(agentId: widget.agentId),
            AgentConversationLog(agentId: widget.agentId),
            AgentObservationLog(agentId: widget.agentId),
            AgentActivityLog(agentId: widget.agentId),
          ],
        ),
      ],
    );
  }
}

/// Stats tab content: token usage, template, controls, and state info.
class _StatsTab extends StatelessWidget {
  const _StatsTab({
    required this.agentId,
    required this.lifecycle,
    required this.stateAsync,
  });

  final String agentId;
  final AgentLifecycle lifecycle;
  final AsyncValue<AgentDomainEntity?> stateAsync;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AgentTokenUsageSection(agentId: agentId),
        const Divider(indent: 16, endIndent: 16),
        _TemplateSection(agentId: agentId),
        const Divider(indent: 16, endIndent: 16),
        AgentControls(agentId: agentId, lifecycle: lifecycle),
        const Divider(indent: 16, endIndent: 16),
        _AgentStateSection(stateAsync: stateAsync),
      ],
    );
  }
}

/// Shows the agent state info (revision, wake count, failures, dates).
class _AgentStateSection extends StatelessWidget {
  const _AgentStateSection({required this.stateAsync});

  final AsyncValue<AgentDomainEntity?> stateAsync;

  @override
  Widget build(BuildContext context) {
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

/// Shows the template assigned to this agent, if any.
class _TemplateSection extends ConsumerWidget {
  const _TemplateSection({required this.agentId});

  final String agentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final templateAsync = ref.watch(templateForAgentProvider(agentId));
    final template = templateAsync.value?.mapOrNull(agentTemplate: (e) => e);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.cardPadding,
        vertical: AppTheme.spacingSmall,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.messages.agentTemplateAssignedLabel,
            style: context.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppTheme.spacingSmall),
          if (templateAsync.isLoading && template == null)
            const SizedBox(
              height: 24,
              width: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else if (templateAsync.hasError && template == null)
            Text(
              context.messages.commonError,
              style: context.textTheme.bodySmall?.copyWith(
                color: context.colorScheme.error,
              ),
            )
          else if (template != null)
            ActionChip(
              avatar: Icon(
                Icons.smart_toy_outlined,
                size: 16,
                color: context.colorScheme.primary,
              ),
              label: Text(template.displayName),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => AgentTemplateDetailPage(
                      templateId: template.id,
                    ),
                  ),
                );
              },
            )
          else
            Text(
              context.messages.agentTemplateNoneAssigned,
              style: context.textTheme.bodySmall?.copyWith(
                color: context.colorScheme.onSurfaceVariant,
              ),
            ),
          const SizedBox(height: AppTheme.spacingXSmall),
          Text(
            context.messages.agentTemplateSwitchHint,
            style: context.textTheme.bodySmall?.copyWith(
              color: context.colorScheme.onSurfaceVariant,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
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
