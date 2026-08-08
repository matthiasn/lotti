import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/template_instance_overview.dart';
import 'package:lotti/features/agents/state/agent_pending_wake_providers.dart';
import 'package:lotti/features/agents/state/template_query_providers.dart';
import 'package:lotti/features/agents/ui/agent_date_format.dart';
import 'package:lotti/features/agents/ui/agent_nav_helpers.dart';
import 'package:lotti/features/agents/ui/instances/instance_view_model.dart';
import 'package:lotti/features/agents/ui/listing/agent_list_data.dart';
import 'package:lotti/features/agents/ui/listing/widgets/agent_list_row.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/nav_service.dart';

/// The template's agent instances, one lazily-built row each.
///
/// Returns slivers rather than a widget so the caller can put it in a
/// `CustomScrollView`: a template accumulates one instance per task, so a
/// mature install has thousands, and the previous `Column`-inside-`ListView`
/// built every one of them on every open of the tab — and buried everything
/// below it out of reach.
class TemplateInstancesSliver extends ConsumerWidget {
  const TemplateInstancesSliver({required this.templateId, super.key});

  final String templateId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final instancesAsync = ref.watch(
      templateInstanceOverviewProvider(templateId),
    );

    return instancesAsync.when(
      loading: () => const SliverToBoxAdapter(
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => SliverToBoxAdapter(
        child: Text(
          context.messages.agentTokenUsageErrorLoading(error.toString()),
          style: tokens.typography.styles.body.bodySmall.copyWith(
            color: tokens.colors.alert.error.defaultColor,
          ),
        ),
      ),
      data: (instances) {
        if (instances.isEmpty) {
          return SliverToBoxAdapter(
            child: Text(
              context.messages.agentTemplateInstancesEmpty,
              style: tokens.typography.styles.body.bodySmall.copyWith(
                color: tokens.colors.text.mediumEmphasis,
              ),
            ),
          );
        }
        return SliverList.builder(
          itemCount: instances.length,
          itemBuilder: (context, index) => TemplateInstanceRow(
            instance: instances[index],
          ),
        );
      },
    );
  }
}

/// One instance row: what it is bound to, when it started, when it last woke,
/// and the two places worth going from here.
///
/// The task title is resolved *here* rather than in the provider — only the
/// rows the user scrolled to pay for that lookup.
class TemplateInstanceRow extends ConsumerWidget {
  const TemplateInstanceRow({required this.instance, super.key});

  final TemplateInstanceOverview instance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final messages = context.messages;
    final taskId = instance.taskId;
    final taskTitle = taskId == null
        ? null
        : ref.watch(pendingWakeTargetTitleProvider(taskId)).value?.trim();

    final numberFormat = NumberFormat.decimalPattern(
      Localizations.localeOf(context).toString(),
    );

    return AgentListRow(
      data: AgentListRowData(
        id: instance.agentId,
        // The task is what the user recognises; the agent's own display name
        // is the fallback for an instance with no task, or one whose title
        // has not resolved yet.
        title: taskTitle != null && taskTitle.isNotEmpty
            ? taskTitle
            : instance.displayName,
        subtitle: _subtitle(context),
        pills: [
          AgentListPill(
            label: agentLifecycleLabel(messages, instance.lifecycle),
            tone: _lifecycleTone(instance.lifecycle),
          ),
        ],
        metaRight: instance.totalTokens == 0
            ? null
            : numberFormat.format(instance.totalTokens),
        // The row itself opens the agent's internals — state, conversation
        // log, reports — which is the "why did it do that" destination.
        onTap: () => navigateToAgentInstance(instance.agentId),
        trailing: taskId == null
            ? null
            : (context) => IconButton(
                icon: const Icon(Icons.open_in_new_rounded, size: 20),
                tooltip: messages.agentTemplateInstanceOpenTask,
                onPressed: () =>
                    getIt<NavService>().beamToNamed('/tasks/$taskId'),
              ),
        sortAt: instance.lastActiveAt,
        searchKey: '',
      ),
    );
  }

  /// Start date first, then last wake: together they say whether an instance
  /// is long-lived and busy, long-lived and stale, or brand new.
  String _subtitle(BuildContext context) {
    final messages = context.messages;
    final started = messages.agentTemplateInstanceStarted(
      formatAgentDateTime(instance.createdAt),
    );
    final lastWakeAt = instance.lastWakeAt;
    final active = lastWakeAt == null
        ? messages.agentTemplateInstanceNeverActive
        : messages.agentTemplateInstanceLastActive(
            formatAgentDateTime(lastWakeAt),
          );
    return '$started · $active';
  }

  AgentListPillTone _lifecycleTone(AgentLifecycle lifecycle) {
    return switch (lifecycle) {
      AgentLifecycle.active => AgentListPillTone.interactive,
      AgentLifecycle.dormant => AgentListPillTone.muted,
      AgentLifecycle.destroyed => AgentListPillTone.error,
      AgentLifecycle.created => AgentListPillTone.info,
    };
  }
}
