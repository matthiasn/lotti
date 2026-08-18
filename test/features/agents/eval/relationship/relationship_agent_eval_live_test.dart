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
import 'package:lotti/features/ai/util/known_models.dart';
import 'package:lotti/get_it.dart';

import '../../../../helpers/fallbacks.dart';
import '../../../ai_consumption/test_utils.dart';
import 'support/relationship_agent_eval_runner.dart';
import 'support/relationship_agent_eval_scenarios.dart';

/// Live relationship-agent inference eval.
///
/// Run book (full version in
/// `docs/evaluations/relationship_agent_models/README.md`):
///
///     LOTTI_RELATIONSHIP_AGENT_EVAL_LIVE=1 \
///     RELATIONSHIP_AGENT_EVAL_API_KEY=$MELIOUS_API_KEY \
///     RELATIONSHIP_AGENT_EVAL_MODELS=deepseek-v4-flash \
///     fvm flutter test test/features/agents/eval/relationship/ \
///       --tags eval-live --plain-name 'relationship-agent inference report'
///
/// Provider type defaults to `melious` deliberately: it is the only provider
/// whose responses carry billing, and cost-per-case is a first-class output
/// of this eval. The default model is `deepseek-v4-flash` — the candidate
/// this contract must work well on, because it is the viable option on cost.
void main() {
  test(
    'writes a relationship-agent inference report',
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
        Platform.environment['RELATIONSHIP_AGENT_EVAL_PROVIDER_TYPE'],
      );
      final provider = AiConfigInferenceProvider(
        id: 'relationship-agent-eval-${providerType.name}',
        name: 'Relationship Agent Eval (${providerType.name})',
        baseUrl:
            Platform.environment['RELATIONSHIP_AGENT_EVAL_BASE_URL'] ??
            ProviderConfig.defaultBaseUrls[providerType]!,
        apiKey:
            Platform.environment['RELATIONSHIP_AGENT_EVAL_API_KEY'] ??
            Platform.environment['MELIOUS_API_KEY'] ??
            '',
        inferenceProviderType: providerType,
        createdAt: DateTime(2026, 8, 18),
      );

      final modelIds = _envList('RELATIONSHIP_AGENT_EVAL_MODELS');
      final allScenarios = await buildRelationshipAgentEvalScenarios();
      final requestedScenarios = _envList(
        'RELATIONSHIP_AGENT_EVAL_SCENARIOS',
      );
      final scenarios = requestedScenarios.isEmpty
          ? allScenarios
          : allScenarios
                .where((s) => requestedScenarios.contains(s.id))
                .toList(growable: false);
      expect(
        scenarios,
        isNotEmpty,
        reason: 'RELATIONSHIP_AGENT_EVAL_SCENARIOS matched no scenario ids.',
      );

      final runner = RelationshipAgentInferenceEvalRunner(
        provider: provider,
        conversationRepository: container.read(
          conversationRepositoryProvider.notifier,
        ),
        inferenceRepository: CloudInferenceWrapper(
          cloudRepository: container.read(cloudInferenceRepositoryProvider),
        ),
        temperature:
            double.tryParse(
              Platform.environment['RELATIONSHIP_AGENT_EVAL_TEMPERATURE'] ?? '',
            ) ??
            0,
        wakesPerDayAssumption:
            int.tryParse(
              Platform.environment['RELATIONSHIP_AGENT_EVAL_WAKES_PER_DAY'] ??
                  '',
            ) ??
            1,
        consumptionForWakeRunKey: (wakeRunKey) => attribution
            .recordedInteractions
            .where((event) => event.wakeRunKey == wakeRunKey)
            .toList(growable: false),
      );

      final report = await runner.run(
        modelIds: modelIds.isEmpty
            ? const [meliousDeepseekV4FlashModelId]
            : modelIds,
        scenarios: scenarios,
      );

      final tempDir = Directory.systemTemp.path;
      final jsonPath =
          Platform.environment['RELATIONSHIP_AGENT_EVAL_JSON'] ??
          '$tempDir/lotti-relationship-agent-eval.json';
      final markdownPath =
          Platform.environment['RELATIONSHIP_AGENT_EVAL_MARKDOWN'] ??
          '$tempDir/lotti-relationship-agent-eval.md';
      _write(jsonPath, report.toPrettyJson());
      _write(markdownPath, report.toMarkdown());

      expect(report.results, isNotEmpty);
      expect(File(jsonPath).existsSync(), isTrue);
      expect(File(markdownPath).existsSync(), isTrue);
      if (Platform.environment['RELATIONSHIP_AGENT_EVAL_STRICT'] == '1') {
        expect(
          report.results.where((result) => !result.passed).toList(),
          isEmpty,
          reason:
              'Relationship-agent eval failures reported. See $markdownPath.',
        );
      }
    },
    skip: Platform.environment['LOTTI_RELATIONSHIP_AGENT_EVAL_LIVE'] == '1'
        ? null
        : 'Set LOTTI_RELATIONSHIP_AGENT_EVAL_LIVE=1 (and MELIOUS_API_KEY) to '
              'run the live relationship-agent eval.',
    timeout: Timeout(
      Duration(
        minutes:
            int.tryParse(
              Platform.environment['RELATIONSHIP_AGENT_EVAL_TIMEOUT_'
                      'MINUTES'] ??
                  '',
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
      'Unknown RELATIONSHIP_AGENT_EVAL_PROVIDER_TYPE "$name".',
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
