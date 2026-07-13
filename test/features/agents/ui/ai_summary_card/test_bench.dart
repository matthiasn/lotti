import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:lotti/database/state/config_flag_provider.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/change_set.dart';
import 'package:lotti/features/agents/model/proposal_ledger.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/state/change_set_providers.dart';
import 'package:lotti/features/agents/state/task_agent_model_providers.dart';
import 'package:lotti/features/agents/state/task_agent_providers.dart';
import 'package:lotti/features/agents/state/unified_suggestion_providers.dart';
import 'package:lotti/features/agents/ui/ai_summary_card.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/resolved_profile.dart';
import 'package:lotti/features/tts/state/tts_audio_player.dart';
import 'package:lotti/features/tts/state/tts_engine_provider.dart';
import 'package:lotti/features/tts/state/tts_model_repository.dart';
import 'package:lotti/utils/consts.dart';

import '../../../../mocks/mocks.dart';
import '../../../../test_helper.dart';
import '../../../tts/test_utils.dart';
import '../../test_data/change_set_factories.dart';
import '../../test_data/entity_factories.dart';

/// Default test viewport for the AI-summary-card tests. Wider than
/// the default 390×844 phone bench so the proposal row renders in its
/// comfortable layout (with explicit confirm/reject buttons) — most
/// tests assert against those buttons. Mobile-specific tests can opt
/// into the compact layout by passing a narrower `MediaQueryData`.
const MediaQueryData desktopMediaQueryData = MediaQueryData(
  size: Size(900, 800),
);

final defaultResolvedSetup = ResolvedAgentSetup(
  status: AgentSetupResolutionStatus.resolved,
  profile: ResolvedProfile(
    thinkingModelId: 'test-model',
    thinkingProvider: AiConfigInferenceProvider(
      id: 'test-provider',
      baseUrl: 'https://example.invalid',
      apiKey: 'test-key',
      name: 'Test Provider',
      createdAt: DateTime(2024),
      inferenceProviderType: InferenceProviderType.genericOpenAi,
    ),
  ),
  source: AgentSetupResolutionSource.legacyModel,
);

/// Shared overrides for the "no agent attached" path.
class NoAgentOverrides {
  const NoAgentOverrides();

  List<Override> build() => [
    taskAgentProvider.overrideWith((ref, id) async => null),
  ];
}

/// Test bench for the [AiSummaryCard] tree. Wires every provider it
/// reads with sensible defaults; pass mocks via `confirmationService` /
/// [updateNotifications] / [taskAgentService] to verify dispatch.
class AgentTestBench {
  AgentTestBench({
    this._report,
    this._suggestions = const UnifiedSuggestionList.empty(),
    this._isRunning = false,
    this._state,
    this._enableAgents = true,
    this._enableSummaryTts = false,
    this._template,
    this._identity,
    this._resolvedSetup,
    this._confirmationService,
    this._updateNotifications,
    this._taskAgentService,
    this._ttsEngine,
    this._mediaQueryData = desktopMediaQueryData,
    this.provideAgentIdentity = false,
    this._isRunningOverride,
    this.suggestionListOverride,
    this.onSuggestionResolveStart,
    this._extraOverrides = const [],
    this.width,
  });

  /// Constrains the card to a fixed width, independent of the screen size in
  /// [_mediaQueryData] — used to render the card as it appears inside a narrow
  /// resizable task pane on a wide desktop.
  final double? width;
  final VoidCallback? onSuggestionResolveStart;

  static const String taskId = 'task-001';

  final AgentReportEntity? _report;
  final UnifiedSuggestionList _suggestions;
  final bool _isRunning;
  final AgentStateEntity? _state;
  final bool _enableAgents;
  final bool _enableSummaryTts;
  final AgentTemplateEntity? _template;
  final AgentIdentityEntity? _identity;
  final ResolvedAgentSetup? _resolvedSetup;
  final MockChangeSetConfirmationService? _confirmationService;
  final MockUpdateNotifications? _updateNotifications;
  final MockTaskAgentService? _taskAgentService;

  /// Optional recording TTS engine for the playback tests. Defaults to a
  /// supported [FakeTtsEngine] so the playback control renders regardless of
  /// the host platform.
  final FakeTtsEngine? _ttsEngine;
  final MediaQueryData _mediaQueryData;

  /// When true, also overrides [agentIdentityProvider] (read by the
  /// internals panel) so navigation into the panel resolves without
  /// hitting real infrastructure. The shell otherwise only needs
  /// [taskAgentProvider]; navigation tests opt into this.
  final bool provideAgentIdentity;

  /// Replaces the default static `agentIsRunningProvider` override.
  /// Used by lifecycle tests that drive the running flag from a
  /// [StreamController] to exercise the running-agent refresh merge.
  final Stream<bool> Function(Ref ref, String agentId)? _isRunningOverride;

  /// Replaces the default static `unifiedSuggestionListProvider`
  /// override. Used by tests whose suggestion list reacts to the
  /// running flag (e.g. empties while the agent runs).
  final FutureOr<UnifiedSuggestionList> Function(Ref ref, String taskId)?
  suggestionListOverride;

  /// Extra Riverpod overrides appended after the defaults — e.g. to seed
  /// `proposalSwipeNudgePlayedProvider` so the swipe nudge is treated as
  /// already-shown.
  final List<Override> _extraOverrides;

  Widget build() {
    final identity = _identity ?? makeTestIdentity();
    return RiverpodWidgetTestBench(
      mediaQueryData: _mediaQueryData,
      overrides: [
        configFlagProvider.overrideWith(
          (ref, flagName) => Stream.value(
            flagName == enableAiSummaryTtsFlag
                ? _enableSummaryTts
                : _enableAgents,
          ),
        ),
        taskAgentProvider.overrideWith((ref, id) async => identity),
        taskAgentResolvedSetupProvider.overrideWith(
          (ref, id) async => _resolvedSetup ?? defaultResolvedSetup,
        ),
        taskAgentSetupOptionsProvider.overrideWith(
          (ref) async => const TaskAgentSetupOptions(
            profiles: [],
            models: [],
            providers: [],
          ),
        ),
        agentReportProvider.overrideWith((ref, agentId) async => _report),
        templateForAgentProvider.overrideWith(
          (ref, agentId) async => _template,
        ),
        agentIsRunningProvider.overrideWith(
          _isRunningOverride ?? (ref, agentId) => Stream.value(_isRunning),
        ),
        agentStateProvider.overrideWith(
          (ref, agentId) async => _state,
        ),
        unifiedSuggestionListProvider.overrideWith(
          suggestionListOverride ?? (ref, taskId) async => _suggestions,
        ),
        if (provideAgentIdentity)
          agentIdentityProvider.overrideWith((ref, id) async => identity),
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
        ttsEngineProvider.overrideWithValue(_ttsEngine ?? FakeTtsEngine()),
        ttsAudioPlayerProvider.overrideWithValue(FakeTtsAudioPlayer()),
        ttsModelRepositoryProvider.overrideWithValue(FakeTtsModelRepository()),
        ..._extraOverrides,
      ],
      child: width == null
          ? SingleChildScrollView(
              child: AiSummaryCard(
                taskId: taskId,
                onSuggestionResolveStart: onSuggestionResolveStart,
              ),
            )
          : Align(
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: width,
                child: SingleChildScrollView(
                  child: AiSummaryCard(
                    taskId: taskId,
                    onSuggestionResolveStart: onSuggestionResolveStart,
                  ),
                ),
              ),
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
