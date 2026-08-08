@Tags(['eval-live'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/constants/provider_config.dart';
import 'package:lotti/features/ai/conversation/conversation_repository.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/cloud_inference_repository.dart';
import 'package:lotti/features/ai/repository/cloud_inference_wrapper.dart';
import 'package:lotti/get_it.dart';

import '../../../../helpers/fallbacks.dart';
import '../../../ai_consumption/test_utils.dart';
import 'support/goal_ad_image_probe.dart';
import 'support/goal_agent_eval_runner.dart';
import 'support/goal_agent_eval_scenarios.dart';
import 'support/goal_agent_spec.dart';

/// Live goal-agent inference eval.
///
/// Run book (full version in `docs/evaluations/goal_agent_models/README.md`):
///
///     LOTTI_GOAL_AGENT_EVAL_LIVE=1 \
///     GOAL_AGENT_EVAL_API_KEY=$MELIOUS_API_KEY \
///     GOAL_AGENT_EVAL_MODELS=glm-5.2 \
///     fvm flutter test test/features/agents/eval/goal/ \
///       --tags eval-live --plain-name 'goal-agent inference report'
///
/// Provider type defaults to `melious` deliberately: it is the only provider
/// whose responses carry billing, and cost-per-case is a first-class output
/// of this eval (generic-OpenAI routing is exactly why the task-agent evals
/// lack credits).
void main() {
  test(
    'writes a goal-agent inference report',
    () async {
      // The test binding installs a mock HttpOverrides whose client fails
      // every request — clear it so the eval reaches a real provider.
      HttpOverrides.global = null;

      // The capture bench IS the credits pipeline: ConversationRepository
      // records per-turn consumption only when an AiInteractionCapture is
      // registered, and the Melious impact side-channel rides on it.
      registerAllFallbackValues();
      final attribution = AiInteractionCaptureTestBench.create()..register();
      addTearDown(attribution.unregister);
      addTearDown(getIt.reset);

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
      final provider = AiConfigInferenceProvider(
        id: 'goal-agent-eval-${providerType.name}',
        name: 'Goal Agent Eval (${providerType.name})',
        baseUrl:
            Platform.environment['GOAL_AGENT_EVAL_BASE_URL'] ??
            ProviderConfig.defaultBaseUrls[providerType]!,
        apiKey:
            Platform.environment['GOAL_AGENT_EVAL_API_KEY'] ??
            Platform.environment['MELIOUS_API_KEY'] ??
            '',
        inferenceProviderType: providerType,
        createdAt: DateTime(2026, 8, 8),
      );

      final modelIds = _envList('GOAL_AGENT_EVAL_MODELS');
      final requestedScenarios = _envList('GOAL_AGENT_EVAL_SCENARIOS');
      final scenarios = requestedScenarios.isEmpty
          ? goalAgentEvalScenarios
          : goalAgentEvalScenarios
                .where((s) => requestedScenarios.contains(s.id))
                .toList(growable: false);
      expect(
        scenarios,
        isNotEmpty,
        reason: 'GOAL_AGENT_EVAL_SCENARIOS matched no scenario ids.',
      );

      final runner = GoalAgentInferenceEvalRunner(
        provider: provider,
        conversationRepository: container.read(
          conversationRepositoryProvider.notifier,
        ),
        inferenceRepository: CloudInferenceWrapper(
          cloudRepository: container.read(cloudInferenceRepositoryProvider),
        ),
        temperature:
            double.tryParse(
              Platform.environment['GOAL_AGENT_EVAL_TEMPERATURE'] ?? '',
            ) ??
            0,
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
      );

      final tempDir = Directory.systemTemp.path;
      final jsonPath =
          Platform.environment['GOAL_AGENT_EVAL_JSON'] ??
          '$tempDir/lotti-goal-agent-eval.json';
      final markdownPath =
          Platform.environment['GOAL_AGENT_EVAL_MARKDOWN'] ??
          '$tempDir/lotti-goal-agent-eval.md';
      _write(jsonPath, report.toPrettyJson());
      _write(markdownPath, report.toMarkdown());

      // Optional image stage: render passing ad briefs through Nano Banana
      // Pro so the visuals can be judged by a human. The composed prompt is
      // built exclusively from the leakage-checked brief fields (ADR 0056) —
      // see goal_ad_image_probe.dart.
      final geminiKey = Platform.environment['GEMINI_API_KEY'] ?? '';
      if (Platform.environment['GOAL_AGENT_EVAL_IMAGES'] == '1' &&
          geminiKey.isNotEmpty) {
        final geminiProvider = AiConfigInferenceProvider(
          id: 'goal-agent-eval-gemini',
          name: 'Goal Agent Eval Images (gemini)',
          baseUrl:
              ProviderConfig.defaultBaseUrls[InferenceProviderType.gemini]!,
          apiKey: geminiKey,
          inferenceProviderType: InferenceProviderType.gemini,
          createdAt: DateTime(2026, 8, 8),
        );
        final imageDir =
            Platform.environment['GOAL_AGENT_EVAL_IMAGE_DIR'] ??
            'eval_artifacts/images';
        final cloudRepository = container.read(
          cloudInferenceRepositoryProvider,
        );
        for (final result in report.results) {
          if (!result.passed) continue;
          for (final call in result.toolCalls) {
            if (call.name != GoalAgentToolNames.createGoalAd) continue;
            final args = call.jsonObjectArguments;
            final sceneConcept = args?['sceneConcept'];
            if (sceneConcept is! String || sceneConcept.trim().isEmpty) {
              continue;
            }
            // One Gemini hiccup must not abort the whole optional stage —
            // the scoring artifacts are already on disk at this point.
            try {
              final path = await generateGoalAdImage(
                repository: cloudRepository,
                geminiProvider: geminiProvider,
                sceneConcept: sceneConcept,
                headline: args?['headline'] as String?,
                cta: args?['cta'] as String?,
                mood: args?['mood'] as String?,
                stylePreset: args?['stylePreset'] as String?,
                outputPath: '$imageDir/${result.scenario.id}_${result.modelId}',
              );
              // Sidecar with the entity-side fields for human review.
              File('$path.txt').writeAsStringSync(
                jsonEncode({
                  'headline': args?['headline'],
                  'altText': args?['altText'],
                  'tone': args?['tone'],
                }),
              );
              stdout.writeln('ad image: $path');
            } catch (error) {
              stderr.writeln(
                'ad image FAILED for ${result.scenario.id} × '
                '${result.modelId}: $error',
              );
            }
          }
        }
      }

      expect(report.results, isNotEmpty);
      expect(File(jsonPath).existsSync(), isTrue);
      expect(File(markdownPath).existsSync(), isTrue);
      if (Platform.environment['GOAL_AGENT_EVAL_STRICT'] == '1') {
        expect(
          report.results.where((result) => !result.passed).toList(),
          isEmpty,
          reason: 'Goal-agent eval failures reported. See $markdownPath.',
        );
      }
    },
    skip: Platform.environment['LOTTI_GOAL_AGENT_EVAL_LIVE'] == '1'
        ? null
        : 'Set LOTTI_GOAL_AGENT_EVAL_LIVE=1 (and MELIOUS_API_KEY) to run '
              'the live goal-agent eval.',
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
