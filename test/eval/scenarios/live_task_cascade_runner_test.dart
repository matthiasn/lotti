// Level 2 live task-agent cascade entrypoint.
//
// Runs selected task-agent scenarios as same-task cascades: each
// `appState.taskLogEntries` item is appended before one wake, while reports,
// observations, and proposals persist across wakes. This is a sidecar live
// runner for cascade smoke evidence. It emits one trace per wake with explicit
// cascadeWake metadata while preserving trialIndex for real repeated trials.

@Tags(['eval-live'])
library;

import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/inference_usage.dart';
import 'package:lotti/features/ai/repository/cloud_inference_repository.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/time_service.dart';

import '../../helpers/fallbacks.dart';
import '../../mocks/mocks.dart' show MockPersistenceLogic;
import '../../widget_test_utils.dart';
import '../harness/eval_harness.dart';
import '../harness/live_eval_target.dart';
import '../harness/observing_conversation_repository.dart';
import '../harness/task_agent_eval_bench.dart';
import 'eval_scenario_catalog.dart';
import 'eval_scenarios.dart';

const _runId = String.fromEnvironment('EVAL_RUN');
const _scenarioCatalogPath = String.fromEnvironment(
  kEvalScenarioCatalogPathEnv,
);
const _scenarioCatalogMode = String.fromEnvironment(
  kEvalScenarioCatalogModeEnv,
);
const _scenarioIds = String.fromEnvironment(kEvalScenarioIdsEnv);
const _profileCatalogValue = String.fromEnvironment(kEvalProfilesPathEnv);
const _profileNames = String.fromEnvironment(kEvalProfileNamesEnv);
const _runsRootPath = String.fromEnvironment('EVAL_RUNS_ROOT');
const _protectedTraceAck = String.fromEnvironment(
  'LOTTI_EVAL_PROTECTED_TRACE_ACK',
);

void main() {
  final settings = LiveEvalSettings.fromEnvironment(Platform.environment);

  setUpAll(() async {
    registerAllFallbackValues();
    await setUpTestGetIt(
      additionalSetup: () {
        getIt
          ..registerSingleton<PersistenceLogic>(MockPersistenceLogic())
          ..registerSingleton<TimeService>(TimeService());
      },
    );
  });

  tearDownAll(tearDownTestGetIt);

  test('maps cascade wake-specific checks into trace Level 1 checks', () {
    const output = AgentRunOutput(
      success: true,
      usage: InferenceUsage.empty,
      report: AgentReportRecord(
        oneLiner: 'No checklist update.',
        tldr: 'No checklist update.',
      ),
    );

    final checks = _cascadeWakeLevel1Checks(
      scenario: taskWorkflowChecklistTranscriptCascadeScenario,
      profile: kFrontierProfile,
      wakeIndex: 1,
      output: output,
    );
    final expectedToolCalls = checks.singleWhere(
      (check) => check.name == 'expected_tool_calls',
    );

    expect(expectedToolCalls.passed, isFalse);
    expect(expectedToolCalls.detail, contains('update_checklist_items'));
  });

  test(
    'produces live task-agent cascade traces',
    () async {
      final rawProfiles = _loadProfileCatalog().profiles;
      settings.validateProfiles(rawProfiles);
      final catalog = EvalScenarioCatalogLoader.fromEnvironment(
        Platform.environment,
        dartDefinePath: _scenarioCatalogPathFromDefine(),
        dartDefineMode: _scenarioCatalogModeFromDefine(),
        dartDefineScenarioIds: _scenarioIdsFromDefine(),
      );
      _validateCascadeScenarios(catalog.scenarios);
      final wakeCount = catalog.scenarios.first.appState.taskLogEntries.length;
      final profiles = rawProfiles;
      final runsRoot = _runsRoot();
      _guardProtectedTraceOutput(catalog, runsRoot);
      final writer = TraceWriter(runsRoot: runsRoot);
      final providerContainer = ProviderContainer();
      addTearDown(providerContainer.dispose);
      final cloudInferenceRepository = providerContainer.read(
        cloudInferenceRepositoryProvider,
      );

      final manifest = EvalProvenance.captureRunManifest(
        runId: _runId,
        targetName: 'live-task-cascade',
        targetKind: 'live',
        scenarios: catalog.scenarios,
        profiles: profiles,
        scenarioCatalogEvidence: catalog.evidence,
        profileExecutionBindings: [
          for (final profile in profiles)
            settings.profileBindingConfigFor(profile).toExecutionBinding(),
        ],
      );
      final manifestFile = await writer.writeManifest(manifest);
      final manifestDigest = manifest.manifestDigest!;
      final traces = <EvalTrace>[];
      final cascadeExpectationErrors = <String>[];

      for (
        var scenarioIndex = 0;
        scenarioIndex < catalog.scenarios.length;
        scenarioIndex++
      ) {
        final scenario = catalog.scenarios[scenarioIndex];
        for (
          var profileIndex = 0;
          profileIndex < profiles.length;
          profileIndex++
        ) {
          final profile = profiles[profileIndex];
          for (
            var trialIndex = 0;
            trialIndex < profile.trialCount;
            trialIndex++
          ) {
            final context = EvalTargetRunContext(
              runId: _runId,
              scenarioId: scenario.id,
              profileName: profile.name,
              trialIndex: trialIndex,
            );
            final outputs = await TaskAgentEvalBench.runCascade(
              scenario,
              profile,
              context: context,
              seedScenarioTaskLogEntries: false,
              wakes: [
                for (final entry in scenario.appState.taskLogEntries)
                  TaskAgentEvalCascadeWake(taskLogEntries: [entry]),
              ],
              conversationRepositoryForWake: (_) =>
                  ObservingConversationRepository(),
              cloudInferenceRepositoryOverride: cloudInferenceRepository,
              profileConfigOverride: settings.profileConfigFor(profile),
              providerEnvPresence: settings.envPresenceForProfile(profile),
            );
            cascadeExpectationErrors.addAll(
              _missingCascadeOutputErrors(
                scenario: scenario,
                profile: profile,
                trialIndex: trialIndex,
                outputCount: outputs.length,
              ),
            );
            for (var wakeIndex = 0; wakeIndex < outputs.length; wakeIndex++) {
              final level1Checks = _cascadeWakeLevel1Checks(
                scenario: scenario,
                profile: profile,
                wakeIndex: wakeIndex,
                output: outputs[wakeIndex],
              );
              cascadeExpectationErrors.addAll(
                _failedCheckErrors(
                  scenario: scenario,
                  profile: profile,
                  trialIndex: trialIndex,
                  wakeIndex: wakeIndex,
                  checks: level1Checks,
                ),
              );
              final trace = EvalTrace(
                runId: _runId,
                scenario: scenario,
                profile: profile,
                provenance: EvalProvenance.capture(
                  scenario: scenario,
                  profile: profile,
                  manifestDigest: manifestDigest,
                ),
                trialIndex: trialIndex,
                cascadeWake: EvalTraceCascadeWake(
                  cascadeId: EvalTraceCascadeWake.taskLogCascadeId,
                  wakeIndex: wakeIndex,
                  wakeCount: wakeCount,
                ),
                output: outputs[wakeIndex],
                level1Checks: level1Checks,
              );
              await writer.writeTrace(trace);
              traces.add(trace);
            }
          }
        }
      }

      EvalRunVerifier.verify(
        runId: _runId,
        traces: traces,
        scenarios: catalog.scenarios,
        profiles: profiles,
        manifest: manifest,
        artifactNames: _artifactNames(_runId, writer),
        requireVerdicts: false,
      ).throwIfFailed();

      expect(
        cascadeExpectationErrors,
        isEmpty,
        reason: cascadeExpectationErrors.join('\n'),
      );
      expect(manifestFile.existsSync(), isTrue);
      expect(
        traces,
        hasLength(
          catalog.scenarios.length *
              profiles.fold<int>(
                0,
                (sum, profile) => sum + profile.trialCount,
              ) *
              wakeCount,
        ),
      );
    },
    timeout: const Timeout(Duration(minutes: 45)),
    skip: _liveRunnerSkip(settings),
  );
}

List<EvalCheck> _cascadeWakeLevel1Checks({
  required EvalScenario scenario,
  required EvalProfile profile,
  required int wakeIndex,
  required AgentRunOutput output,
}) {
  ExpectedCascadeWakeState? expectedWake;
  for (final candidate in scenario.expectations.cascadeWakes) {
    if (candidate.wakeIndex == wakeIndex) {
      if (expectedWake != null) {
        return [
          EvalCheck.fail(
            'cascade_wake_expectation',
            'multiple cascade wake expectations for wake $wakeIndex',
          ),
        ];
      }
      expectedWake = candidate;
    }
  }
  if (expectedWake == null) {
    return [
      ...runLevel1(scenario, output, profile: profile),
      EvalCheck.fail(
        'cascade_wake_expectation',
        'no cascade wake expectation for wake $wakeIndex',
      ),
    ];
  }
  return runCascadeWakeLevel1(
    scenario,
    output,
    expectedWake,
    profile: profile,
  );
}

List<String> _missingCascadeOutputErrors({
  required EvalScenario scenario,
  required EvalProfile profile,
  required int trialIndex,
  required int outputCount,
}) {
  final label = '${scenario.id}::${profile.name}::trial-$trialIndex';
  return [
    for (final expectedWake in scenario.expectations.cascadeWakes)
      if (expectedWake.wakeIndex < 0 || expectedWake.wakeIndex >= outputCount)
        '$label wake ${expectedWake.wakeIndex} has no output',
  ];
}

List<String> _failedCheckErrors({
  required EvalScenario scenario,
  required EvalProfile profile,
  required int trialIndex,
  required int wakeIndex,
  required List<EvalCheck> checks,
}) {
  final label = '${scenario.id}::${profile.name}::trial-$trialIndex';
  return [
    for (final check in checks.where((check) => !check.passed))
      '$label wake $wakeIndex ${check.name}: ${check.detail}',
  ];
}

Object? _liveRunnerSkip(LiveEvalSettings settings) {
  if (!settings.enabled) {
    return 'Set LOTTI_EVAL_LIVE=1 plus provider credentials to run Level 2.';
  }
  if (_runId.isEmpty) {
    return 'Set --dart-define=EVAL_RUN=<runId> to write trace artifacts.';
  }
  return false;
}

void _validateCascadeScenarios(List<EvalScenario> scenarios) {
  if (scenarios.isEmpty) {
    throw StateError('Select at least one task-agent cascade scenario.');
  }
  final wakeCounts = <int>{};
  for (final scenario in scenarios) {
    if (scenario.agentKind != AgentKind.taskAgent) {
      throw StateError(
        'Live task cascade runner only supports task-agent scenarios; '
        '${scenario.id} is ${scenario.agentKind.name}.',
      );
    }
    if (scenario.appState.taskLogEntries.isEmpty) {
      throw StateError(
        'Scenario ${scenario.id} has no appState.taskLogEntries to cascade.',
      );
    }
    wakeCounts.add(scenario.appState.taskLogEntries.length);
  }
  if (wakeCounts.length != 1) {
    throw StateError(
      'Selected cascade scenarios must have the same wake count; got '
      '${wakeCounts.join(', ')}.',
    );
  }
}

EvalProfileCatalog _loadProfileCatalog() {
  return EvalProfileCatalogLoader.fromEnvironment(
    Platform.environment,
    dartDefineValue: _profileCatalogValueFromDefine(),
    dartDefineProfileNames: _profileNamesFromDefine(),
  );
}

String _scenarioCatalogPathFromDefine() => _scenarioCatalogPath;

String _profileCatalogValueFromDefine() => _profileCatalogValue;

String _profileNamesFromDefine() => _profileNames;

String _scenarioCatalogModeFromDefine() => _scenarioCatalogMode;

String _scenarioIdsFromDefine() => _scenarioIds;

String _runsRoot() {
  final fromDefine = _runsRootPath.trim();
  if (fromDefine.isNotEmpty) return fromDefine;
  final fromEnvironment = Platform.environment['EVAL_RUNS_ROOT']?.trim();
  if (fromEnvironment != null && fromEnvironment.isNotEmpty) {
    return fromEnvironment;
  }
  return 'eval/runs';
}

void _guardProtectedTraceOutput(
  EvalScenarioCatalog catalog,
  String runsRoot,
) {
  if (!catalog.evidence.hasProtectedHoldoutEvidence) return;
  final ackFromDefine = _protectedTraceAck.trim();
  final ack = ackFromDefine.isNotEmpty
      ? ackFromDefine
      : Platform.environment['LOTTI_EVAL_PROTECTED_TRACE_ACK'];
  if (ack == '1') return;
  final repoPath = Directory.current.absolute.path;
  final rootDirectory = Directory(runsRoot);
  final rootPath = rootDirectory.isAbsolute
      ? rootDirectory.absolute.path
      : Directory('$repoPath/$runsRoot').absolute.path;
  final insideRepo = rootPath == repoPath || rootPath.startsWith('$repoPath/');
  if (!insideRepo) return;
  throw StateError(
    'Protected eval scenarios write raw scenario content into trace files. '
    'Set EVAL_RUNS_ROOT to an absolute path outside the repo or set '
    'LOTTI_EVAL_PROTECTED_TRACE_ACK=1 to acknowledge this.',
  );
}

List<String> _artifactNames(String runId, TraceWriter writer) {
  final dir = Directory(writer.runDir(runId));
  if (!dir.existsSync()) return const <String>[];
  final names = <String>[];
  for (final entity in dir.listSync()) {
    if (entity is File) {
      names.add(entity.uri.pathSegments.last);
    }
  }
  names.sort();
  return names;
}
