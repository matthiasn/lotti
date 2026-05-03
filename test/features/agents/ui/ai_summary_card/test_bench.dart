import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:lotti/database/state/config_flag_provider.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/change_set.dart';
import 'package:lotti/features/agents/model/proposal_ledger.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/state/change_set_providers.dart';
import 'package:lotti/features/agents/state/task_agent_providers.dart';
import 'package:lotti/features/agents/state/unified_suggestion_providers.dart';
import 'package:lotti/features/agents/ui/ai_summary_card.dart';
import 'package:lotti/utils/consts.dart';

import '../../../../mocks/mocks.dart';
import '../../../../test_helper.dart';
import '../../test_data/change_set_factories.dart';
import '../../test_data/entity_factories.dart';

/// Shared overrides for the "no agent attached" path.
class NoAgentOverrides {
  const NoAgentOverrides();

  List<Override> build() => [
    configFlagProvider.overrideWith(
      (ref, flagName) => Stream.value(flagName == enableAgentsFlag),
    ),
    taskAgentProvider.overrideWith((ref, id) async => null),
  ];
}

/// Test bench for the [AiSummaryCard] tree. Wires every provider it
/// reads with sensible defaults; pass mocks via `confirmationService` /
/// [updateNotifications] / [taskAgentService] to verify dispatch.
class AgentTestBench {
  AgentTestBench({
    AgentReportEntity? report,
    UnifiedSuggestionList suggestions = const UnifiedSuggestionList.empty(),
    bool isRunning = false,
    AgentStateEntity? state,
    bool enableAgents = true,
    MockChangeSetConfirmationService? confirmationService,
    MockUpdateNotifications? updateNotifications,
    MockTaskAgentService? taskAgentService,
  }) : _report = report,
       _suggestions = suggestions,
       _isRunning = isRunning,
       _state = state,
       _enableAgents = enableAgents,
       _confirmationService = confirmationService,
       _updateNotifications = updateNotifications,
       _taskAgentService = taskAgentService;

  static const String taskId = 'task-001';

  final AgentReportEntity? _report;
  final UnifiedSuggestionList _suggestions;
  final bool _isRunning;
  final AgentStateEntity? _state;
  final bool _enableAgents;
  final MockChangeSetConfirmationService? _confirmationService;
  final MockUpdateNotifications? _updateNotifications;
  final MockTaskAgentService? _taskAgentService;

  Widget build() {
    final identity = makeTestIdentity();
    return RiverpodWidgetTestBench(
      overrides: [
        configFlagProvider.overrideWith(
          (ref, flagName) => Stream.value(_enableAgents),
        ),
        taskAgentProvider.overrideWith((ref, id) async => identity),
        agentReportProvider.overrideWith((ref, agentId) async => _report),
        templateForAgentProvider.overrideWith((ref, agentId) async => null),
        agentIsRunningProvider.overrideWith(
          (ref, agentId) => Stream.value(_isRunning),
        ),
        agentStateProvider.overrideWith(
          (ref, agentId) async => _state,
        ),
        unifiedSuggestionListProvider.overrideWith(
          (ref, taskId) async => _suggestions,
        ),
        if (_confirmationService != null)
          changeSetConfirmationServiceProvider.overrideWith(
            (ref) => _confirmationService,
          ),
        if (_updateNotifications != null)
          updateNotificationsProvider.overrideWith(
            (ref) => _updateNotifications,
          ),
        if (_taskAgentService != null)
          taskAgentServiceProvider.overrideWith(
            (ref) => _taskAgentService,
          ),
      ],
      child: const SingleChildScrollView(
        child: AiSummaryCard(taskId: taskId),
      ),
    );
  }
}

/// Builds a single-item [PendingSuggestion] for tests.
PendingSuggestion makePending({
  required String id,
  required String toolName,
  required String humanSummary,
  Map<String, dynamic> args = const {},
  ChangeSetEntity? changeSet,
}) {
  final cs =
      changeSet ??
      makeTestChangeSet(
        id: id,
        items: [
          ChangeItem(
            toolName: toolName,
            args: args,
            humanSummary: humanSummary,
          ),
        ],
      );
  return PendingSuggestion(
    changeSet: cs,
    itemIndex: 0,
    item: cs.items.first,
    fingerprint: 'fp-$id',
  );
}

/// Builds a resolved-history [LedgerEntry] for tests.
LedgerEntry makeLedgerEntry({
  required String id,
  required ChangeItemStatus status,
  String toolName = 'set_task_status',
  String humanSummary = 'Set status to GROOMED',
  DateTime? createdAt,
  DateTime? resolvedAt,
}) {
  return LedgerEntry(
    changeSetId: id,
    itemIndex: 0,
    toolName: toolName,
    args: const {},
    humanSummary: humanSummary,
    fingerprint: 'fp-$id',
    status: status,
    createdAt: createdAt ?? DateTime(2026, 5, 4, 9),
    resolvedAt: resolvedAt ?? DateTime(2026, 5, 4, 10),
    resolvedBy: DecisionActor.user,
    verdict: status == ChangeItemStatus.confirmed
        ? ChangeDecisionVerdict.confirmed
        : ChangeDecisionVerdict.rejected,
  );
}
