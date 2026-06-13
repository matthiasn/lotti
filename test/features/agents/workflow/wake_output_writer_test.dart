import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/observation_record.dart';
import 'package:lotti/features/agents/model/proposal_ledger.dart';
import 'package:lotti/features/agents/service/suggestion_retraction_service.dart';
import 'package:lotti/features/agents/workflow/wake_output_writer.dart';
import 'package:lotti/features/sync/g_counter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:uuid/uuid.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';

// Deterministic identity / time used across the suite.
const _agentId = 'agent-1';
const _taskId = 'task-1';
const _threadId = 'thread-1';
const _runKey = 'run-1';
final _now = DateTime(2024, 3, 15, 9, 30);

/// A [Uuid] stub that hands out ids from a fixed queue, falling back to a
/// counter-suffixed value once the queue drains. Lets tests assert on the
/// exact ids the writer minted (e.g. the report id surfaced in the result).
///
/// `v4` is routed through [noSuchMethod] rather than a typed override so the
/// stub does not depend on the uuid package's unexported `V4Options` type.
class _SequentialUuid implements Uuid {
  _SequentialUuid(this._ids);

  final List<String> _ids;
  int _index = 0;

  String _next() {
    if (_index < _ids.length) return _ids[_index++];
    return 'uuid-${_index++}';
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #v4) return _next();
    return super.noSuchMethod(invocation);
  }
}

AgentStateEntity _state({GCounter? wakeCounter}) =>
    AgentDomainEntity.agentState(
          id: 'state-1',
          agentId: _agentId,
          slots: const AgentSlots(activeTaskId: _taskId),
          updatedAt: DateTime(2024),
          vectorClock: null,
          consecutiveFailureCount: 3,
          wakeCounter: wakeCounter ?? const GCounter.empty(),
        )
        as AgentStateEntity;

ProposalLedger _ledger(List<LedgerEntry> resolved) =>
    ProposalLedger(open: const [], resolved: resolved);

LedgerEntry _resolvedEntry({
  required String toolName,
  required String fingerprint,
  required String humanSummary,
  required ChangeDecisionVerdict verdict,
  Map<String, dynamic> args = const {},
}) => LedgerEntry(
  changeSetId: 'cs-1',
  itemIndex: 0,
  toolName: toolName,
  args: args,
  humanSummary: humanSummary,
  fingerprint: fingerprint,
  status: ChangeItemStatus.confirmed,
  createdAt: _now,
  verdict: verdict,
);

void main() {
  setUpAll(registerAllFallbackValues);

  late MockAgentSyncService sync;
  late MockAgentRepository repo;
  late MockTaskAgentStrategy strategy;
  late MockSuggestionRetractionService retraction;
  late MockChangeSetBuilder builder;

  setUp(() {
    sync = MockAgentSyncService();
    repo = MockAgentRepository();
    strategy = MockTaskAgentStrategy();
    retraction = MockSuggestionRetractionService();
    builder = MockChangeSetBuilder();

    // upsertEntity, appendMilestone, build, applyStaged are fire-and-forget
    // here; stub them to no-ops. runInTransaction/localHost have mock defaults.
    when(() => sync.upsertEntity(any())).thenAnswer((_) async {});
    stubAppendMilestone(sync);
    when(
      () => builder.build(
        sync,
        existingPendingSets: any(named: 'existingPendingSets'),
        rejectedFingerprints: any(named: 'rejectedFingerprints'),
        rejectedDisplayKeys: any(named: 'rejectedDisplayKeys'),
      ),
    ).thenAnswer((_) async => null);
    when(() => builder.proposedFingerprints).thenReturn(const {});
    when(
      () => retraction.applyStaged(
        any(),
        skipFingerprints: any(named: 'skipFingerprints'),
      ),
    ).thenAnswer((_) async {});

    // Sensible strategy defaults; individual tests override what they assert.
    when(() => strategy.finalResponse).thenReturn(null);
    when(() => strategy.extractStagedRetractions()).thenReturn(const []);
  });

  WakeOutputWriter writer({Uuid? uuid}) => WakeOutputWriter(
    syncService: sync,
    agentRepository: repo,
    uuid: uuid ?? const Uuid(),
  );

  Future<WakeReportToEmbed?> run({
    String reportContent = '',
    String? reportTldr,
    String? reportOneLiner,
    List<ObservationRecord> observations = const [],
    ProposalLedger? ledger,
    AgentStateEntity? state,
    Uuid? uuid,
  }) => writer(uuid: uuid).persist(
    strategy: strategy,
    reportContent: reportContent,
    reportTldr: reportTldr,
    reportOneLiner: reportOneLiner,
    observations: observations,
    retractionService: retraction,
    changeSetBuilder: builder,
    ledger: ledger ?? _ledger(const []),
    pendingSets: const [],
    state: state ?? _state(),
    taskId: _taskId,
    agentId: _agentId,
    threadId: _threadId,
    runKey: _runKey,
    now: _now,
  );

  // Drains every captured `upsertEntity` argument, in call order. `verify`
  // consumes the recorded calls, so this must be called at most ONCE per test;
  // assertions then filter the returned list locally.
  List<AgentDomainEntity> capturedUpserts() => verify(
    () => sync.upsertEntity(captureAny()),
  ).captured.cast<AgentDomainEntity>();

  group('thought message', () {
    test(
      'non-null finalResponse upserts a thought payload + message',
      () async {
        when(() => strategy.finalResponse).thenReturn('I considered the task.');

        await run();

        final upserts = capturedUpserts();
        final payloads = upserts
            .whereType<AgentMessagePayloadEntity>()
            .where((p) => p.content['text'] == 'I considered the task.')
            .toList();
        expect(payloads, hasLength(1));
        final thoughtMessages = upserts
            .whereType<AgentMessageEntity>()
            .where((m) => m.kind == AgentMessageKind.thought)
            .toList();
        expect(thoughtMessages, hasLength(1));
        // The thought message links back to its payload.
        expect(thoughtMessages.single.contentEntryId, payloads.single.id);
      },
    );

    test(
      'null finalResponse upserts neither a thought payload nor message',
      () async {
        when(() => strategy.finalResponse).thenReturn(null);

        await run();

        final upserts = capturedUpserts();
        expect(
          upserts.whereType<AgentMessagePayloadEntity>().where(
            (p) => p.content.containsKey('text'),
          ),
          isEmpty,
        );
        expect(
          upserts.whereType<AgentMessageEntity>().where(
            (m) => m.kind == AgentMessageKind.thought,
          ),
          isEmpty,
        );
      },
    );
  });

  group('report', () {
    test('non-empty content writes report + head, reuses existing head id, '
        'and returns the report to embed', () async {
      when(
        () => repo.getReportHead(_agentId, AgentReportScopes.current),
      ).thenAnswer(
        (_) async =>
            AgentDomainEntity.agentReportHead(
                  id: 'head-existing',
                  agentId: _agentId,
                  scope: AgentReportScopes.current,
                  reportId: 'report-previous',
                  updatedAt: DateTime(2024),
                  vectorClock: null,
                )
                as AgentReportHeadEntity,
      );

      final result = await run(
        reportContent: '# Status\nAll good.',
        reportTldr: 'all good',
        reportOneLiner: 'ok',
        uuid: _SequentialUuid(['report-new']),
      );

      // Report + head both written.
      final reports = verify(
        () => sync.upsertEntity(captureAny()),
      ).captured.cast<AgentDomainEntity>();
      final report = reports.whereType<AgentReportEntity>().single;
      expect(report.id, 'report-new');
      expect(report.content, '# Status\nAll good.');
      expect(report.tldr, 'all good');
      expect(report.oneLiner, 'ok');

      final head = reports.whereType<AgentReportHeadEntity>().single;
      // Existing head id is reused (LWW pointer update, not a new row).
      expect(head.id, 'head-existing');
      expect(head.reportId, 'report-new');

      // Result carries the new report id and the superseded one.
      expect(result, isNotNull);
      expect(result!.reportId, 'report-new');
      expect(result.reportContent, '# Status\nAll good.');
      expect(result.taskId, _taskId);
      expect(result.previousReportId, 'report-previous');
    });

    test('mints a fresh head id when there is no existing head', () async {
      when(
        () => repo.getReportHead(_agentId, AgentReportScopes.current),
      ).thenAnswer((_) async => null);

      final result = await run(
        reportContent: 'first report',
        uuid: _SequentialUuid(['report-id', 'head-id']),
      );

      final head = verify(() => sync.upsertEntity(captureAny())).captured
          .cast<AgentDomainEntity>()
          .whereType<AgentReportHeadEntity>()
          .single;
      expect(head.id, 'head-id');
      expect(result!.previousReportId, isNull);
    });

    test('empty content writes no report and persist returns null', () async {
      final result = await run();

      expect(result, isNull);
      final upserts = capturedUpserts();
      expect(upserts.whereType<AgentReportEntity>(), isEmpty);
      expect(upserts.whereType<AgentReportHeadEntity>(), isEmpty);
      // No report means the head read is skipped entirely.
      verifyNever(() => repo.getReportHead(any(), any()));
    });
  });

  group('observations', () {
    test(
      'each observation upserts a payload and an observation message',
      () async {
        await run(
          observations: const [
            ObservationRecord(
              text: 'first',
              priority: ObservationPriority.critical,
              category: ObservationCategory.grievance,
            ),
            ObservationRecord(text: 'second'),
          ],
        );

        final upserts = capturedUpserts();
        final payloads = upserts
            .whereType<AgentMessagePayloadEntity>()
            .where((p) => p.content.containsKey('priority'))
            .toList();
        expect(payloads, hasLength(2));
        expect(payloads.first.content['text'], 'first');
        expect(payloads.first.content['priority'], 'critical');
        expect(payloads.first.content['category'], 'grievance');
        expect(payloads.last.content['priority'], 'routine');

        expect(
          upserts.whereType<AgentMessageEntity>().where(
            (m) => m.kind == AgentMessageKind.observation,
          ),
          hasLength(2),
        );
      },
    );
  });

  group('staged retractions', () {
    test('applyStaged is called with the strategy staged list and the '
        "builder's proposed fingerprints as skip set", () async {
      final staged = <StagedRetraction>[];
      when(() => strategy.extractStagedRetractions()).thenReturn(staged);
      when(() => builder.proposedFingerprints).thenReturn({'fp-a', 'fp-b'});

      await run();

      final captured = verify(
        () => retraction.applyStaged(
          captureAny(),
          skipFingerprints: captureAny(named: 'skipFingerprints'),
        ),
      ).captured;
      expect(captured[0], same(staged));
      expect(captured[1], {'fp-a', 'fp-b'});
    });
  });

  group('change set build', () {
    test(
      'derives rejected fingerprints and display keys from the ledger',
      () async {
        final ledger = _ledger([
          _resolvedEntry(
            toolName: 'set_task_priority',
            fingerprint: 'fp-rejected',
            humanSummary: 'Set priority to high',
            verdict: ChangeDecisionVerdict.rejected,
          ),
          _resolvedEntry(
            toolName: 'set_task_priority',
            fingerprint: 'fp-confirmed',
            humanSummary: 'Set priority to low',
            verdict: ChangeDecisionVerdict.confirmed,
          ),
        ]);

        await run(ledger: ledger);

        final rejectedFps = verify(
          () => builder.build(
            sync,
            existingPendingSets: any(named: 'existingPendingSets'),
            rejectedFingerprints: captureAny(named: 'rejectedFingerprints'),
            rejectedDisplayKeys: captureAny(named: 'rejectedDisplayKeys'),
          ),
        ).captured;
        // Only the rejected entry contributes its fingerprint.
        expect(rejectedFps[0], {'fp-rejected'});
        // And exactly one display key, derived from the rejected entry only.
        expect((rejectedFps[1] as Set).length, 1);
      },
    );
  });

  group('state + milestone', () {
    test(
      'persists state with reset failure count and incremented wakeCounter',
      () async {
        await run(state: _state(wakeCounter: const GCounter({'host-a': 4})));

        final state = verify(() => sync.upsertEntity(captureAny())).captured
            .cast<AgentDomainEntity>()
            .whereType<AgentStateEntity>()
            .single;
        expect(state.consecutiveFailureCount, 0);
        expect(state.lastWakeAt, _now);
        expect(state.updatedAt, _now);
        // 4 (host-a) + 1 (test-host increment) = 5 total.
        expect(state.wakeCounter.value, 5);
      },
    );

    test('appends a wake-completed milestone', () async {
      await run();

      verify(
        () => sync.appendMilestone(
          agentId: _agentId,
          milestone: AgentMilestone.wakeCompleted,
          createdAt: _now,
          threadId: _threadId,
          runKey: _runKey,
        ),
      ).called(1);
    });
  });
}
