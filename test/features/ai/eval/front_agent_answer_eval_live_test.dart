@Tags(['eval-live'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/ai/ai_config.dart';
import 'package:lotti/features/ai/constants/provider_config.dart';
import 'package:lotti/features/ai/conversation/conversation_repository.dart';
import 'package:lotti/features/ai/repository/cloud_inference_repository.dart';
import 'package:lotti/features/ai/repository/cloud_inference_wrapper.dart';
import 'package:lotti/features/companion/model/companion_reaction.dart';
import 'package:lotti/features/front_agent/model/front_logged_time_chart.dart';
import 'package:lotti/features/front_agent/model/front_reply_surface.dart';
import 'package:lotti/features/front_agent/model/front_routing_index.dart';
import 'package:lotti/features/front_agent/workflow/front_agent_contract.dart';
import 'package:lotti/features/front_agent/workflow/front_agent_strategy.dart';
import 'package:lotti/features/front_agent/workflow/front_agent_workflow.dart';
import 'package:lotti/features/insights/model/insights_models.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';
import 'support/front_agent_routing_scenarios.dart';

/// What one question should come back as.
class _AnswerScenario {
  const _AnswerScenario({
    required this.id,
    required this.input,
    this.wants = const {},
    this.proseOnly = false,
    this.cardIds = const {},
    this.dueNone = false,
  });

  final String id;
  final String input;

  /// Component types her answer must draw.
  final Set<String> wants;

  /// Whether she should draw nothing at all.
  final bool proseOnly;

  /// Task ids that must be on cards.
  final Set<String> cardIds;

  /// Whether the due lookup finds nothing this turn.
  final bool dueNone;
}

const _scenarios = [
  _AnswerScenario(
    id: 'due_today',
    input: 'What is due today?',
    wants: {FrontReplyComponents.taskCards},
    cardIds: {'task-fish-order', 'task-bay-c-seam'},
  ),
  _AnswerScenario(
    id: 'overdue_and_due',
    input: 'What is overdue, and what is due today?',
    wants: {FrontReplyComponents.taskCards},
    cardIds: {'task-fish-order', 'task-bay-c-seam'},
  ),
  _AnswerScenario(
    id: 'time_past_week',
    input: 'How much time did I log in the past seven days?',
    wants: {FrontReplyComponents.loggedTimeChart},
  ),
  // Nothing was found: there is nothing to draw, only to say.
  _AnswerScenario(
    id: 'nothing_overdue',
    input: 'Is anything overdue?',
    proseOnly: true,
    dueNone: true,
  ),
];

/// Her answer to a question against a real model, scenario by scenario, with
/// the production strategy, system message and reply parser, a hand-held
/// index (`frontEvalIndex`) and fixed lookup results — so the thing measured
/// is whether a model writes her answer in the reply format: UI blocks
/// first, prose always, cards by id.
///
/// Per scenario and model it reports whether an answer was taken, its prose,
/// the components drawn, the format failures logged, and the provider calls
/// against the three-call bound. A capacity error (HTTP 429) is retried with
/// exponential backoff. The artifact goes outside the repository.
///
/// Run it with:
///
/// ```sh
/// MISTRAL_API_KEY=… \
///   FRONT_ANSWER_EVAL_OUTPUT=/tmp/front-answer-eval.json \
///   fvm flutter test test/features/ai/eval/front_agent_answer_eval_live_test.dart
/// ```
///
/// `FRONT_ANSWER_EVAL_MODELS` (comma-separated) picks the models,
/// `FRONT_ANSWER_EVAL_RUNS` how often each scenario runs.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(registerAllFallbackValues);

  test(
    'answers every scenario through the real contract and reports',
    timeout: const Timeout(Duration(minutes: 30)),
    () async {
      HttpOverrides.global = null;
      await setUpTestGetIt();
      addTearDown(tearDownTestGetIt);

      final env = Platform.environment;
      final apiKey = env['MISTRAL_API_KEY'] ?? '';
      final output = env['FRONT_ANSWER_EVAL_OUTPUT'];
      expect(apiKey, isNotEmpty, reason: 'Set MISTRAL_API_KEY');
      expect(output, isNotNull, reason: 'Set FRONT_ANSWER_EVAL_OUTPUT');
      final artifactFile = File(output!).absolute;
      expect(
        artifactFile.path.startsWith(
          '${Directory.current.absolute.path}${Platform.pathSeparator}',
        ),
        isFalse,
        reason: 'Generated model output must stay outside the repository',
      );
      final models =
          (env['FRONT_ANSWER_EVAL_MODELS'] ??
                  'mistral-large-4-0,deepseek-v4-1-flash-1017,zai-glm-5-3-flash')
              .split(',');
      final runs = int.parse(env['FRONT_ANSWER_EVAL_RUNS'] ?? '1');

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
                id: 'front-answer-eval-provider',
                name: 'Front answer eval',
                baseUrl: ProviderConfig
                    .defaultBaseUrls[InferenceProviderType.mistral]!,
                apiKey: apiKey,
                inferenceProviderType: InferenceProviderType.mistral,
                createdAt: DateTime(2026, 11, 12),
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
      final now = frontEvalNow;
      final today = DateTime(now.year, now.month, now.day);
      final due = [
        for (final row in frontEvalIndex.rows)
          if (row.id == 'task-fish-order' || row.id == 'task-bay-c-seam') row,
      ];
      expect(due, hasLength(2));

      final rows = <Map<String, Object?>>[];
      var passed = 0;
      var total = 0;
      for (final model in models) {
        for (final scenario in _scenarios) {
          for (var run = 0; run < runs; run++) {
            total++;
            final formatFailures = <String>[];
            final logger = MockDomainLogger();
            when(
              () => logger.log(
                any(),
                any(),
                subDomain: any(named: 'subDomain'),
                level: any(named: 'level'),
              ),
            ).thenAnswer((invocation) {
              final message = invocation.positionalArguments[1] as String;
              if (message.startsWith('front reply format')) {
                formatFailures.add(message);
              }
            });
            // A retry after a 429 is a new turn: a strategy kept from the
            // failed attempt would still count its lookups.
            FrontAgentStrategy newStrategy() => FrontAgentStrategy(
              syncService: syncService,
              domainLogger: logger,
              agentId: 'front-answer-eval',
              threadId: 'thread-${scenario.id}',
              runKey: 'run-${scenario.id}-$run',
              input: scenario.input,
              index: frontEvalIndex,
              now: now,
              corpusMatcher: (_) async => const [],
              dueTaskLister: (query) async => FrontDueTasks(
                window: query.window,
                today: today,
                through: today,
                rows: scenario.dueNone ? const [] : due,
              ),
              loggedTimeSummarizer: (query) async => FrontLoggedTime(
                period: query.period,
                from: today.subtract(const Duration(days: 6)),
                through: today,
                byCategory: const [
                  (name: 'Colony care', seconds: 64800),
                  (name: 'Station maintenance', seconds: 50400),
                ],
                chart: const FrontLoggedTimeChart(
                  range: InsightsRange(startDay: 20397, endDayExclusive: 20404),
                  categoryIds: {},
                ),
              ),
            );

            var strategy = newStrategy();
            final watch = Stopwatch()..start();
            Object? failure;
            var providerCalls = 0;
            try {
              await _withBackoff(() async {
                strategy = newStrategy();
                formatFailures.clear();
                final conversationId = conversations.createConversation(
                  systemMessage: frontAgentSystemMessage(CompanionSass.warm),
                );
                try {
                  // The turn as the workflow runs it: one send, her answer
                  // taken, then the one repair the budget allows.
                  Future<void> send(String message, int budget) =>
                      conversations.sendMessage(
                        conversationId: conversationId,
                        message: message,
                        model: model,
                        provider: provider,
                        inferenceRepo: inferenceRepo,
                        tools: tools,
                        temperature: 0,
                        strategy: strategy,
                        rethrowInferenceErrors: true,
                        turnBudget: budget,
                      );
                  await send(
                    renderFrontTurn(
                      index: frontEvalIndex,
                      recent: const [],
                      input: scenario.input,
                      now: now,
                    ),
                    frontProviderCallsPerTurn,
                  );
                  final manager = conversations.getConversation(conversationId);
                  frontTakeAnswer(strategy, manager);
                  final calls = manager?.turnCount ?? frontProviderCallsPerTurn;
                  if (!strategy.hasTerminalOutput &&
                      calls < frontProviderCallsPerTurn) {
                    await send(
                      frontContinuationInstruction(
                        answerLookups: strategy.answerLookupCalls,
                        rejectedDispatches: strategy.rejectedDispatches,
                      ),
                      frontProviderCallsPerTurn - calls,
                    );
                    frontTakeAnswer(strategy, manager);
                  }
                  providerCalls = manager?.turnCount ?? 0;
                } finally {
                  conversations.deleteConversation(conversationId);
                }
              });
            } catch (error) {
              failure = error;
            }
            watch.stop();

            final drawn = [
              for (final component in strategy.replyComponents)
                component['component'],
            ];
            final cards = {
              for (final component in strategy.replyComponents)
                if (component case {'items': final List<Object?> items})
                  for (final item in items) (item! as Map)['id'],
            };
            final failed = <String>[
              if (failure != null) 'threw',
              if (strategy.replyToUser == null) 'no answer taken',
              if (formatFailures.isNotEmpty) 'format failure logged',
              for (final want in scenario.wants)
                if (!drawn.contains(want)) 'missing $want',
              if (scenario.proseOnly &&
                  drawn.any((type) => type != FrontReplyComponents.text))
                'drew UI with nothing to show',
              for (final id in scenario.cardIds)
                if (!cards.contains(id)) 'missing card $id',
              if (strategy.dispatch != null) 'dispatched a question',
            ];
            if (failed.isEmpty) passed++;
            rows.add({
              'model': model,
              'scenario': scenario.id,
              'input': scenario.input,
              'answer': strategy.replyToUser,
              'drawn': drawn,
              'cards': cards.toList(),
              'formatFailures': formatFailures,
              'lookupCalls': strategy.lookupCalls,
              'providerCalls': providerCalls,
              'milliseconds': watch.elapsedMilliseconds,
              'failure': failure?.toString(),
              'failedChecks': failed,
            });
            artifactFile.writeAsStringSync(
              const JsonEncoder.withIndent('  ').convert({
                'schemaVersion': 1,
                'models': models,
                'total': total,
                'passed': passed,
                'rows': rows,
              }),
            );
          }
        }
      }
      // The artifact is the result; a model may lose a scenario without the
      // run being a failure, but a run that never reached a model is.
      expect(rows.where((r) => r['failure'] != null), isEmpty);
    },
  );
}

/// Runs [body], and again after a wait that doubles each time, while the
/// provider answers that it is out of capacity (HTTP 429).
Future<void> _withBackoff(Future<void> Function() body) async {
  for (var attempt = 0; ; attempt++) {
    try {
      return await body();
    } catch (error) {
      if (!'$error'.contains('429') || attempt >= 7) rethrow;
      await Future<void>.delayed(Duration(seconds: 2 << attempt));
    }
  }
}
