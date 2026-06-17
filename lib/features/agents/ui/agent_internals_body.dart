import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/state/task_agent_providers.dart';
import 'package:lotti/features/agents/ui/agent_activity_log.dart';
import 'package:lotti/features/agents/ui/agent_controls.dart';
import 'package:lotti/features/agents/ui/agent_conversation_log.dart';
import 'package:lotti/features/agents/ui/agent_date_format.dart';
import 'package:lotti/features/agents/ui/agent_template_detail_page.dart';
import 'package:lotti/features/agents/ui/agent_token_usage_section.dart';
import 'package:lotti/features/agents/ui/profile_selector.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/state/inference_profile_controller.dart';
import 'package:lotti/features/design_system/components/toasts/design_system_toast.dart';
import 'package:lotti/features/design_system/components/toasts/toast_messenger.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/nav_bar/bottom_nav_safe_navigator.dart';

/// Tabbed body for the agent internals view.
///
/// Hosts the five canonical agent tabs — **Stats**, **Reports**,
/// **Conversations**, **Observations**, **Activity** — that previously
/// lived inline in `AgentDetailPage`. Lifted into its own widget so the
/// same content can render either as the body of the standalone agent
/// detail page or inside the right-side internals panel surfaced from
/// the AI summary card.
class AgentInternalsBody extends StatefulWidget {
  const AgentInternalsBody({
    required this.agentId,
    required this.lifecycle,
    required this.stateAsync,
    super.key,
  });

  final String agentId;
  final AgentLifecycle lifecycle;
  final AsyncValue<AgentDomainEntity?> stateAsync;

  @override
  State<AgentInternalsBody> createState() => _AgentInternalsBodyState();
}

class _AgentInternalsBodyState extends State<AgentInternalsBody>
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
        _ProfileSection(agentId: agentId),
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
            label: context.messages.agentStateWakeCount,
            value: state.wakeCounter.value.toString(),
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
                // Root navigator on mobile so the editor's FormBottomBar
                // clears the floating bottom nav — this push keeps the
                // instance route's URL, so the route-based slide-away can't
                // see it.
                bottomNavSafeNavigatorOf(context).push(
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

/// Shows and allows changing the inference profile for this agent.
class _ProfileSection extends ConsumerWidget {
  const _ProfileSection({required this.agentId});

  final String agentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final identityAsync = ref.watch(agentIdentityProvider(agentId));
    final identity = identityAsync.value?.mapOrNull(agent: (e) => e);
    final profileId = identity?.config.profileId;

    // Resolve profile name.
    final profilesAsync = ref.watch(inferenceProfileControllerProvider);
    final profileName = profilesAsync.value
        ?.whereType<AiConfigInferenceProfile>()
        .where((p) => p.id == profileId)
        .firstOrNull
        ?.name;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.cardPadding,
        vertical: AppTheme.spacingSmall,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.messages.inferenceProfilesTitle,
            style: context.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppTheme.spacingSmall),
          ProfileSelector(
            selectedProfileId: profileId,
            onProfileSelected: (newProfileId) async {
              if (identity == null) return;
              final service = ref.read(taskAgentServiceProvider);
              try {
                await service.updateAgentProfile(
                  agentId: agentId,
                  profileId: newProfileId,
                );
                if (!context.mounted) return;
                ref.invalidate(agentIdentityProvider(agentId));
              } catch (e, stackTrace) {
                developer.log(
                  'updateAgentProfile failed',
                  name: 'AgentInternalsBody',
                  error: e.runtimeType,
                  stackTrace: stackTrace,
                );
                if (!context.mounted) return;
                context.showToast(
                  tone: DesignSystemToastTone.error,
                  title: context.messages.commonError,
                );
              }
            },
          ),
          if (profileName != null) ...[
            const SizedBox(height: AppTheme.spacingXSmall),
            Text(
              profileName,
              style: context.textTheme.bodySmall?.copyWith(
                color: context.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
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
          Expanded(
            child: Text(
              value,
              style: context.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
