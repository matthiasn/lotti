import 'dart:convert';

import 'package:lotti/features/ai/eval/qwen_local_eval_config.dart';
import 'package:lotti/features/ai/model/ai_config.dart';

enum QwenLocalEvalFailureCategory {
  none,
  emptyResponse,
  missingToolCall,
  wrongToolCall,
  invalidToolArguments,
  argumentMismatch,
  requestFailed,
}

class QwenLocalEvalToolCall {
  const QwenLocalEvalToolCall({
    required this.name,
    required this.argumentsJson,
  });

  final String name;
  final String argumentsJson;

  Map<String, dynamic>? get jsonObjectArguments {
    try {
      final decoded = jsonDecode(argumentsJson);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  bool get hasJsonObjectArguments {
    return jsonObjectArguments != null;
  }

  bool containsExpectedArguments(Map<String, Object?> expectedArguments) {
    final arguments = jsonObjectArguments;
    if (arguments == null) return false;
    return _containsExpectedValues(arguments, expectedArguments);
  }

  Map<String, Object?> toJson() {
    return {
      'name': name,
      'argumentsJson': argumentsJson,
      'argumentsJsonValid': hasJsonObjectArguments,
    };
  }
}

class QwenLocalEvalCaseResult {
  const QwenLocalEvalCaseResult({
    required this.profile,
    required this.scenario,
    required this.provider,
    required this.latencyMs,
    required this.contentLength,
    required this.toolCalls,
    required this.failureCategory,
    this.inputTokens,
    this.outputTokens,
    this.errorMessage,
  });

  final QwenLocalEvalProfile profile;
  final QwenLocalEvalScenario scenario;
  final AiConfigInferenceProvider provider;
  final int latencyMs;
  final int contentLength;
  final int? inputTokens;
  final int? outputTokens;
  final List<QwenLocalEvalToolCall> toolCalls;
  final QwenLocalEvalFailureCategory failureCategory;
  final String? errorMessage;

  bool get passed => failureCategory == QwenLocalEvalFailureCategory.none;

  bool get matchedExpectedTool {
    final expected = scenario.expectedToolName;
    return expected == null || toolCalls.any((call) => call.name == expected);
  }

  bool get matchedExpectedArguments {
    if (!scenario.expectsArguments) return true;
    final expectedToolName = scenario.expectedToolName;
    final expectedArguments = scenario.expectedArgumentsSubset;
    return toolCalls.any((call) {
      final matchesTool =
          expectedToolName == null || call.name == expectedToolName;
      return matchesTool && call.containsExpectedArguments(expectedArguments);
    });
  }

  Map<String, Object?> toJson() {
    return {
      'profileName': profile.name,
      'providerModelId': profile.providerModelId,
      'modelClass': profile.modelClass,
      'scenarioId': scenario.id,
      'provider': {
        'id': provider.id,
        'name': provider.name,
        'type': provider.inferenceProviderType.name,
        'baseUrl': provider.baseUrl,
      },
      'latencyMs': latencyMs,
      'contentLength': contentLength,
      'inputTokens': inputTokens,
      'outputTokens': outputTokens,
      'toolCallCount': toolCalls.length,
      'toolCallNames': toolCalls.map((call) => call.name).toList(),
      'expectedToolName': scenario.expectedToolName,
      'expectedArgumentKeys': scenario.expectedArgumentsSubset.keys.toList(),
      'matchedExpectedTool': matchedExpectedTool,
      'matchedExpectedArguments': matchedExpectedArguments,
      'failureCategory': failureCategory.name,
      'errorMessage': errorMessage,
      'toolCalls': toolCalls.map((call) => call.toJson()).toList(),
    };
  }
}

class QwenLocalEvalProfileSummary {
  const QwenLocalEvalProfileSummary({
    required this.profile,
    required this.totalScenarios,
    required this.passedScenarios,
    required this.averageLatencyMs,
    required this.toolCallScenarioCount,
    required this.matchedToolCallScenarios,
    required this.argumentScenarioCount,
    required this.matchedArgumentScenarios,
    required this.failureCounts,
  });

  final QwenLocalEvalProfile profile;
  final int totalScenarios;
  final int passedScenarios;
  final int averageLatencyMs;
  final int toolCallScenarioCount;
  final int matchedToolCallScenarios;
  final int argumentScenarioCount;
  final int matchedArgumentScenarios;
  final Map<QwenLocalEvalFailureCategory, int> failureCounts;

  double get passRate =>
      totalScenarios == 0 ? 0 : passedScenarios / totalScenarios;

  double get toolCallMatchRate => toolCallScenarioCount == 0
      ? 0
      : matchedToolCallScenarios / toolCallScenarioCount;

  double get argumentMatchRate => argumentScenarioCount == 0
      ? 0
      : matchedArgumentScenarios / argumentScenarioCount;

  Map<String, Object?> toJson() {
    return {
      ...profile.toJson(),
      'totalScenarios': totalScenarios,
      'passedScenarios': passedScenarios,
      'passRate': passRate,
      'averageLatencyMs': averageLatencyMs,
      'toolCallScenarioCount': toolCallScenarioCount,
      'matchedToolCallScenarios': matchedToolCallScenarios,
      'toolCallMatchRate': toolCallMatchRate,
      'argumentScenarioCount': argumentScenarioCount,
      'matchedArgumentScenarios': matchedArgumentScenarios,
      'argumentMatchRate': argumentMatchRate,
      'failureCounts': {
        for (final entry in failureCounts.entries) entry.key.name: entry.value,
      },
    };
  }
}

class QwenLocalEvalReport {
  const QwenLocalEvalReport({
    required this.provider,
    required this.scenarios,
    required this.profiles,
    required this.results,
  });

  final AiConfigInferenceProvider provider;
  final List<QwenLocalEvalScenario> scenarios;
  final List<QwenLocalEvalProfile> profiles;
  final List<QwenLocalEvalCaseResult> results;

  List<QwenLocalEvalProfileSummary> get summaries {
    return profiles
        .map((profile) {
          final profileResults = results
              .where((result) => result.profile.name == profile.name)
              .toList(growable: false);
          final toolScenarios = profileResults.where(
            (result) => result.scenario.expectsToolCall,
          );
          final argumentScenarios = profileResults.where(
            (result) => result.scenario.expectsArguments,
          );
          final latencyTotal = profileResults.fold<int>(
            0,
            (sum, result) => sum + result.latencyMs,
          );
          final failureCounts = <QwenLocalEvalFailureCategory, int>{};
          for (final result in profileResults) {
            if (result.passed) continue;
            failureCounts.update(
              result.failureCategory,
              (count) => count + 1,
              ifAbsent: () => 1,
            );
          }

          return QwenLocalEvalProfileSummary(
            profile: profile,
            totalScenarios: profileResults.length,
            passedScenarios: profileResults
                .where((result) => result.passed)
                .length,
            averageLatencyMs: profileResults.isEmpty
                ? 0
                : latencyTotal ~/ profileResults.length,
            toolCallScenarioCount: toolScenarios.length,
            matchedToolCallScenarios: toolScenarios
                .where((result) => result.matchedExpectedTool)
                .length,
            argumentScenarioCount: argumentScenarios.length,
            matchedArgumentScenarios: argumentScenarios
                .where((result) => result.matchedExpectedArguments)
                .length,
            failureCounts: failureCounts,
          );
        })
        .toList(growable: false);
  }

  String toPrettyJson() {
    return const JsonEncoder.withIndent('  ').convert(toJson());
  }

  Map<String, Object?> toJson() {
    return {
      'schemaVersion': 1,
      'kind': qwenLocalEvalKind,
      'provider': {
        'id': provider.id,
        'name': provider.name,
        'type': provider.inferenceProviderType.name,
        'baseUrl': provider.baseUrl,
      },
      'profiles': profiles.map((profile) => profile.toJson()).toList(),
      'scenarios': scenarios.map((scenario) => scenario.toJson()).toList(),
      'summaries': summaries.map((summary) => summary.toJson()).toList(),
      'results': results.map((result) => result.toJson()).toList(),
    };
  }

  String toMarkdown() {
    final buffer = StringBuffer()
      ..writeln('# Qwen Local Inference Eval')
      ..writeln()
      ..writeln(
        'Provider: `${provider.name}` (${provider.inferenceProviderType.name}) '
        'at `${provider.baseUrl}`',
      )
      ..writeln()
      ..writeln(
        '| Profile | Model | Pass | Avg latency | Tool match | Arg match | Failures |',
      )
      ..writeln('| --- | --- | ---: | ---: | ---: | ---: | --- |');

    for (final summary in summaries) {
      final failures = summary.failureCounts.isEmpty
          ? '-'
          : summary.failureCounts.entries
                .map((entry) => '${entry.key.name}: ${entry.value}')
                .join(', ');
      buffer.writeln(
        '| ${summary.profile.name} | `${summary.profile.providerModelId}` | '
        '${summary.passedScenarios}/${summary.totalScenarios} | '
        '${summary.averageLatencyMs} ms | '
        '${summary.matchedToolCallScenarios}/${summary.toolCallScenarioCount} | '
        '${summary.matchedArgumentScenarios}/${summary.argumentScenarioCount} | '
        '$failures |',
      );
    }

    final failures = results.where((result) => !result.passed);
    if (failures.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('## Failures');
      for (final result in failures) {
        buffer.writeln(
          '- `${result.profile.name}` / `${result.scenario.id}`: '
          '${result.failureCategory.name}'
          '${result.errorMessage == null ? '' : ' - ${result.errorMessage}'}',
        );
      }
    }

    return buffer.toString();
  }
}

bool _containsExpectedValues(
  Map<String, dynamic> actual,
  Map<String, Object?> expected,
) {
  for (final entry in expected.entries) {
    if (!actual.containsKey(entry.key)) return false;
    if (!_matchesExpectedValue(actual[entry.key], entry.value)) return false;
  }
  return true;
}

bool _matchesExpectedValue(Object? actual, Object? expected) {
  if (expected is Map<String, Object?>) {
    return actual is Map<String, dynamic> &&
        _containsExpectedValues(actual, expected);
  }
  if (expected is List<Object?>) {
    if (actual is! List || actual.length != expected.length) return false;
    for (var i = 0; i < expected.length; i++) {
      if (!_matchesExpectedValue(actual[i], expected[i])) return false;
    }
    return true;
  }
  return actual == expected;
}
