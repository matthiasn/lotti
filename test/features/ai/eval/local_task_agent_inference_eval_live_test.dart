@Tags(['eval-live'])
library;

import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/constants/provider_config.dart';
import 'package:lotti/features/ai/conversation/conversation_repository.dart';
import 'package:lotti/features/ai/eval/local_task_agent_inference_eval.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/cloud_inference_repository.dart';
import 'package:lotti/features/ai/repository/cloud_inference_wrapper.dart';

void main() {
  test(
    'writes a local task-agent inference report',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      const providerType = InferenceProviderType.omlx;
      final provider = AiConfigInferenceProvider(
        id: 'local-task-agent-omlx',
        name: 'Local oMLX',
        baseUrl:
            Platform.environment['LOCAL_TASK_AGENT_EVAL_BASE_URL'] ??
            Platform.environment['OMLX_BASE_URL'] ??
            ProviderConfig.defaultBaseUrls[providerType]!,
        apiKey:
            Platform.environment['LOCAL_TASK_AGENT_EVAL_API_KEY'] ??
            Platform.environment['OMLX_API_KEY'] ??
            '',
        inferenceProviderType: providerType,
        createdAt: DateTime(2026, 6, 21),
      );
      final profiles = _envList(
        'LOCAL_TASK_AGENT_EVAL_PROFILES',
      ).map(parseLocalTaskAgentEvalProfile).toList(growable: false);

      final runner = LocalTaskAgentInferenceEvalRunner(
        provider: provider,
        conversationRepository: container.read(
          conversationRepositoryProvider.notifier,
        ),
        inferenceRepository: CloudInferenceWrapper(
          cloudRepository: container.read(cloudInferenceRepositoryProvider),
        ),
        temperature: _envDouble('LOCAL_TASK_AGENT_EVAL_TEMPERATURE') ?? 0.3,
      );

      final report = await runner.run(
        profiles: profiles.isEmpty
            ? defaultLocalTaskAgentEvalProfiles
            : profiles,
        scenarios: [defaultLocalTaskAgentWakeScenario()],
      );

      final tempDir = Directory.systemTemp.path;
      final jsonPath =
          Platform.environment['LOCAL_TASK_AGENT_EVAL_JSON'] ??
          '$tempDir/lotti-local-task-agent-eval.json';
      final markdownPath =
          Platform.environment['LOCAL_TASK_AGENT_EVAL_MARKDOWN'] ??
          '$tempDir/lotti-local-task-agent-eval.md';
      _write(jsonPath, report.toPrettyJson());
      _write(markdownPath, report.toMarkdown());

      expect(report.results, isNotEmpty);
      expect(File(jsonPath).existsSync(), isTrue);
      expect(File(markdownPath).existsSync(), isTrue);
      expect(
        report.results.where((result) => !result.passed).toList(),
        isEmpty,
        reason:
            'Local task-agent eval failures were reported. '
            'See $markdownPath.',
      );
    },
    skip: Platform.environment['LOTTI_LOCAL_TASK_AGENT_EVAL_LIVE'] == '1'
        ? null
        : 'Set LOTTI_LOCAL_TASK_AGENT_EVAL_LIVE=1 to run local oMLX inference.',
    timeout: const Timeout(Duration(minutes: 10)),
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

double? _envDouble(String name) {
  return parseLocalTaskAgentEvalTemperature(
    Platform.environment[name],
    name: name,
  );
}

void _write(String path, String content) {
  final file = File(path);
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(content);
}
