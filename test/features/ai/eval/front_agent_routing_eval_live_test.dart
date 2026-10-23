@Tags(['eval-live'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/ai/ai_config.dart';
import 'package:lotti/features/ai/constants/provider_config.dart';
import 'package:lotti/features/ai/conversation/conversation_repository.dart';
import 'package:lotti/features/ai/model/inference_usage.dart';
import 'package:lotti/features/ai/repository/cloud_inference_repository.dart';
import 'package:lotti/features/ai/repository/cloud_inference_wrapper.dart';
import 'package:lotti/features/ai/util/known_models.dart';
import 'package:lotti/features/front_agent/model/front_dispatch.dart';
import 'package:lotti/features/front_agent/workflow/front_agent_contract.dart';
import 'package:lotti/features/front_agent/workflow/front_agent_strategy.dart';
import 'package:lotti/features/front_agent/workflow/front_agent_workflow.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';
import 'support/front_agent_routing_scenarios.dart';

/// The front agent's routing turn against a real model, scenario by
/// scenario, with the production strategy, contract and prompt layout and
/// a hand-held index (`frontEvalIndex`), so the thing measured is the
/// model's routing and nothing else.
///
/// Per scenario it reports the outcome, every destination, the lookup
/// calls, the provider calls against the three-call bound, and the cached
/// input tokens of each call — the cache-hit ratio is what the index's
/// sorted, fixed rendering exists for, so it is measured rather than
/// assumed. The artifact goes outside the repository.
///
/// Run it with:
///
/// ```sh
/// MELIOUS_API_KEY=… \
///   FRONT_AGENT_EVAL_MODEL=deepseek-v4.1-flash \
///   FRONT_AGENT_EVAL_OUTPUT=/tmp/front-agent-eval.json \
///   fvm flutter test test/features/ai/eval/front_agent_routing_eval_live_test.dart
/// ```
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(registerAllFallbackValues);

  test('routes every scenario through the real contract and reports', () async {
    HttpOverrides.global = null;
    await setUpTestGetIt();
    addTearDown(tearDownTestGetIt);

    final env = Platform.environment;
    final apiKey =
        env['FRONT_AGENT_EVAL_API_KEY'] ?? env['MELIOUS_API_KEY'] ?? '';
    final baseUrl =
        env['FRONT_AGENT_EVAL_BASE_URL'] ??
        env['MELIOUS_BASE_URL'] ??
        ProviderConfig.defaultBaseUrls[InferenceProviderType.melious]!;
    final modelId =
        env['FRONT_AGENT_EVAL_MODEL'] ?? meliousDeepseekV41FlashModelId;
    final output = env['FRONT_AGENT_EVAL_OUTPUT'];
    expect(apiKey, isNotEmpty, reason: 'Set MELIOUS_API_KEY');
    expect(output, isNotNull, reason: 'Set FRONT_AGENT_EVAL_OUTPUT');
    final artifactFile = File(output!).absolute;
    final root = Directory.current.absolute.path;
    expect(
      artifactFile.path.startsWith('$root${Platform.pathSeparator}'),
      isFalse,
      reason: 'Generated model output must stay outside the repository',
    );
    final selected = env['FRONT_AGENT_EVAL_SCENARIOS']?.split(',').toSet();
    final scenarios = frontEvalScenarios
        .where((s) => selected == null || selected.contains(s.id))
        .toList();
    expect(scenarios, isNotEmpty);

    final container = ProviderContainer();
    addTearDown(container.dispose);
    addTearDown(
      container.listen(conversationRepositoryProvider, (_, _) {}).close,
    );
    addTearDown(
      container.listen(cloudInferenceRepositoryProvider, (_, _) {}).close,
    );
    final provider =
        AiConfig.inferenceProvider(
              id: 'front-agent-eval-provider',
              name: 'Front agent eval',
              baseUrl: baseUrl,
              apiKey: apiKey,
              inferenceProviderType: InferenceProviderType.melious,
              createdAt: DateTime(2026, 10, 23),
            )
            as AiConfigInferenceProvider;
    final inferenceRepo = CloudInferenceWrapper(
      cloudRepository: container.read(cloudInferenceRepositoryProvider),
    );
    final conversations = container.read(
      conversationRepositoryProvider.notifier,
    );
    final syncService = MockAgentSyncService();
    when(() => syncService.upsertEntity(any())).thenAnswer((_) async {});
    final tools = [
      for (final tool in frontAgentTools) tool.toChatCompletionTool(),
    ];
    final now = DateTime(2026, 10, 23, 9, 30);

    final rows = <Map<String, Object?>>[];
    var passed = 0;
    for (final scenario in scenarios) {
      final strategy = FrontAgentStrategy(
        syncService: syncService,
        domainLogger: MockDomainLogger(),
        agentId: 'front-agent-eval',
        threadId: 'thread-${scenario.id}',
        runKey: 'run-${scenario.id}',
        input: scenario.input,
        index: frontEvalIndex,
        // The closed task is not in the corpus either: a match finds nothing.
        corpusMatcher: (_) async => const [],
      );
      final conversationId = conversations.createConversation(
        systemMessage: frontAgentSystemPrompt,
      );
      final watch = Stopwatch()..start();
      InferenceUsage? usage;
      Object? failure;
      try {
        usage = await conversations.sendMessage(
          conversationId: conversationId,
          message: renderFrontTurn(
            index: frontEvalIndex,
            recent: const [],
            input: scenario.input,
            now: now,
          ),
          model: modelId,
          provider: provider,
          inferenceRepo: inferenceRepo,
          tools: tools,
          temperature: 0,
          strategy: strategy,
          rethrowInferenceErrors: true,
          turnBudget: frontProviderCallsPerTurn,
        );
      } catch (error) {
        failure = error;
      }
      final manager = conversations.getConversation(conversationId);
      final providerCalls = manager?.turnCount ?? 0;
      conversations.deleteConversation(conversationId);
      watch.stop();

      final verdict = _judge(scenario, strategy);
      if (verdict.isEmpty) passed++;
      rows.add({
        'scenario': scenario.id,
        'note': scenario.note,
        'input': scenario.input,
        'outcome': strategy.dispatch != null
            ? 'dispatch'
            : strategy.askUser != null
            ? 'ask'
            : strategy.replyToUser != null
            ? 'reply'
            : 'none',
        'segments': [
          for (final segment
              in strategy.dispatch?.segments ?? const <FrontDispatchSegment>[])
            segment.toJson(),
        ],
        'question': strategy.askUser?.question,
        'options': [
          for (final option
              in strategy.askUser?.options ?? const <FrontAskOption>[])
            '${option.kind.wireName}:${option.id}',
        ],
        'reply': strategy.replyToUser,
        'lookupCalls': strategy.lookupCalls,
        'rejectedDispatches': strategy.rejectedDispatches,
        'providerCalls': providerCalls,
        'inputTokens': usage?.inputTokens,
        'cachedInputTokens': usage?.cachedInputTokens,
        'outputTokens': usage?.outputTokens,
        'milliseconds': watch.elapsedMilliseconds,
        'failure': failure?.toString(),
        'failedChecks': verdict,
      });
      artifactFile.writeAsStringSync(
        const JsonEncoder.withIndent('  ').convert({
          'schemaVersion': 1,
          'model': modelId,
          'scenarios': scenarios.length,
          'passed': passed,
          'rows': rows,
        }),
      );
    }
    // The artifact is the result; a cheap model is allowed to lose a
    // scenario without the run being a failure, but a run that never
    // reached the model is.
    expect(rows.where((r) => r['failure'] != null), isEmpty);
  });
}

/// The checks a scenario's outcome fails, by name; empty when it passed.
List<String> _judge(FrontEvalScenario scenario, FrontAgentStrategy strategy) {
  final failed = <String>[];
  final dispatch = strategy.dispatch;
  final ask = strategy.askUser;
  final destinationIds = {
    for (final segment in dispatch?.segments ?? const <FrontDispatchSegment>[])
      ?segment.destinationId,
    for (final option in ask?.options ?? const <FrontAskOption>[]) option.id,
  };
  switch (scenario.outcome) {
    case FrontEvalOutcome.dispatch:
      if (dispatch == null) {
        failed.add('expected dispatch');
      } else {
        for (final expected in scenario.expectedSegments) {
          final hit = dispatch.segments.any(
            (s) =>
                s.kind == expected.kind &&
                (expected.id == null || s.destinationId == expected.id),
          );
          if (!hit) {
            failed.add(
              'missing ${expected.kind.wireName}'
              '${expected.id == null ? '' : ':${expected.id}'}',
            );
          }
        }
      }
    case FrontEvalOutcome.ask:
      if (ask == null) {
        failed.add('expected ask_user');
      } else if (ask.options.any(
        (o) => !scenario.askCandidates.contains(o.id),
      )) {
        failed.add('offered an option outside the candidates');
      }
    case FrontEvalOutcome.reply:
      if (strategy.replyToUser == null) failed.add('expected reply_to_user');
      if (dispatch?.routed.isNotEmpty ?? false) {
        failed.add('dispatched to an existing owner');
      }
  }
  for (final id in scenario.forbiddenDestinationIds) {
    if (destinationIds.contains(id)) failed.add('forbidden destination $id');
  }
  if (strategy.lookupCalls > scenario.maxLookups) {
    failed.add(
      'lookups ${strategy.lookupCalls} > allowed ${scenario.maxLookups}',
    );
  }
  return failed;
}
