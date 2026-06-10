// Level 2 live task-agent cascade entrypoint.
//
// Runs selected task-agent scenarios as same-task cascades: each
// `appState.taskLogEntries` item is appended before one wake, while reports,
// observations, and proposals persist across wakes. The output is one trace per
// wake, using trialIndex as the wake index.

@Tags(['eval-live'])
library;

import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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
      final profiles = [
        for (final profile in rawProfiles)
          _profileWithTrialCount(profile, wakeCount),
      ];
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
          for (final profile in rawProfiles)
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
          final rawProfile = rawProfiles[profileIndex];
          final context = EvalTargetRunContext(
            runId: _runId,
            scenarioId: scenario.id,
            profileName: profile.name,
            trialIndex: 0,
          );
          final outputs = await TaskAgentEvalBench.runCascade(
            scenario,
            rawProfile,
            context: context,
            seedScenarioTaskLogEntries: false,
            wakes: [
              for (final entry in scenario.appState.taskLogEntries)
                TaskAgentEvalCascadeWake(taskLogEntries: [entry]),
            ],
            conversationRepositoryForWake: (_) =>
                ObservingConversationRepository(),
            cloudInferenceRepositoryOverride: cloudInferenceRepository,
            profileConfigOverride: settings.profileConfigFor(rawProfile),
            providerEnvPresence: settings.envPresenceForProfile(rawProfile),
          );
          cascadeExpectationErrors.addAll(
            _cascadeWakeExpectationErrors(
              scenario: scenario,
              profile: profile,
              outputs: outputs,
            ),
          );
          for (var wakeIndex = 0; wakeIndex < outputs.length; wakeIndex++) {
            final trace = EvalTrace(
              runId: _runId,
              scenario: scenario,
              profile: profile,
              provenance: EvalProvenance.capture(
                scenario: scenario,
                profile: profile,
                manifestDigest: manifestDigest,
              ),
              trialIndex: wakeIndex,
              output: outputs[wakeIndex],
              level1Checks: runLevel1(
                scenario,
                outputs[wakeIndex],
                profile: profile,
              ),
            );
            await writer.writeTrace(trace);
            traces.add(trace);
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
        hasLength(catalog.scenarios.length * profiles.length * wakeCount),
      );
    },
    timeout: const Timeout(Duration(minutes: 45)),
    skip: _liveRunnerSkip(settings),
  );
}

List<String> _cascadeWakeExpectationErrors({
  required EvalScenario scenario,
  required EvalProfile profile,
  required List<AgentRunOutput> outputs,
}) {
  if (scenario.id != 'task_workflow_checklist_transcript_cascade') {
    return const [];
  }

  final errors = <String>[];
  final label = '${scenario.id}::${profile.name}';
  if (outputs.length < 2) {
    return ['$label expected at least two cascade wakes'];
  }

  final wake1 = outputs[1];
  final checkedPullRequest = wake1.proposals.any(
    (proposal) =>
        proposal.toolName == 'update_checklist_item' &&
        proposal.targetId == 'task-redesign' &&
        proposal.status == 'pending' &&
        proposal.args['id'] == 'ci-pr' &&
        proposal.args['isChecked'] == true,
  );
  if (!checkedPullRequest) {
    errors.add(
      '$label wake 1 missing pending update_checklist_item proposal for '
      'ci-pr with isChecked=true',
    );
  }

  final incorrectlyCheckedLaterItems = outputs.expand((output) {
    return output.proposals.where(
      (proposal) =>
          proposal.toolName == 'update_checklist_item' &&
          proposal.args['isChecked'] == true &&
          {'ci-review', 'ci-release'}.contains(proposal.args['id']),
    );
  }).toList();
  if (incorrectlyCheckedLaterItems.isNotEmpty) {
    errors.add(
      '$label checked checklist items that the transcript leaves pending: '
      '${incorrectlyCheckedLaterItems.map((proposal) => proposal.args['id']).join(', ')}',
    );
  }

  return errors;
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

EvalProfile _profileWithTrialCount(EvalProfile profile, int trialCount) =>
    EvalProfile(
      name: profile.name,
      isLocal: profile.isLocal,
      modelClass: profile.modelClass,
      modelId: profile.modelId,
      temperature: profile.temperature,
      maxCompletionTokens: profile.maxCompletionTokens,
      tokenBudget: profile.tokenBudget,
      trialCount: trialCount,
      inputTokenCostMicros: profile.inputTokenCostMicros,
      outputTokenCostMicros: profile.outputTokenCostMicros,
      cachedInputTokenCostMicros: profile.cachedInputTokenCostMicros,
      thoughtsTokenCostMicros: profile.thoughtsTokenCostMicros,
    );

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
