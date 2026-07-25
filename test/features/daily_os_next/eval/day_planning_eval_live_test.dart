@Tags(['eval-live'])
library;

import 'dart:io';

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/constants/provider_config.dart';
import 'package:lotti/features/ai/conversation/conversation_repository.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/cloud_inference_repository.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/time_service.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';
import '../../ai_consumption/test_utils.dart';
import 'framework/eval_report.dart';
import 'framework/eval_runner.dart';
import 'framework/eval_scenario.dart';
import 'framework/eval_variant.dart';

/// Runs the day-planning matrix against real inference providers and writes a
/// report. **Opt-in, never in CI.**
///
/// Everything below the model is production code (see `eval_runner.dart`); this
/// file only supplies the inference layer and the output paths.
///
/// This eval **always passes when it runs**. Violations are reported, never
/// asserted: a live run is non-deterministic and costs money, and a red build
/// people learn to ignore is worse than no signal at all. The report is the
/// deliverable — read it, and read the judge bundle beside it.
///
/// Missing credentials are the one hard failure, because that is a setup error
/// rather than anything a model did.
///
/// ```sh
/// set -a; source .env; set +a   # MELIOUS_API_KEY / MELIOUS_BASE_URL
/// LOTTI_DAY_PLANNING_EVAL_LIVE=1 \
/// DAY_PLANNING_EVAL_MODELS=glm-5.2 \
/// DAY_PLANNING_EVAL_SAMPLES=3 \
///   fvm flutter test test/features/daily_os_next/eval/day_planning_eval_live_test.dart
/// ```
///
/// Also honours `DAY_PLANNING_EVAL_SCENARIOS` (comma-separated scenario ids,
/// default all) and the `DAY_PLANNING_EVAL_DIR` / `_JSON` / `_MARKDOWN` output
/// overrides.
///
/// Wall-clock time is intentional here (exempt from the fake-time policy in
/// `test/README.md`): same-day scenarios run under a clock anchored to their
/// start hour so production's same-day guard is live, and latency is one of
/// the things being measured.
void main() {
  setUpAll(registerAllFallbackValues);

  final environment = Platform.environment;
  final live = environment['LOTTI_DAY_PLANNING_EVAL_LIVE'] == '1';
  final modelIds = _csv(environment['DAY_PLANNING_EVAL_MODELS'], 'glm-5.2');
  final samples =
      int.tryParse(environment['DAY_PLANNING_EVAL_SAMPLES'] ?? '') ?? 1;
  final scenarioIds = _csv(environment['DAY_PLANNING_EVAL_SCENARIOS'], '');
  final scenarios = scenarioIds.isEmpty
      ? evalScenarios
      : [
          for (final scenario in evalScenarios)
            if (scenarioIds.contains(scenario.id)) scenario,
        ];

  test(
    'runs the day-planning matrix against live models and writes a report',
    () async {
      if (scenarios.isEmpty) {
        fail(
          'DAY_PLANNING_EVAL_SCENARIOS matched no scenario. Known ids: '
          '${evalScenarios.map((s) => s.id).join(', ')}.',
        );
      }
      final apiKey = environment['MELIOUS_API_KEY'];
      if (apiKey == null || apiKey.isEmpty) {
        // A setup error, not a model result — the one thing worth failing on.
        fail(
          'MELIOUS_API_KEY is not set — source .env before running the live '
          'day-planning eval.',
        );
      }

      final attribution = AiInteractionCaptureTestBench.create();
      await setUpTestGetIt(
        additionalSetup: () {
          getIt
            ..registerSingleton<PersistenceLogic>(MockPersistenceLogic())
            ..registerSingleton<TimeService>(TimeService());
          attribution.register();
        },
      );
      addTearDown(tearDownTestGetIt);
      // The test binding installs a mock HttpOverrides whose client instantly
      // fails every request with HTTP 400 — clear it so the eval can reach a
      // real provider.
      HttpOverrides.global = null;

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

      final provider =
          AiConfig.inferenceProvider(
                id: 'provider-day-planning-eval',
                name: 'Melious (day-planning eval)',
                baseUrl:
                    environment['MELIOUS_BASE_URL'] ??
                    ProviderConfig.defaultBaseUrls[InferenceProviderType
                        .melious]!,
                apiKey: apiKey,
                inferenceProviderType: InferenceProviderType.melious,
                createdAt: DateTime(2026, 7, 25),
              )
              as AiConfigInferenceProvider;

      final targets = [
        for (final modelId in modelIds)
          EvalModelTarget(
            id: modelId,
            open: (_) async => EvalLlmLayer(
              conversationRepository: container.read(
                conversationRepositoryProvider.notifier,
              ),
              cloudInferenceRepository: container.read(
                cloudInferenceRepositoryProvider,
              ),
              profile: AiConfigInferenceProfile(
                id: 'profile-$modelId',
                name: 'Day-planning eval ($modelId)',
                thinkingModelId: modelId,
                createdAt: DateTime(2026, 7, 25),
              ),
              model:
                  AiConfig.model(
                        id: 'model-$modelId',
                        name: modelId,
                        providerModelId: modelId,
                        inferenceProviderId: provider.id,
                        createdAt: DateTime(2026, 7, 25),
                        inputModalities: const [Modality.text],
                        outputModalities: const [Modality.text],
                        isReasoningModel: true,
                        supportsFunctionCalling: true,
                        description: 'Model under day-planning eval.',
                      )
                      as AiConfigModel,
              provider: provider,
            ),
          ),
      ];

      debugPrint(
        'day-planning eval: ${scenarios.length} scenario(s) x '
        '${targets.length} model(s) x ${evalVariants.length} variant(s) x '
        '$samples sample(s)',
      );

      final results = await runEvalMatrix(
        models: targets,
        scenarios: scenarios,
        samples: samples,
        attribution: attribution,
        log: debugPrint,
      );

      final report = EvalReport.fromResults(results, generatedAt: clock.now());
      final paths = writeEvalReport(report);

      // Reported, never asserted. The one exception above is credentials.
      debugPrint(report.toMarkdown());
      debugPrint('day-planning eval report: ${paths.markdownPath}');
      debugPrint('day-planning eval judge bundle: ${paths.jsonPath}');
      for (final standing in report.standings) {
        debugPrint(
          '  ${standing.modelId}: ${standing.overall.label} '
          '(${standing.failedRuns} failed run(s) of ${standing.runs})',
        );
      }
    },
    skip: live
        ? null
        : 'Set LOTTI_DAY_PLANNING_EVAL_LIVE=1 (plus MELIOUS_API_KEY / '
              'MELIOUS_BASE_URL) to run the live day-planning eval.',
    // Generous: one cell can take minutes against a reasoning model, and the
    // matrix runs them sequentially. RealDayAgent's own 10-minute job-await
    // soft cap is what turns a hang into a diagnostic.
    timeout: const Timeout(Duration(hours: 2)),
  );
}

List<String> _csv(String? raw, String fallback) => (raw ?? fallback)
    .split(',')
    .map((value) => value.trim())
    .where((value) => value.isNotEmpty)
    .toList();
