@Tags(['eval-live'])
library;

import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/constants/provider_config.dart';
import 'package:lotti/features/ai/eval/qwen_local_inference_eval.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/cloud_inference_repository.dart';
import 'package:lotti/features/ai/repository/cloud_inference_wrapper.dart';

void main() {
  test(
    'writes a compact local Qwen inference report',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      const providerType = InferenceProviderType.omlx;
      final provider = AiConfigInferenceProvider(
        id: 'qwen-local-omlx',
        name: 'Local oMLX',
        baseUrl:
            Platform.environment['QWEN_EVAL_BASE_URL'] ??
            Platform.environment['OMLX_BASE_URL'] ??
            ProviderConfig.defaultBaseUrls[providerType]!,
        apiKey:
            Platform.environment['QWEN_EVAL_API_KEY'] ??
            Platform.environment['OMLX_API_KEY'] ??
            '',
        inferenceProviderType: providerType,
        createdAt: DateTime(2026, 6, 16),
      );
      final profiles = _envList(
        'QWEN_EVAL_PROFILES',
      ).map(parseQwenLocalEvalProfile).toList(growable: false);
      final scenarios = selectQwenLocalEvalScenarios(
        _envList('QWEN_EVAL_SCENARIOS'),
      );

      final runner = QwenLocalInferenceEvalRunner(
        provider: provider,
        repository: CloudInferenceWrapper(
          cloudRepository: container.read(cloudInferenceRepositoryProvider),
        ),
        temperature: _envDouble('QWEN_EVAL_TEMPERATURE') ?? 0,
        maxCompletionTokens: _envInt('QWEN_EVAL_MAX_COMPLETION_TOKENS') ?? 512,
      );

      final report = await runner.run(
        profiles: profiles.isEmpty ? defaultQwenLocalEvalProfiles : profiles,
        scenarios: scenarios,
      );

      final jsonPath =
          Platform.environment['QWEN_EVAL_JSON'] ??
          '/private/tmp/lotti-qwen-local-eval.json';
      final markdownPath =
          Platform.environment['QWEN_EVAL_MARKDOWN'] ??
          '/private/tmp/lotti-qwen-local-eval.md';
      _write(jsonPath, report.toPrettyJson());
      _write(markdownPath, report.toMarkdown());

      expect(report.results, isNotEmpty);
      expect(File(jsonPath).existsSync(), isTrue);
      expect(File(markdownPath).existsSync(), isTrue);
      expect(
        report.results.where((result) => !result.passed).toList(),
        isEmpty,
        reason: 'Local oMLX eval failures were reported. See $markdownPath.',
      );
    },
    skip: Platform.environment['LOTTI_QWEN_EVAL_LIVE'] == '1'
        ? null
        : 'Set LOTTI_QWEN_EVAL_LIVE=1 to run local oMLX inference.',
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
  final value = Platform.environment[name];
  return value == null || value.isEmpty ? null : double.parse(value);
}

int? _envInt(String name) {
  final value = Platform.environment[name];
  return value == null || value.isEmpty ? null : int.parse(value);
}

void _write(String path, String content) {
  final file = File(path);
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(content);
}
