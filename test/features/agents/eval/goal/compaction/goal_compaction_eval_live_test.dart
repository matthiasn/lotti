@Tags(['eval-live'])
library;

import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/constants/provider_config.dart';
import 'package:lotti/features/ai/conversation/conversation_repository.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/cloud_inference_repository.dart';
import 'package:lotti/features/ai/repository/cloud_inference_wrapper.dart';
import 'package:lotti/features/goals/logic/goal_checkin_compaction_strategy.dart';
import 'package:lotti/get_it.dart';

import '../../../../../helpers/fallbacks.dart';
import '../../../../ai_consumption/test_utils.dart';
import 'support/goal_compaction_eval.dart';
import 'support/goal_compaction_fixtures.dart';

/// Live check-in compaction eval: writes the judging packet.
///
/// Run book: `docs/evaluations/goal_agent_models/compaction.md`.
///
///     LOTTI_GOAL_COMPACTION_EVAL_LIVE=1 \
///     MELIOUS_API_KEY=... \
///     GOAL_COMPACTION_EVAL_MODEL=glm-5.2 \
///     GOAL_COMPACTION_EVAL_SAMPLES=1 \
///     fvm flutter test \
///       test/features/agents/eval/goal/compaction/goal_compaction_eval_live_test.dart \
///       --tags eval-live
///
/// Environment:
/// - `GOAL_COMPACTION_EVAL_MODEL` — the agent model (default `glm-5.2`).
/// - `GOAL_COMPACTION_EVAL_DIGEST_MODEL` — the digest writer (default: same).
/// - `GOAL_COMPACTION_EVAL_FIXTURES` — comma-separated fixture ids.
/// - `GOAL_COMPACTION_EVAL_STRATEGIES` — subset of `full,truncate,hierarchical`.
/// - `GOAL_COMPACTION_EVAL_SAMPLES` — runs per (fixture × strategy), default 1.
/// - `GOAL_COMPACTION_EVAL_PACKET` — where the packet JSON goes.
/// - `GOAL_COMPACTION_EVAL_DIGEST_CACHE` — digest cache directory.
/// - `GOAL_COMPACTION_EVAL_TEMPERATURE` — default 0.
/// - `GOAL_COMPACTION_EVAL_PROVIDER_TYPE`, `_BASE_URL`, `_API_KEY` — provider
///   overrides; the key falls back to `MELIOUS_API_KEY`.
/// - `GOAL_COMPACTION_EVAL_TIMEOUT_MINUTES` — default 90.
void main() {
  test(
    'writes a goal check-in compaction judging packet',
    () async {
      HttpOverrides.global = null;
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
        Platform.environment['GOAL_COMPACTION_EVAL_PROVIDER_TYPE'],
      );
      final provider = AiConfigInferenceProvider(
        id: 'goal-compaction-eval-${providerType.name}',
        name: 'Goal Compaction Eval (${providerType.name})',
        baseUrl:
            Platform.environment['GOAL_COMPACTION_EVAL_BASE_URL'] ??
            ProviderConfig.defaultBaseUrls[providerType]!,
        apiKey:
            Platform.environment['GOAL_COMPACTION_EVAL_API_KEY'] ??
            Platform.environment['MELIOUS_API_KEY'] ??
            '',
        inferenceProviderType: providerType,
        createdAt: DateTime(2026, 8, 27),
      );

      final modelId =
          Platform.environment['GOAL_COMPACTION_EVAL_MODEL'] ?? 'glm-5.2';
      final digestModelId =
          Platform.environment['GOAL_COMPACTION_EVAL_DIGEST_MODEL'] ?? modelId;
      final conversationRepository = container.read(
        conversationRepositoryProvider.notifier,
      );
      final inferenceRepository = CloudInferenceWrapper(
        cloudRepository: container.read(cloudInferenceRepositoryProvider),
      );

      final digestWriter = CachedLlmDigestWriter(
        provider: provider,
        modelId: digestModelId,
        conversationRepository: conversationRepository,
        inferenceRepository: inferenceRepository,
        cacheDirectory: Directory(
          Platform.environment['GOAL_COMPACTION_EVAL_DIGEST_CACHE'] ??
              'eval_artifacts/goal_compaction_digests/$digestModelId',
        ),
      );

      final requestedFixtures = _envList('GOAL_COMPACTION_EVAL_FIXTURES');
      final fixtures = requestedFixtures.isEmpty
          ? goalCompactionFixtures
          : goalCompactionFixtures
                .where((f) => requestedFixtures.contains(f.id))
                .toList(growable: false);
      expect(fixtures, isNotEmpty, reason: 'no fixture matched');

      final requestedStrategies = _envList('GOAL_COMPACTION_EVAL_STRATEGIES');
      final strategies = goalCompactionEvalArms(digestWriter)
          .where(
            (s) =>
                requestedStrategies.isEmpty ||
                requestedStrategies.contains(s.id),
          )
          .toList(growable: false);
      expect(strategies, isNotEmpty, reason: 'no strategy matched');
      expect(
        strategies.any((s) => s is FullContextCheckInCompaction),
        isTrue,
        reason: 'the full arm is the oracle every other arm is judged against',
      );

      final runner = GoalCompactionEvalRunner(
        provider: provider,
        modelId: modelId,
        conversationRepository: conversationRepository,
        inferenceRepository: inferenceRepository,
        temperature:
            double.tryParse(
              Platform.environment['GOAL_COMPACTION_EVAL_TEMPERATURE'] ?? '',
            ) ??
            0,
        log: (line) => stdout.writeln('[compaction-eval] $line'),
      );

      final packet = await runner.run(
        fixtures: fixtures,
        strategies: strategies,
        samples:
            int.tryParse(
              Platform.environment['GOAL_COMPACTION_EVAL_SAMPLES'] ?? '',
            ) ??
            1,
        digestUsage: () => digestWriter.usageJson,
      );

      final packetPath =
          Platform.environment['GOAL_COMPACTION_EVAL_PACKET'] ??
          '${Directory.systemTemp.path}/lotti-goal-compaction-packet.json';
      File(packetPath)
        ..parent.createSync(recursive: true)
        ..writeAsStringSync(packet.toPrettyJson());
      stdout.writeln('[compaction-eval] packet: $packetPath');

      expect(packet.cases, isNotEmpty);
      final errors = packet.cases.where((c) => c.errorMessage != null);
      expect(
        errors,
        isEmpty,
        reason: errors
            .map(
              (c) =>
                  '${c.fixture.id}/${c.strategyId}: '
                  '${c.errorMessage}',
            )
            .join('\n'),
      );
    },
    skip: Platform.environment['LOTTI_GOAL_COMPACTION_EVAL_LIVE'] == '1'
        ? null
        : 'Set LOTTI_GOAL_COMPACTION_EVAL_LIVE=1 (and MELIOUS_API_KEY) to run '
              'the live compaction eval.',
    timeout: Timeout(
      Duration(
        minutes:
            int.tryParse(
              Platform.environment['GOAL_COMPACTION_EVAL_TIMEOUT_MINUTES'] ??
                  '',
            ) ??
            90,
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
      'Unknown GOAL_COMPACTION_EVAL_PROVIDER_TYPE "$name".',
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
