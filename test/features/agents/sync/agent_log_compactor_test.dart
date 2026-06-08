import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/proposal_ledger.dart';
import 'package:lotti/features/agents/projection/compaction_summary.dart';
import 'package:lotti/features/agents/projection/decision_events.dart';
import 'package:lotti/features/agents/projection/input_capture.dart';
import 'package:lotti/features/agents/projection/input_events.dart';
import 'package:lotti/features/agents/sync/agent_input_capture_service.dart';
import 'package:lotti/features/agents/sync/agent_log_compactor.dart';
import 'package:lotti/features/agents/sync/agent_sync_service.dart';
import 'package:lotti/features/ai/service/text_chunker.dart';
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
  late AgentSyncService sync;
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
    sync = AgentSyncService(
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

  Future<String?> compact({required int budget, int? retain, int day = 20}) =>
      compactor.maybeCompact(
        agentId: _agentId,
        budget: budget,
        retainTokens: retain,
        summarize: stubSummarize,
        at: DateTime.utc(2024, 3, day),
      );

  /// The token cost the compactor assigns a captured `{'text': ...}` payload —
  /// used to pick budgets relative to real entry sizes instead of guessing.
  int tokensOf(String text) =>
      TextChunker.estimateTokens(jsonEncode({'text': text}));

  List<AgentMessageEntity> summaryMessages() =>
      repo.messages.where((m) => m.kind == AgentMessageKind.summary).toList();

  /// The read-side view the prompt assembly derives: the active checkpoint
  /// (if any) and stable labels for the visible event tail after its cutoff.
  Future<({SummaryCheckpoint? checkpoint, List<String> tailEntryIds})>
  activeView() async {
    final log = projectInputEvents(
      messages: repo.messages,
      links: repo.links,
    );
    final checkpoint = selectActiveSummary(
      summaries: await compactor.loadSummaries(_agentId),
      log: log,
    );
    final tail = visibleTailEvents(log: log, cutoff: checkpoint?.cutoff);
    return (
      checkpoint: checkpoint,
      tailEntryIds: [
        for (final event in tail)
          if (event.inlineContent?['entryType'] == 'retraction')
            'retraction:${event.inlineContent?['sourceEntryId']}'
          else
            event.contentEntryId,
      ],
    );
  }

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

  test('hysteresis: no fold while the tail fits the trigger, even above the '
      'retain mark', () async {
    await captureAll([src('e1', 'a', day: 1), src('e2', 'b', day: 2)], 10);
    // The retain (low) watermark is irrelevant until the trigger (high)
    // watermark is exceeded — between folds, wakes are pure reads and the
    // prompt's summary block stays byte-stable (prefix-cache friendly).
    expect(await compact(budget: 100000, retain: 0), isNull);
    expect(summaryMessages(), isEmpty);
  });

  test(
    'folds down to the retain watermark once the trigger is exceeded',
    () async {
      await captureAll([
        src('e1', 'alpha alpha alpha', day: 1),
        src('e2', 'bravo bravo bravo', day: 2),
        src('e3', 'charlie charlie', day: 3),
      ], 10);
      // Trigger chosen so a fold-to-trigger would fold ONLY e1 (e2+e3 still
      // fit), but the retain watermark folds deeper — e1 AND e2 — leaving
      // headroom so the next wakes do not immediately re-summarize.
      final budget =
          tokensOf('bravo bravo bravo') + tokensOf('charlie charlie');
      expect(await compact(budget: budget, retain: 0), isNotNull);
      expect(summarizeCalls.single.count, 2); // e1 + e2 folded, not just e1

      final view = await activeView();
      expect(view.checkpoint!.coveredSources.keys.toSet(), {'e1', 'e2'});
      expect(view.tailEntryIds, ['e3']);
    },
  );

  test('a retain at or above the trigger folds only to the trigger', () async {
    await captureAll([
      src('e1', 'alpha alpha alpha', day: 1),
      src('e2', 'bravo bravo bravo', day: 2),
      src('e3', 'charlie charlie', day: 3),
    ], 10);
    final budget = tokensOf('bravo bravo bravo') + tokensOf('charlie charlie');
    // Degenerate watermarks (retain >= trigger) fall back to fold-to-trigger.
    expect(await compact(budget: budget, retain: budget), isNotNull);
    expect(summarizeCalls.single.count, 1); // only e1

    final view = await activeView();
    expect(view.checkpoint!.coveredSources.keys.toSet(), {'e1'});
    expect(view.tailEntryIds, ['e2', 'e3']);
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

      final view = await activeView();
      expect(view.checkpoint!.summaryText, 'SUMMARY(2)');
      expect(view.tailEntryIds, ['e3']); // newest stays verbatim
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

      final view = await activeView();
      expect(view.checkpoint!.coveredSources.keys.toSet(), {
        'e1',
        'e2',
        'e3',
        'e4',
      });
      expect(view.tailEntryIds, ['e5']);
    },
  );

  test('an edit of folded content keeps the checkpoint and appends an '
      'edited line to the tail', () async {
    await captureAll([
      src('e1', 'alpha', day: 1),
      src('e2', 'beta', day: 2),
      src('e3', 'gamma', day: 3),
    ], 10);
    await compact(budget: 0); // covers {e1,e2}, tail [e3]

    // e1 is edited after the fold: a NEW event appends; the checkpoint stays
    // active (no full-tail re-expansion as under state-shaped coverage).
    await captureAll([
      src('e1', 'alpha REVISED', day: 1),
      src('e2', 'beta', day: 2),
      src('e3', 'gamma', day: 3),
    ], 11);

    final view = await activeView();
    expect(view.checkpoint, isNotNull);
    expect(view.tailEntryIds, ['e3', 'e1']); // edit appended after the tail

    final context = await compactor.assembleContext(_agentId);
    expect(context, contains('SUMMARY(2)'));
    expect(context, contains('(id: e1, entry, edited) alpha REVISED'));
    // The folded original does not resurface verbatim.
    expect(context.indexOf('gamma'), lessThan(context.indexOf('alpha')));
  });

  test('an edit within the tail appends; the original line stays', () async {
    await captureAll([src('e1', 'first wording', day: 1)], 10);
    await captureAll([src('e1', 'second wording', day: 1)], 11);

    final context = await compactor.assembleContext(_agentId);
    expect(context, contains('(id: e1, entry) first wording'));
    expect(context, contains('(id: e1, entry, edited) second wording'));
    expect(
      context.indexOf('first wording'),
      lessThan(context.indexOf('second wording')),
    );
  });

  test('a retraction of covered content keeps the checkpoint and appends a '
      'retraction line', () async {
    await captureAll([
      src('e1', 'alpha', day: 1),
      src('e2', 'beta', day: 2),
      src('e3', 'gamma', day: 3),
    ], 10);
    await compact(budget: 0); // covers {e1,e2}, tail [e3]

    // e1 is deleted: the wake re-captures without it → retraction event.
    await captureAll([
      src('e2', 'beta', day: 2),
      src('e3', 'gamma', day: 3),
    ], 11);

    final view = await activeView();
    expect(view.checkpoint, isNotNull);
    expect(view.tailEntryIds, ['e3', 'retraction:e1']);

    final context = await compactor.assembleContext(_agentId);
    expect(context, contains('SUMMARY(2)'));
    expect(context, isNot(contains('alpha')));
    expect(context, contains('gamma'));
    expect(
      context,
      contains(
        '(id: e1, retraction) '
        'no longer appears in the current task context',
      ),
    );
  });

  /// Seeds an observation (payload + message) directly into the repo, the
  /// shape `record_observations` persists.
  Future<void> seedObservation(String id, String text, {required int day}) {
    repo.seed([
      AgentDomainEntity.agentMessagePayload(
        id: 'pl-$id',
        agentId: _agentId,
        createdAt: DateTime.utc(2024, 3, day),
        vectorClock: null,
        content: <String, Object?>{'text': text},
      ),
      AgentDomainEntity.agentMessage(
        id: id,
        agentId: _agentId,
        threadId: id,
        kind: AgentMessageKind.observation,
        createdAt: DateTime.utc(2024, 3, day),
        vectorClock: null,
        contentEntryId: 'pl-$id',
        metadata: const AgentMessageMetadata(),
      ),
    ]);
    return Future.value();
  }

  test('the assembled context is append-only across wakes: each earlier '
      'context is a byte prefix of the next', () async {
    // The provider prefix-cache invariant, end to end: between folds, new
    // events (captures, edits, observations, retractions) may only APPEND
    // bytes to the assembled task log — never change existing ones.
    await captureAll([src('e1', 'first note', day: 1)], 10);
    final first = await compactor.assembleContext(_agentId);

    await seedObservation('obs-1', 'a private note', day: 11);
    await captureAll([
      src('e1', 'first note', day: 1),
      src('e2', 'second note', day: 12),
    ], 12);
    final second = await compactor.assembleContext(_agentId);

    // An EDIT also only appends (the original line is frozen).
    await captureAll([
      src('e1', 'first note REVISED', day: 1),
      src('e2', 'second note', day: 12),
    ], 13);
    final third = await compactor.assembleContext(_agentId);

    // A RETRACTION also only appends; the prior captured line is retained as
    // historical evidence, followed by the explicit correction signal.
    await captureAll([src('e1', 'first note REVISED', day: 1)], 14);
    final fourth = await compactor.assembleContext(_agentId);

    expect(second, startsWith(first));
    expect(third, startsWith(second));
    expect(fourth, startsWith(third));
    expect(third, contains('(id: e1, entry, edited) first note REVISED'));
    expect(
      fourth,
      contains(
        '(id: e2, retraction) '
        'no longer appears in the current task context',
      ),
    );
  });

  test('a late-arriving pre-cutoff event (sync) re-expands the tail and the '
      'next fold re-covers it', () async {
    await captureAll([
      src('e1', 'alpha', day: 1),
      src('e2', 'beta', day: 2),
      src('e3', 'gamma', day: 3),
    ], 10);
    await compact(budget: 0); // covers {e1,e2}, cutoff at day 10, tail [e3]
    expect(
      await compactor.assembleContext(_agentId),
      contains('SUMMARY(2)'),
    );

    // Another device captured e-late BEFORE this device folded (capture time
    // day 8 < cutoff day 10) and it syncs in now: it is in neither the prose
    // nor the post-cutoff tail, so the checkpoint must die.
    await capture.captureWakeInputs(
      agentId: _agentId,
      sources: [
        src('e1', 'alpha', day: 1),
        src('e2', 'beta', day: 2),
        src('e3', 'gamma', day: 3),
        src('e-late', 'late from other device', day: 4),
      ],
      at: DateTime.utc(2024, 3, 8),
    );

    final reExpanded = await compactor.assembleContext(_agentId);
    expect(reExpanded, isNot(contains('SUMMARY(2)')));
    expect(reExpanded, contains('late from other device'));
    expect(reExpanded, contains('alpha')); // full verbatim re-expansion
    expect(reExpanded, contains('gamma'));

    // The next fold re-covers everything including the late arrival, and the
    // new checkpoint is complete again.
    await compact(budget: 0, day: 21);
    final refolded = await compactor.assembleContext(_agentId);
    expect(refolded, contains('Summary of earlier activity'));
    expect(refolded, isNot(contains('late from other device')));
    expect(refolded, contains('gamma')); // newest stays verbatim

    final view = await activeView();
    expect(view.checkpoint!.coveredSources.keys, contains('e-late'));
  });

  test('assembleContextAsOf re-derives a past view byte-identically after '
      'later appends and folds', () async {
    // Wake 1's view: a fold covering {e1,e2}, tail [e3].
    await captureAll([
      src('e1', 'alpha', day: 1),
      src('e2', 'beta', day: 2),
      src('e3', 'gamma', day: 3),
    ], 10);
    await compact(budget: 0);
    final wake1 = await compactor.assembleContextDetailed(_agentId);
    expect(wake1.activeSummaryId, isNotNull);
    expect(wake1.lastEventPosition, isNotNull);

    // History moves on: new content, an edit, an observation, another fold.
    await seedObservation('obs-1', 'later note', day: 12);
    await captureAll([
      src('e1', 'alpha', day: 1),
      src('e2', 'beta REVISED', day: 2),
      src('e3', 'gamma', day: 3),
      src('e4', 'delta', day: 13),
    ], 13);
    await compact(budget: 0, day: 14);
    final nowView = await compactor.assembleContext(_agentId);
    expect(nowView, isNot(wake1.text));

    // The pinned marker reproduces wake 1's exact block.
    final reconstructed = await compactor.assembleContextAsOf(
      _agentId,
      summaryId: wake1.activeSummaryId,
      until: wake1.lastEventPosition,
    );
    expect(reconstructed, wake1.text);
  });

  test('assembleContextAsOf preserves content retracted AFTER the wake — the '
      'append-only log keeps the past render intact', () async {
    await captureAll([
      src('e1', 'sensitive note', day: 1),
      src('e2', 'other note', day: 2),
    ], 10);
    final wake1 = await compactor.assembleContextDetailed(_agentId);
    expect(wake1.text, contains('sensitive note'));

    // The user deletes e1 after the wake (re-capture without it). The
    // retraction is appended past wake 1's boundary, so it never reaches back
    // into the pinned reconstruction — retractions document later state, they
    // do not retroactively redact what an earlier wake saw.
    await captureAll([src('e2', 'other note', day: 2)], 11);

    // The retraction really landed: the current view carries a retraction
    // marker for e1, so the historical check below proves the append-only
    // boundary, not a missing delete.
    final view = await activeView();
    expect(view.tailEntryIds, contains('retraction:e1'));

    final reconstructed = await compactor.assembleContextAsOf(
      _agentId,
      summaryId: wake1.activeSummaryId,
      until: wake1.lastEventPosition,
    );
    expect(reconstructed, wake1.text);
    expect(reconstructed, contains('sensitive note'));
    expect(reconstructed, contains('other note'));
  });

  test('decision events share the substrate: they interleave, render with '
      'IDs, and fold', () async {
    await captureAll([src('e1', 'user note', day: 9)], 9);
    await captureAll([
      src('e1', 'user note', day: 9),
      src('e2', 'newest note', day: 12),
    ], 12);

    final decisionCompactor = AgentLogCompactor(
      syncService: sync,
      inlineEvents: decisionEventsFromLedger([
        LedgerEntry(
          changeSetId: 'cs-1',
          itemIndex: 0,
          toolName: 'set_task_title',
          args: const {},
          humanSummary: 'Set title to "X"',
          fingerprint: 'set_task_title:42',
          status: ChangeItemStatus.confirmed,
          createdAt: DateTime.utc(2024, 3, 10),
          resolvedAt: DateTime.utc(2024, 3, 11),
          resolvedBy: DecisionActor.user,
          verdict: ChangeDecisionVerdict.confirmed,
        ),
      ]),
    );

    final context = await decisionCompactor.assembleContext(_agentId);
    expect(
      context,
      contains(
        '(id: cs-1:0, decision) [fp=set_task_title:42] ✓ `set_task_title`: '
        'Set title to "X" — confirmed by user',
      ),
    );
    // Event order: capture(day 9) < decision(day 11) < capture(day 12).
    expect(
      context.indexOf('user note'),
      lessThan(context.indexOf('(id: cs-1:0, decision)')),
    );
    expect(
      context.indexOf('(id: cs-1:0, decision)'),
      lessThan(context.indexOf('newest note')),
    );

    // budget 0 ⇒ fold everything but the newest event: the capture AND the
    // decision fold into the summary by the same watermarks.
    expect(
      await decisionCompactor.maybeCompact(
        agentId: _agentId,
        budget: 0,
        summarize: stubSummarize,
        at: DateTime.utc(2024, 3, 13),
      ),
      isNotNull,
    );
    expect(summarizeCalls.single.count, 2);

    final folded = await decisionCompactor.assembleContext(_agentId);
    expect(folded, contains('SUMMARY(2)'));
    expect(folded, isNot(contains('(id: cs-1:0, decision)')));
    expect(folded, contains('newest note'));
  });

  test(
    'observations interleave with captured content and expose IDs',
    () async {
      await captureAll([src('e1', 'user note', day: 9)], 9);
      await seedObservation('obs-1', 'I noticed the scope changed.', day: 11);
      await captureAll([
        src('e1', 'user note', day: 9),
        src('e2', 'later user note', day: 12),
      ], 12);

      final context = await compactor.assembleContext(_agentId);
      expect(
        context,
        contains(
          '(id: obs-1, observation) I noticed the scope changed.',
        ),
      );
      // Single substrate, event order: capture(day 9) < observation(day 11)
      // < capture(day 12).
      expect(
        context.indexOf('user note'),
        lessThan(context.indexOf('I noticed')),
      );
      expect(
        context.indexOf('I noticed'),
        lessThan(context.indexOf('later user note')),
      );
    },
  );

  test('observations fold into summaries by the same watermarks', () async {
    await captureAll([src('e1', 'alpha', day: 1)], 10);
    await seedObservation('obs-1', 'an old private note', day: 11);
    await captureAll([
      src('e1', 'alpha', day: 1),
      src('e2', 'omega', day: 12),
    ], 12);

    // budget 0 ⇒ fold everything but the newest event (e2's capture).
    expect(await compact(budget: 0, day: 13), isNotNull);
    // The summarizer folded the capture AND the observation.
    expect(summarizeCalls.single.count, 2);

    final context = await compactor.assembleContext(_agentId);
    expect(context, contains('SUMMARY(2)'));
    expect(context, isNot(contains('an old private note')));
    expect(context, contains('omega'));
  });

  test('a retraction of tail-only content keeps its line and appends the '
      'retraction', () async {
    await captureAll([
      src('e1', 'alpha', day: 1),
      src('e2', 'beta', day: 2),
      src('e3', 'gamma', day: 3),
    ], 10);
    await compact(budget: 0); // covers {e1,e2}, tail [e3]

    // e3 (uncovered) is deleted.
    await captureAll([
      src('e1', 'alpha', day: 1),
      src('e2', 'beta', day: 2),
    ], 11);

    final view = await activeView();
    expect(view.checkpoint, isNotNull);
    expect(view.tailEntryIds, ['e3', 'retraction:e3']);

    final context = await compactor.assembleContext(_agentId);
    expect(context, contains('SUMMARY(2)'));
    expect(context, contains('gamma'));
    expect(
      context,
      contains(
        '(id: e3, retraction) '
        'no longer appears in the current task context',
      ),
    );
  });

  test(
    'loadSummaries skips checkpoints whose payload is missing or has the '
    'wrong entity type',
    () async {
      final at = DateTime.utc(2024, 3, 10);
      // Summary message pointing at a payload id that does not exist.
      await repo.upsertEntity(
        AgentDomainEntity.agentMessage(
          id: 'sum-missing',
          agentId: _agentId,
          threadId: 'sum-missing',
          kind: AgentMessageKind.summary,
          createdAt: at,
          vectorClock: null,
          contentEntryId: 'no-such-payload',
          metadata: const AgentMessageMetadata(),
        ),
      );
      // Summary message whose contentEntryId resolves to a NON-payload
      // entity (the seeded agent state).
      final stateId = repo.entities.whereType<AgentStateEntity>().single.id;
      await repo.upsertEntity(
        AgentDomainEntity.agentMessage(
          id: 'sum-wrong-type',
          agentId: _agentId,
          threadId: 'sum-wrong-type',
          kind: AgentMessageKind.summary,
          createdAt: at,
          vectorClock: null,
          contentEntryId: stateId,
          metadata: const AgentMessageMetadata(),
        ),
      );

      // Both rows are silently skipped — no checkpoint, no crash.
      expect(await compactor.loadSummaries(_agentId), isEmpty);
    },
  );

  test(
    'a re-produced checkpoint payload dedupes by content digest: the '
    'payload write is skipped, only a new summary message is appended',
    () async {
      await captureAll([src('e1', 'alpha', day: 1)], 1);
      await captureAll([src('e2', 'beta', day: 2)], 2);

      // First compaction folds e1 and writes checkpoint payload D.
      final budget = tokensOf('beta');
      expect(await compact(budget: budget), isNotNull);
      final firstSummary = summaryMessages().single;
      final payloadId = firstSummary.contentEntryId!;
      final payloadWritesAfterFirst = repo.entityWriteCount(payloadId);

      // Soft-delete the summary message: the checkpoint disappears from the
      // active view, but the content-addressed payload D stays.
      await repo.upsertEntity(
        firstSummary.copyWith(deletedAt: DateTime.utc(2024, 3, 21)),
      );

      // Re-compacting the identical log re-derives the identical payload
      // content → same digest → the `getEntity(payloadId) == null` guard
      // skips the write (ADR 0017 convergence), while a fresh summary
      // message still lands.
      expect(await compact(budget: budget, day: 22), isNotNull);

      expect(
        repo.entityWriteCount(payloadId),
        payloadWritesAfterFirst,
        reason: 'duplicate payload content must not be re-written',
      );
      final liveSummaries = summaryMessages()
          .where((m) => m.deletedAt == null)
          .toList();
      expect(liveSummaries, hasLength(1));
      expect(liveSummaries.single.contentEntryId, payloadId);
      expect(liveSummaries.single.id, isNot(firstSummary.id));
    },
  );

  group('deferred inline events (lazy capture content)', () {
    // Mirrors `dayCaptureEvents`: position + id are eager, transcript resolves
    // on demand so a long-lived agent never reloads its whole history.
    InputEvent deferredCapture(String id, {required int day}) =>
        InputEvent.inlineDeferred(
          position: EventPosition(
            at: DateTime.utc(2024, 3, day, 0, 1),
            sourceAt: DateTime.utc(2024, 3, day),
            key: 'capture|$id',
          ),
          contentEntryId: id,
          sourceCreatedAt: DateTime.utc(2024, 3, day),
        );

    test(
      'the read path resolves content ONLY for the post-cutoff tail; covered '
      'captures stay covered without ever reloading their transcript',
      () async {
        final resolvedIds = <String>[];
        Future<Map<String, Object?>?> resolver(String id) async {
          resolvedIds.add(id);
          return <String, Object?>{'entryType': 'capture', 'text': 'body $id'};
        }

        final events = [
          deferredCapture('c1', day: 1),
          deferredCapture('c2', day: 2),
          deferredCapture('c3', day: 3),
        ];
        final c = AgentLogCompactor(
          syncService: sync,
          inlineEvents: events,
          resolveInlineContent: resolver,
        );

        // First fold covers {c1, c2}; tail = [c3]. (The fold legitimately reads
        // the folded sources once to summarize them.)
        expect(
          await c.maybeCompact(
            agentId: _agentId,
            budget: 0,
            summarize: stubSummarize,
            at: DateTime.utc(2024, 3, 20),
          ),
          isNotNull,
        );

        // The warm-wake invariant: a subsequent assembly reads ONLY the tail.
        resolvedIds.clear();
        final assembled = await c.assembleContextDetailed(_agentId);
        expect(resolvedIds, ['c3']);
        expect(assembled.text, contains('body c3'));
        expect(assembled.text, isNot(contains('body c1')));
        expect(assembled.text, isNot(contains('body c2')));

        // The checkpoint is still active even though c1/c2 content was never
        // reloaded — coverage is proven by id, not by content.
        final active = selectActiveSummary(
          summaries: await c.loadSummaries(_agentId),
          log: projectInputEvents(
            messages: repo.messages,
            links: repo.links,
            inlineEvents: events,
          ),
        );
        expect(active, isNotNull);
      },
    );

    test(
      'a late-arriving deferred capture BEFORE the cutoff invalidates the '
      'checkpoint (convergence preserved without loading content)',
      () async {
        Future<Map<String, Object?>?> resolver(String id) async =>
            <String, Object?>{'entryType': 'capture', 'text': 'body $id'};

        final folded = [
          deferredCapture('c1', day: 1),
          deferredCapture('c2', day: 2),
          deferredCapture('c3', day: 3),
        ];
        final c = AgentLogCompactor(
          syncService: sync,
          inlineEvents: folded,
          resolveInlineContent: resolver,
        );
        // Covers {c1, c2}; cutoff at c2 (day 2).
        await c.maybeCompact(
          agentId: _agentId,
          budget: 0,
          summarize: stubSummarize,
          at: DateTime.utc(2024, 3, 20),
        );

        // A peer's capture lands at day 1 (before the cutoff) and is NOT in the
        // checkpoint's covered set. The completeness check keys on id, so it is
        // detected even though its transcript is never loaded.
        final withLateArrival = projectInputEvents(
          messages: repo.messages,
          links: repo.links,
          inlineEvents: [...folded, deferredCapture('c1b', day: 1)],
        );
        final active = selectActiveSummary(
          summaries: await c.loadSummaries(_agentId),
          log: withLateArrival,
        );
        expect(
          active,
          isNull,
          reason:
              'an uncovered pre-cutoff event must invalidate the checkpoint',
        );
      },
    );
  });

  group('searchLog (recall)', () {
    test('finds folded content the summary no longer shows verbatim', () async {
      await captureAll([
        src('e1', 'buy milk and eggs', day: 1),
        src('e2', 'call the dentist', day: 2),
        src('e3', 'review the Q3 report', day: 3),
      ], 10);
      await compact(budget: 0); // folds e1,e2 into the summary; tail = [e3]

      final folded = await compactor.searchLog(_agentId, query: 'milk');
      expect(folded.map((h) => h.contentEntryId), ['e1']);
      expect(folded.single.text, 'buy milk and eggs');

      final tail = await compactor.searchLog(_agentId, query: 'report');
      expect(tail.map((h) => h.contentEntryId), ['e3']);
    });

    test('term-AND, case-insensitive, newest-first, and limit', () async {
      await captureAll([
        src('e1', 'morning gym session', day: 1),
        src('e2', 'gym membership renewal', day: 2),
        src('e3', 'evening gym plan', day: 3),
      ], 10);

      // All three mention "gym"; results are newest-first, case-insensitive.
      final all = await compactor.searchLog(_agentId, query: 'GYM');
      expect(all.map((h) => h.contentEntryId), ['e3', 'e2', 'e1']);

      // All terms must appear (AND).
      final both = await compactor.searchLog(_agentId, query: 'gym renewal');
      expect(both.map((h) => h.contentEntryId), ['e2']);

      // limit caps the result, keeping the newest.
      final capped = await compactor.searchLog(
        _agentId,
        query: 'gym',
        limit: 1,
      );
      expect(capped.map((h) => h.contentEntryId), ['e3']);
    });

    test('empty and no-match queries return nothing', () async {
      await captureAll([src('e1', 'alpha', day: 1)], 10);
      expect(await compactor.searchLog(_agentId, query: '   '), isEmpty);
      expect(await compactor.searchLog(_agentId, query: 'zzz'), isEmpty);
    });

    test('resolves DEFERRED inline capture content on demand', () async {
      final event = InputEvent.inlineDeferred(
        position: EventPosition(
          at: DateTime.utc(2024, 3, 5, 0, 1),
          sourceAt: DateTime.utc(2024, 3, 5),
          key: 'capture|cap-x',
        ),
        contentEntryId: 'cap-x',
        sourceCreatedAt: DateTime.utc(2024, 3, 5),
      );
      final c = AgentLogCompactor(
        syncService: sync,
        inlineEvents: [event],
        resolveInlineContent: (_) async => <String, Object?>{
          'entryType': 'capture',
          'text': 'lazy transcript about taxes',
        },
      );

      final hits = await c.searchLog(_agentId, query: 'taxes');
      expect(hits.single.contentEntryId, 'cap-x');
      expect(hits.single.type, 'capture');
      expect(hits.single.text, 'lazy transcript about taxes');
    });
  });
}
