@Tags(['eval-live'])
library;

import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/constants/provider_config.dart';
import 'package:lotti/features/ai/conversation/conversation_repository.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/cloud_inference_repository.dart';
import 'package:lotti/get_it.dart';

import '../../../../helpers/fallbacks.dart';
import '../../../ai_consumption/test_utils.dart';
import 'support/goal_agent_outcome_eval.dart';
import 'support/goal_agent_outcome_eval_scenarios.dart';

/// Live goal-agent OUTCOME eval (tier 2).
///
/// Runs the real `GoalAgentWorkflow` against a live model and scores what it
/// PERSISTED. Strategy rejections, forced retries and the persistence gates
/// are all inside the measurement, so a case passes only if the user would
/// actually have got the right thing — which is not the same question tier 1
/// asks, and the numbers are not comparable with it.
///
/// Run book (full version in `docs/evaluations/goal_agent_models/README.md`):
///
///     LOTTI_GOAL_OUTCOME_EVAL_LIVE=1 \
///     GOAL_AGENT_EVAL_API_KEY=$MELIOUS_API_KEY \
///     GOAL_OUTCOME_EVAL_MODELS=deepseek-v4-flash-0731 \
///     fvm flutter test test/features/agents/eval/goal/ \
///       --tags eval-live --plain-name 'goal-agent outcome report'
void main() {
  test(
    'writes a goal-agent outcome report',
    () async {
      // The test binding installs a mock HttpOverrides whose client fails
      // every request — clear it so the eval reaches a real provider.
      HttpOverrides.global = null;

      registerAllFallbackValues();
      final attribution = AiInteractionCaptureTestBench.create()..register();
      // Registration order is load-bearing: tear-downs run in reverse, so
      // `unregister` must be registered LAST to run BEFORE `getIt.reset`
      // pulls the registrations out from under it.
      addTearDown(getIt.reset);
      addTearDown(attribution.unregister);

      final container = ProviderContainer();
      addTearDown(container.dispose);
      final conversationSubscription = container.listen(
        conversationRepositoryProvider,
        (_, _) {},
      );
      addTearDown(conversationSubscription.close);
      final cloudSubscription = container.listen(
        cloudInferenceRepositoryProvider,
        (_, _) {},
      );
      addTearDown(cloudSubscription.close);

      final providerType = _providerType(
        Platform.environment['GOAL_AGENT_EVAL_PROVIDER_TYPE'],
      );
      // Fail loudly on a missing key. Falling back to an empty string makes
      // every case an `inferenceError`, and since the test only asserts the
      // report is non-empty, a run that authenticated nowhere would still go
      // green and produce a report full of zeros.
      final apiKey =
          Platform.environment['GOAL_AGENT_EVAL_API_KEY'] ??
          Platform.environment['MELIOUS_API_KEY'] ??
          '';
      expect(
        apiKey,
        isNotEmpty,
        reason:
            'Set GOAL_AGENT_EVAL_API_KEY (or MELIOUS_API_KEY) — an empty key '
            'produces a full report of authentication failures.',
      );
      final provider = AiConfigInferenceProvider(
        id: 'goal-outcome-eval-${providerType.name}',
        name: 'Goal Outcome Eval (${providerType.name})',
        baseUrl:
            Platform.environment['GOAL_AGENT_EVAL_BASE_URL'] ??
            ProviderConfig.defaultBaseUrls[providerType]!,
        apiKey: apiKey,
        inferenceProviderType: providerType,
        createdAt: DateTime(2026, 8, 8),
      );

      final modelIds = _envList('GOAL_OUTCOME_EVAL_MODELS');
      final requested = _envList('GOAL_OUTCOME_EVAL_SCENARIOS');
      final repeats =
          int.tryParse(
            Platform.environment['GOAL_OUTCOME_EVAL_REPEATS'] ?? '',
          ) ??
          1;
      final scenarios = requested.isEmpty
          ? goalOutcomeEvalScenarios
          : goalOutcomeEvalScenarios
                .where((s) => requested.contains(s.id))
                .toList(growable: false);
      expect(
        scenarios,
        isNotEmpty,
        reason: 'GOAL_OUTCOME_EVAL_SCENARIOS matched no scenario ids.',
      );

      final runner = GoalOutcomeEvalRunner(
        provider: provider,
        conversationRepository: container.read(
          conversationRepositoryProvider.notifier,
        ),
        cloudInferenceRepository: container.read(
          cloudInferenceRepositoryProvider,
        ),
        wakesPerDayAssumption:
            int.tryParse(
              Platform.environment['GOAL_AGENT_EVAL_WAKES_PER_DAY'] ?? '',
            ) ??
            3,
        consumptionForWakeRunKey: (wakeRunKey) => attribution
            .recordedInteractions
            .where((event) => event.wakeRunKey == wakeRunKey)
            .toList(growable: false),
      );

      final report = await runner.run(
        modelIds: modelIds.isEmpty ? const ['glm-5.2'] : modelIds,
        scenarios: scenarios,
        repeats: repeats,
      );

      final tempDir = Directory.systemTemp.path;
      final jsonPath =
          Platform.environment['GOAL_OUTCOME_EVAL_JSON'] ??
          '$tempDir/lotti-goal-outcome-eval.json';
      final markdownPath =
          Platform.environment['GOAL_OUTCOME_EVAL_MARKDOWN'] ??
          '$tempDir/lotti-goal-outcome-eval.md';
      _write(jsonPath, report.toPrettyJson());
      _write(markdownPath, report.toMarkdown());

      expect(report.results, isNotEmpty);
      expect(File(markdownPath).existsSync(), isTrue);
    },
    skip: Platform.environment['LOTTI_GOAL_OUTCOME_EVAL_LIVE'] == '1'
        ? null
        : 'Set LOTTI_GOAL_OUTCOME_EVAL_LIVE=1 (and MELIOUS_API_KEY) to run '
              'the live goal-agent outcome eval.',
    timeout: Timeout(
      Duration(
        minutes:
            int.tryParse(
              Platform.environment['GOAL_AGENT_EVAL_TIMEOUT_MINUTES'] ?? '',
            ) ??
            30,
      ),
    ),
  );
}

InferenceProviderType _providerType(String? name) {
  if (name == null || name.trim().isEmpty) {
    return InferenceProviderType.melious;
  }
  return InferenceProviderType.values.firstWhere(
    (value) => value.name == name.trim(),
    orElse: () => throw FormatException(
      'Unknown GOAL_AGENT_EVAL_PROVIDER_TYPE "$name".',
    ),
  );
}

List<String> _envList(String name) {
  final value = Platform.environment[name];
  if (value == null || value.trim().isEmpty) return const [];
  return value
      .split(',')
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .toList(growable: false);
}

void _write(String path, String content) {
  final file = File(path);
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(content);
}
