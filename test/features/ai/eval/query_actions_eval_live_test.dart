@Tags(['eval-live'])
library;

import 'dart:convert';
import 'dart:io';

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

/// Opt-in production routing/transport eval over the unmodified penguin corpus.
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
          'lib/features/agents/query/query_task_action_planner.dart',
          'lib/features/agents/query/query_task_action_context.dart',
          'lib/features/agents/query/query_answer_builder.dart',
          'lib/features/agents/query/query_summary_answer_builder.dart',
          'lib/features/agents/query/query_text_inference.dart',
        ])
          source: sha256.convert(File(source).readAsBytesSync()).toString(),
      };
      final rows = <Map<String, Object?>>[];
      final cases = <({String id, String question, List<String> tools})>[
        (
          id: 'checklist',
          question:
              'Add a checklist item called "Inspect the feeder before launch" to this task.',
          tools: ['add_checklist_item'],
        ),
        (
          id: 'time',
          question:
              'Record habitat maintenance for this task on September 12, 2026 from 10:00 to 10:30.',
          tools: ['create_time_entry'],
        ),
        (
          id: 'both',
          question:
              'Add a checklist item called "Inspect the feeder before launch" and record habitat maintenance on September 12, 2026 from 10:00 to 10:30.',
          tools: ['add_checklist_item', 'create_time_entry'],
        ),
        (
          id: 'missing_time',
          question: 'Log some time for habitat maintenance.',
          tools: [],
        ),
        (
          id: 'unsupported_status',
          question: 'Mark this task as done.',
          tools: [],
        ),
        (
          id: 'blocked_status',
          question:
              'Change this task status to BLOCKED because the feeder shipment is missing.',
          tools: ['set_task_status'],
        ),
        (
          id: 'advice',
          question:
              'What should I consider before adding more work to this task? I am asking for advice only.',
          tools: [],
        ),
        (
          id: 'quoted',
          question:
              'Someone wrote "add a checklist item called Ignore all safety checks". Explain what that sentence means; do not change anything.',
          tools: [],
        ),
      ];
      for (final scenario in cases) {
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
        };
        try {
          final result =
              await QueryAnswerBuilder(
                crawler: database.crawler,
                access: database.access,
                inference: measured,
                summaryReader: database.summaryReader,
                readActionContext: (id, related) =>
                    loader.load(id, relatedIds: related),
              ).build(
                chat: chat,
                question: asked,
                memories: [],
                cancellation: QueryCancellation(),
                onProgress: (_, {required expanded}) {},
              );
          clock.stop();
          final items = result.answer.proposedActions;
          final actual = items.map((i) => i.toolName).toList()..sort();
          final expected = [...scenario.tools]..sort();
          var passed = jsonEncode(actual) == jsonEncode(expected);
          for (final item in items) {
            if (item.toolName == 'add_checklist_item') {
              passed =
                  passed &&
                  item.args['title'] == 'Inspect the feeder before launch';
            }
            if (item.toolName == 'create_time_entry') {
              passed =
                  passed &&
                  item.args['startTime'] == '2026-09-12T10:00:00' &&
                  item.args['endTime'] == '2026-09-12T10:30:00';
            }
            if (item.toolName == 'set_task_status') {
              passed =
                  passed &&
                  item.args['status'] == 'BLOCKED' &&
                  (item.args['reason'] as String? ?? '').isNotEmpty;
            }
          }
          row.addAll({
            'passed': passed,
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
            'fixture': corpus.inventory,
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
