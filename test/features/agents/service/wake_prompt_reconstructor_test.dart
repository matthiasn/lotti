import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/proposal_ledger.dart';
import 'package:lotti/features/agents/projection/decision_events.dart';
import 'package:lotti/features/agents/projection/input_capture.dart';
import 'package:lotti/features/agents/service/wake_prompt_reconstructor.dart';
import 'package:lotti/features/agents/sync/agent_input_capture_service.dart';
import 'package:lotti/features/agents/sync/agent_log_compactor.dart';
import 'package:lotti/features/agents/sync/agent_sync_service.dart';
import 'package:lotti/features/agents/workflow/task_agent_workflow.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../sync/in_memory_agent_repository.dart';
import '../test_data/entity_factories.dart';
import '../test_data/link_factories.dart';

const _agentId = 'agent-1';

void main() {
  setUpAll(registerAllFallbackValues);

  late InMemoryAgentRepository repo;
  late AgentSyncService sync;
  late AgentInputCaptureService capture;
  late AgentLogCompactor compactor;
  late WakePromptReconstructor reconstructor;

  setUp(() {
    repo = InMemoryAgentRepository()..seed([makeTestState(agentId: _agentId)]);
    final vc = MockVectorClockService();
    var counter = 0;
    when(
      () => vc.getNextVectorClock(previous: any(named: 'previous')),
    ).thenAnswer((_) async => VectorClock({'h1': ++counter}));
    final outbox = MockOutboxService();
    when(() => outbox.enqueueMessage(any())).thenAnswer((_) async {});
    sync = AgentSyncService(
      repository: repo,
      outboxService: outbox,
      vectorClockService: vc,
    );
    capture = AgentInputCaptureService(syncService: sync);
    compactor = AgentLogCompactor(syncService: sync);
    reconstructor = WakePromptReconstructor(syncService: sync);
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

  test(
    'reconstructs the full prompt byte-identically after later appends',
    () async {
      await captureAll([
        src('e1', 'alpha', day: 1),
        src('e2', 'beta', day: 2),
      ], 10);

      // The wake assembles its log and persists a v2 record around it — the
      // exact split the workflows produce.
      final assembled = await compactor.assembleContextDetailed(_agentId);
      const head = 'PREFIX BLOCKS\n## Task Log\n';
      const tail = '\n\n## Current Task Context\nVOLATILE STATE\n';
      final originalPrompt = head + assembled.text + tail;
      final record = <String, Object?>{
        'promptFormat': 'v2',
        'head': head,
        'tail': tail,
        'log': <String, Object?>{
          'summaryId': ?assembled.activeSummaryId,
          if (assembled.lastEventPosition != null)
            'until': <String, Object?>{
              'at': assembled.lastEventPosition!.at.toIso8601String(),
              'sourceAt': assembled.lastEventPosition!.sourceAt
                  .toIso8601String(),
              'key': assembled.lastEventPosition!.key,
            },
        },
      };

      // History moves on after the wake.
      await captureAll([
        src('e1', 'alpha', day: 1),
        src('e2', 'beta', day: 2),
        src('e3', 'gamma', day: 12),
      ], 12);

      final reconstructed = await reconstructor.reconstruct(
        agentId: _agentId,
        content: record,
      );
      expect(reconstructed, originalPrompt);
    },
  );

  test(
    'splices the day-agent JSON line back via the json-day-log-line wrap',
    () async {
      await captureAll([src('e1', 'note', day: 1)], 10);
      final assembled = await compactor.assembleContextDetailed(_agentId);

      final record = <String, Object?>{
        'promptFormat': 'v2',
        'head': '{\n  "dayId": "2024-03-10",\n',
        'tail': '  "currentLocalTime": "T"\n}',
        'wrap': 'json-day-log-line',
        'log': <String, Object?>{
          if (assembled.lastEventPosition != null)
            'until': <String, Object?>{
              'at': assembled.lastEventPosition!.at.toIso8601String(),
              'sourceAt': assembled.lastEventPosition!.sourceAt
                  .toIso8601String(),
              'key': assembled.lastEventPosition!.key,
            },
        },
      };

      final reconstructed = (await reconstructor.reconstruct(
        agentId: _agentId,
        content: record,
      ))!;

      expect(reconstructed, startsWith('{\n  "dayId": "2024-03-10",\n'));
      expect(reconstructed, contains('"dayLog": "### Recent entries'));
      expect(reconstructed, endsWith('  "currentLocalTime": "T"\n}'));
      // The JSON stays parseable with the re-encoded line in place.
      expect(reconstructed, contains('note'));
    },
  );

  test('returns null for legacy text payloads', () async {
    expect(
      await reconstructor.reconstruct(
        agentId: _agentId,
        content: const {'text': 'a legacy full prompt'},
      ),
      isNull,
    );
  });

  test(
    're-derives resolved decision events through the agent task link',
    () async {
      await repo.upsertLink(
        makeTestAgentTaskLink(
          id: 'link-task',
          fromId: _agentId,
          toId: 'task-1',
        ),
      );
      // A verdict resolved BEFORE the wake's boundary: it was in the prompt,
      // so reconstruction must re-derive it from the synced ledger.
      final entry = LedgerEntry(
        changeSetId: 'cs-1',
        itemIndex: 0,
        toolName: 'set_task_title',
        args: const {},
        humanSummary: 'Set title to "X"',
        fingerprint: 'set_task_title:123',
        status: ChangeItemStatus.confirmed,
        createdAt: DateTime.utc(2024, 3, 5),
        resolvedAt: DateTime.utc(2024, 3, 5),
        resolvedBy: DecisionActor.user,
        verdict: ChangeDecisionVerdict.confirmed,
      );
      when(
        () => repo.getProposalLedger(
          _agentId,
          taskId: 'task-1',
          resolvedLimit: TaskAgentWorkflow.resolvedDecisionWindow,
        ),
      ).thenAnswer(
        (_) async => ProposalLedger(open: const [], resolved: [entry]),
      );
      await captureAll([src('e1', 'note', day: 1)], 10);
      final assembled = await compactor.assembleContextDetailed(_agentId);

      final reconstructed = await reconstructor.reconstruct(
        agentId: _agentId,
        content: <String, Object?>{
          'promptFormat': 'v2',
          'head': 'H\n',
          'tail': '\nT',
          'log': <String, Object?>{
            if (assembled.lastEventPosition != null)
              'until': <String, Object?>{
                'at': assembled.lastEventPosition!.at.toIso8601String(),
                'sourceAt': assembled.lastEventPosition!.sourceAt
                    .toIso8601String(),
                'key': assembled.lastEventPosition!.key,
              },
          },
        },
      );
      expect(reconstructed, contains('note'));
      expect(reconstructed, contains(formatResolvedLedgerLine(entry)));
    },
  );

  test(
    'absorbs inline-event lookup failures and reconstructs without them',
    () async {
      // The task-link read throws (e.g. the ledger table is unavailable):
      // reconstruction degrades to the captured log alone, never to null.
      await repo.upsertLink(
        makeTestAgentTaskLink(
          id: 'link-task',
          fromId: _agentId,
          toId: 'task-1',
        ),
      );
      when(
        () => repo.getProposalLedger(
          _agentId,
          taskId: 'task-1',
          resolvedLimit: TaskAgentWorkflow.resolvedDecisionWindow,
        ),
      ).thenThrow(StateError('ledger unavailable'));
      await captureAll([src('e1', 'note', day: 1)], 10);
      final assembled = await compactor.assembleContextDetailed(_agentId);

      final reconstructed = await reconstructor.reconstruct(
        agentId: _agentId,
        content: <String, Object?>{
          'promptFormat': 'v2',
          'head': 'H\n',
          'tail': '\nT',
          'log': <String, Object?>{
            if (assembled.lastEventPosition != null)
              'until': <String, Object?>{
                'at': assembled.lastEventPosition!.at.toIso8601String(),
                'sourceAt': assembled.lastEventPosition!.sourceAt
                    .toIso8601String(),
                'key': assembled.lastEventPosition!.key,
              },
          },
        },
      );
      expect(reconstructed, 'H\n${assembled.text}\nT');
    },
  );
}
