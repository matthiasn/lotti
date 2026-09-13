@Tags(['eval-live'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:clock/clock.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/query_chat_models.dart';
import 'package:lotti/features/agents/query/query_answer_builder.dart';
import 'package:lotti/features/agents/query/query_chat_projection.dart';
import 'package:lotti/features/agents/query/query_task_action_context.dart';
import 'package:lotti/features/agents/query/query_text_inference.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/resolved_profile.dart';
import 'package:lotti/features/ai/repository/cloud_inference_repository.dart';
import 'package:lotti/features/demo/seed/demo_world.dart';

import '../../../helpers/fallbacks.dart';
import '../../../widget_test_utils.dart';
import '../../ai_consumption/test_utils.dart';
import 'support/penguin_query_eval.dart';
import 'support/query_action_eval.dart';
import 'support/query_action_eval_fixture.dart';

/// Opt-in production routing/transport eval with a frozen action-only overlay
/// on the penguin corpus; ordinary query eval fixtures remain unchanged.
/// It cannot apply actions: no approval service or mutation dispatcher is wired.
/// QUERY_EVAL_SUMMARY_REPORTS must be a previously frozen, query-neutral bundle.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(registerAllFallbackValues);
  test(
    'measures time to task action review and guards non-action requests',
    () async {
      HttpOverrides.global = null;
      await setUpTestGetIt();
      addTearDown(tearDownTestGetIt);
      final env = Platform.environment;
      final model = env['QUERY_EVAL_MODEL']!;
      final artifact = File(env['QUERY_EVAL_OUTPUT']!).absolute;
      expect(
        artifact.path.startsWith(
          '${Directory.current.absolute.path}${Platform.pathSeparator}',
        ),
        isFalse,
      );
      expect(artifact.existsSync(), isFalse);
      final endpoint = validatePenguinQueryEndpoint(env['MELIOUS_BASE_URL']!);
      final corpus = PenguinQueryCorpus();
      final database = PenguinQueryDatabase(corpus);
      addTearDown(database.close);
      await database.seed();
      await database.seedReports(
        jsonDecode(File(env['QUERY_EVAL_SUMMARY_REPORTS']!).readAsStringSync())
            as Map<String, dynamic>,
      );
      final fixture = QueryActionEvalFixture(database);
      await fixture.seed();
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final subscription = container.listen(
        cloudInferenceRepositoryProvider,
        (_, _) {},
      );
      addTearDown(subscription.close);
      final provider = AiConfigInferenceProvider(
        id: 'action-eval',
        name: 'Synthetic action eval',
        baseUrl: endpoint.toString(),
        apiKey: env['MELIOUS_API_KEY']!,
        inferenceProviderType: InferenceProviderType.melious,
        createdAt: manualDemoNow,
      );
      final accounting = AiInteractionCaptureTestBench.create();
      final inference = QueryTextInference.forProfile(
        cloud: container.read(cloudInferenceRepositoryProvider),
        profile: ResolvedProfile(
          thinkingModelId: model,
          thinkingProvider: provider,
        ),
        agentId: 'action-eval',
        chatId: 'action-eval',
        categoryId: corpus.task.meta.categoryId,
        taskId: corpus.task.meta.id,
        capture: accounting.capture,
      );
      final sourceHashes = <String, String>{
        for (final source in [
          'test/features/ai/eval/query_actions_eval_live_test.dart',
          'test/features/ai/eval/support/query_action_eval.dart',
          'test/features/ai/eval/support/query_action_eval_fixture.dart',
          'lib/features/agents/tools/agent_tool_registry.dart',
          'lib/features/agents/tools/task_checklist_tool_definitions.dart',
          'lib/features/agents/tools/task_field_tool_definitions.dart',
          'lib/features/agents/tools/task_time_tool_definitions.dart',
          'lib/features/agents/tools/task_link_tool_definitions.dart',
          'lib/features/agents/query/query_task_action_planner.dart',
          'lib/features/agents/query/query_task_action_context.dart',
          'lib/features/agents/query/query_answer_builder.dart',
          'lib/features/agents/query/query_summary_answer_builder.dart',
          'lib/features/agents/query/query_text_inference.dart',
        ])
          source: sha256.convert(File(source).readAsBytesSync()).toString(),
      };
      artifact.parent.createSync(recursive: true);
      final rows = <Map<String, Object?>>[];
      final selected = env['QUERY_ACTION_EVAL_CASES']?.split(',').toSet();
      if (selected != null) {
        expect(
          selected.difference(queryActionEvalCases.map((c) => c.id).toSet()),
          isEmpty,
        );
      }
      final cases = queryActionEvalCases
          .where((c) => selected == null || selected.contains(c.id))
          .toList();
      for (final scenario in cases) {
        await fixture.reset(scenario);
        final measured = MeasuredQueryInference(inference);
        final asked = AgentQueryChatEventEntity(
          id: scenario.id,
          agentId: 'action-eval',
          chatId: scenario.id,
          data: QueryChatQuestion(text: scenario.question),
          createdAt: manualDemoNow,
          vectorClock: null,
        );
        final chat = QueryChatHistory(
          id: scenario.id,
          scope: corpus.scope,
          title: corpus.task.data.title,
          private: false,
          archived: false,
          lastActivity: manualDemoNow,
          events: [asked],
          unread: false,
        );
        final loader = QueryTaskActionContextLoader(access: database.access);
        final clock = Stopwatch()..start();
        final row = <String, Object?>{
          'case': scenario.id,
          'question': scenario.question,
          'activeTimer': scenario.activeTimer,
          'languageAlreadySet': scenario.languageAlreadySet,
        };
        try {
          final result = await withClock(
            Clock.fixed(QueryActionEvalFixture.now),
            () =>
                QueryAnswerBuilder(
                  crawler: database.crawler,
                  access: database.access,
                  inference: measured,
                  summaryReader: database.summaryReader,
                  readActionContext: (id, related) => loader.load(
                    id,
                    relatedIds: related,
                    runningTimerId: scenario.activeTimer
                        ? ActionEvalIds.timer
                        : null,
                  ),
                ).build(
                  chat: chat,
                  question: asked,
                  memories: [],
                  cancellation: QueryCancellation(),
                  onProgress: (_, {required expanded}) {},
                ),
          );
          clock.stop();
          final errors = scenario.grade(result.answer);
          row.addAll({
            'passed': errors.isEmpty,
            'errors': errors,
            'status': 'complete',
            'answer': result.answer.toJson(),
          });
        } catch (error) {
          clock.stop();
          row.addAll({'passed': false, 'status': error.runtimeType.toString()});
        }
        row.addAll({
          'timeToReviewMs': clock.elapsedMicroseconds / 1000,
          'calls': measured.calls,
        });
        rows.add(row);
        artifact.writeAsStringSync(
          const JsonEncoder.withIndent('  ').convert({
            'model': model,
            'sourceHashes': sourceHashes,
            'timingDefinition':
                'Question-to-built-review; excludes publication and UI rendering',
            'fixture': 'penguin-action-overlay-v1',
            'fixtureHash': fixture.hash,
            'baseInventory': corpus.inventory,
            'variant': env['QUERY_EVAL_VARIANT'],
            'caseSelection': cases.map((c) => c.id).toList(),
            'reportInputsHash': database.reportInputsHash,
            'results': rows,
          }),
        );
      }
      expect(
        rows.where((row) => row['passed'] != true).map((row) => row['case']),
        isEmpty,
      );
    },
    skip: Platform.environment['LOTTI_QUERY_ACTION_EVAL_LIVE'] != '1',
    timeout: const Timeout(Duration(minutes: 15)),
  );
}
