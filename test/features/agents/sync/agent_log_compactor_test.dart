import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/projection/compaction_summary.dart';
import 'package:lotti/features/agents/projection/input_capture.dart';
import 'package:lotti/features/agents/projection/input_frontier.dart';
import 'package:lotti/features/agents/sync/agent_input_capture_service.dart';
import 'package:lotti/features/agents/sync/agent_log_compactor.dart';
import 'package:lotti/features/agents/sync/agent_sync_service.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../test_data/entity_factories.dart';
import 'in_memory_agent_repository.dart';

const _agentId = 'agent-1';

void main() {
  setUpAll(registerAllFallbackValues);

  late InMemoryAgentRepository repo;
  late AgentInputCaptureService capture;
  late AgentLogCompactor compactor;
  late List<({int count, String? prior})> summarizeCalls;

  Future<String> stubSummarize({
    required List<RenderedSource> sources,
    String? priorSummary,
  }) async {
    summarizeCalls.add((count: sources.length, prior: priorSummary));
    return 'SUMMARY(${sources.length})';
  }

  setUp(() {
    repo = InMemoryAgentRepository()..seed([makeTestState(agentId: _agentId)]);
    final vc = MockVectorClockService();
    var counter = 0;
    when(
      () => vc.getNextVectorClock(previous: any(named: 'previous')),
    ).thenAnswer((_) async => VectorClock({'h1': ++counter}));
    final outbox = MockOutboxService();
    when(() => outbox.enqueueMessage(any())).thenAnswer((_) async {});
    final sync = AgentSyncService(
      repository: repo,
      outboxService: outbox,
      vectorClockService: vc,
    );
    capture = AgentInputCaptureService(syncService: sync);
    compactor = AgentLogCompactor(syncService: sync);
    summarizeCalls = [];
  });

  RenderedSource src(String entryId, String text, {required int day}) =>
      RenderedSource(
        contentEntryId: entryId,
        sourceCreatedAt: DateTime.utc(2024, 3, day),
        content: {'text': text},
      );

  Future<void> captureAll(List<RenderedSource> sources, int day) =>
      capture.captureWakeInputs(
        agentId: _agentId,
        sources: sources,
        at: DateTime.utc(2024, 3, day),
      );

  Future<String?> compact({required int budget, int day = 20}) =>
      compactor.maybeCompact(
        agentId: _agentId,
        budget: budget,
        summarize: stubSummarize,
        at: DateTime.utc(2024, 3, day),
      );

  List<AgentMessageEntity> summaryMessages() =>
      repo.messages.where((m) => m.kind == AgentMessageKind.summary).toList();

  ActiveSummary activeNow(List<SummaryCheckpoint> checkpoints) =>
      selectActiveSummary(
        frontier: inputFrontierDigests(
          projectInputFrontier(messages: repo.messages, links: repo.links),
        ),
        summaries: checkpoints,
      );

  test('returns null when nothing is captured', () async {
    expect(await compact(budget: 0), isNull);
    expect(summaryMessages(), isEmpty);
  });

  test('assembleContext is empty before anything is captured', () async {
    expect(await compactor.assembleContext(_agentId), isEmpty);
  });

  test(
    'assembleContext renders the active summary above the uncovered tail',
    () async {
      await captureAll([
        src('e1', 'alpha', day: 1),
        src('e2', 'beta', day: 2),
        src('e3', 'gamma', day: 3),
      ], 10);
      await compact(budget: 0); // folds e1,e2 into a summary; tail = [e3]

      final context = await compactor.assembleContext(_agentId);
      expect(context, contains('Summary of earlier activity'));
      expect(context, contains('SUMMARY(2)'));
      expect(context, contains('gamma')); // uncovered tail rendered verbatim
      expect(context, isNot(contains('alpha'))); // folded away into the summary
      expect(context, isNot(contains('beta')));
    },
  );

  test(
    'assembleContext orders the uncovered tail by time then entry id',
    () async {
      // e2 and e3 share a timestamp, so the chronological tiebreak orders them by
      // entry id; no compaction keeps all three as the verbatim tail.
      await captureAll([
        src('e1', 'alpha', day: 1),
        src('e3', 'charlie', day: 3),
        src('e2', 'bravo', day: 3),
      ], 10);

      final context = await compactor.assembleContext(_agentId);
      expect(context.indexOf('alpha'), lessThan(context.indexOf('bravo')));
      expect(context.indexOf('bravo'), lessThan(context.indexOf('charlie')));
    },
  );

  test('does not compact when the tail fits the budget', () async {
    await captureAll([src('e1', 'a', day: 1), src('e2', 'b', day: 2)], 10);
    expect(await compact(budget: 100000), isNull);
    expect(summaryMessages(), isEmpty);
  });

  test(
    'folds the oldest sources into a summary when the tail overflows',
    () async {
      await captureAll([
        src('e1', 'a', day: 1),
        src('e2', 'b', day: 2),
        src('e3', 'c', day: 3),
      ], 10);

      // budget 0 ⇒ fold everything but the newest entry.
      final summaryId = await compact(budget: 0);
      expect(summaryId, isNotNull);
      expect(summaryMessages(), hasLength(1));

      // The summarizer saw the two oldest sources, no prior summary.
      expect(summarizeCalls.single.count, 2);
      expect(summarizeCalls.single.prior, isNull);

      final checkpoints = await compactor.loadSummaries(_agentId);
      expect(checkpoints.single.coveredSources.keys.toSet(), {'e1', 'e2'});

      final active = activeNow(checkpoints);
      expect(active.checkpoint!.summaryText, 'SUMMARY(2)');
      expect(active.uncoveredEntryIds, ['e3']); // newest stays verbatim
    },
  );

  test(
    'a second compaction folds in the prior summary and grows coverage',
    () async {
      await captureAll([
        src('e1', 'a', day: 1),
        src('e2', 'b', day: 2),
        src('e3', 'c', day: 3),
      ], 10);
      await compact(budget: 0); // covers {e1,e2}, tail [e3]

      // More content arrives — pass the full current set so nothing is retracted.
      await captureAll([
        src('e1', 'a', day: 1),
        src('e2', 'b', day: 2),
        src('e3', 'c', day: 3),
        src('e4', 'd', day: 4),
        src('e5', 'e', day: 5),
      ], 11);

      final summaryId = await compact(
        budget: 0,
        day: 21,
      ); // folds e3,e4; keep e5
      expect(summaryId, isNotNull);
      expect(summaryMessages(), hasLength(2));

      // The second summarization received the prior summary text.
      expect(summarizeCalls.last.prior, 'SUMMARY(2)');

      final active = activeNow(await compactor.loadSummaries(_agentId));
      expect(active.checkpoint!.coveredSources.keys.toSet(), {
        'e1',
        'e2',
        'e3',
        'e4',
      });
      expect(active.uncoveredEntryIds, ['e5']);
    },
  );
}
