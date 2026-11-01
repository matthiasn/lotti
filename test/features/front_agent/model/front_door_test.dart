import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/agents/query_chat_models.dart';
import 'package:lotti/features/front_agent/model/front_dispatch.dart';
import 'package:lotti/features/front_agent/model/front_door.dart';

void main() {
  final claimedAt = DateTime.utc(2026, 10, 24, 9);

  FrontDoorRecord record({FrontDoorOutcome? outcome}) => FrontDoorRecord(
    segmentIndex: 2,
    text: 'Ask Pip about Friday.',
    kind: FrontDestinationKind.person,
    destinationId: 'pip',
    ownerTitle: 'Pip',
    status: outcome == null ? FrontDoorStatus.claimed : FrontDoorStatus.done,
    claimedAt: claimedAt,
    outcome: outcome,
  );

  test('the record id is the dispatch record plus the segment index', () {
    expect(frontDoorRecordId('dispatch-1', 2), 'dispatch-1:door:2');
    expect(frontDoorToolName, 'front_door');
  });

  test('a claim goes stale after the grace, a done record never does', () {
    final claim = record();
    expect(
      claim.isStaleClaimAt(claimedAt.add(const Duration(minutes: 29))),
      isFalse,
    );
    expect(claim.isStaleClaimAt(claimedAt.add(frontDoorClaimGrace)), isTrue);
    final done = claim.done(const FrontDoorSkipped(FrontDoorSkipReason.noDoor));
    expect(done.status, FrontDoorStatus.done);
    expect(
      done.isStaleClaimAt(claimedAt.add(const Duration(days: 1))),
      isFalse,
    );
  });

  test('every outcome round-trips through JSON', () {
    final outcomes = <FrontDoorOutcome>[
      const FrontDoorAnswer(
        text: 'The seam is next.',
        summaryBased: true,
        incomplete: false,
        ownerIds: ['task-1'],
      ),
      const FrontDoorChatTurn(
        specialistAgentId: 'goal-a',
        specialistMessageId: 'm-1',
      ),
      const FrontDoorSkipped(FrontDoorSkipReason.noAgent),
      const FrontDoorFailed('StateError'),
      const FrontDoorProposal(ownerId: 'garden'),
      const FrontDoorProposal(ownerId: 'garden', generation: 2),
      const FrontDoorFiled(
        entryId: 'entry-1',
        ownerId: 'garden',
        generation: 1,
      ),
      const FrontDoorFiled(entryId: 'entry-2'),
      const FrontDoorFiled(entryId: 'entry-3', newKind: FrontNewKind.goal),
      const FrontDoorDeclined(),
      const FrontDoorDeclined(ownerId: 'garden', generation: 2),
      const FrontDoorDeclined(newKind: FrontNewKind.goal, generation: 1),
      const FrontDoorInbox(),
      const FrontDoorInbox(newKind: FrontNewKind.goal),
      const FrontDoorInbox(newKind: FrontNewKind.project, generation: 1),
      const FrontDoorInbox(ownerId: 'garden', generation: 2),
      const FrontDoorTaskCreated(taskId: 'task-1'),
      const FrontDoorTaskCreated(
        taskId: 'task-2',
        newKind: FrontNewKind.task,
        generation: 3,
      ),
      const FrontDoorDay(),
      FrontDoorDayPlanned(day: DateTime(2026, 11)),
      const FrontDoorProjectCreated(projectId: 'p-1'),
    ];
    for (final outcome in outcomes) {
      final back = FrontDoorRecord.fromJson(record(outcome: outcome).toJson());
      expect(back, isNotNull, reason: outcome.toJson().toString());
      expect(back!.outcome?.toJson(), outcome.toJson());
      expect(back.status, FrontDoorStatus.done);
      expect(back.segmentIndex, 2);
      expect(back.destinationId, 'pip');
      expect(back.ownerTitle, 'Pip');
      expect(back.claimedAt, claimedAt);
    }
  });

  group('a journal answer', () {
    const source = QuerySourceRef(
      id: 'feeder-note',
      private: false,
      categoryPrivate: false,
      categoryId: 'colony',
    );
    final evidence = QueryEvidence(
      source: source,
      kind: QuerySourceKind.text,
      label: 'Feeder note',
      sourceDate: DateTime(2026, 10, 20),
      textVersion: 'entryText',
      fingerprint: 'f',
      sourceText: 'The seam walk comes after the feeder repair.',
      start: 0,
      end: 13,
      summary: 'The order of the work',
    );

    test('round-trips through stored JSON with its evidence and '
        'dependencies', () {
      final answer = FrontDoorAnswer(
        text: 'After the feeder repair [1].',
        summaryBased: false,
        incomplete: true,
        fromJournal: true,
        private: true,
        evidence: [evidence],
        dependencies: const [source],
      );
      final stored =
          jsonDecode(jsonEncode(record(outcome: answer).toJson()))
              as Map<String, Object?>;

      final back =
          FrontDoorRecord.fromJson(stored)!.outcome! as FrontDoorAnswer;

      expect(back.fromJournal, isTrue);
      expect(back.private, isTrue);
      expect(back.evidence, [evidence]);
      expect(back.dependencies, [source]);
      expect(back.toJson(), answer.toJson());
    });

    test('an owner answer stores none of it, and an older record reads as '
        'an owner answer', () {
      const owner = FrontDoorAnswer(
        text: 't',
        summaryBased: false,
        incomplete: false,
      );
      expect(
        owner.toJson().keys,
        isNot(contains(anyOf('fromJournal', 'evidence', 'dependencies'))),
      );
      final back =
          FrontDoorOutcome.fromJson({'type': 'answer', 'text': 't'})!
              as FrontDoorAnswer;
      expect(back.fromJournal, isFalse);
      expect(back.evidence, isEmpty);
    });

    test('a malformed piece of evidence is left out, the rest kept', () {
      final back =
          FrontDoorOutcome.fromJson({
                'type': 'answer',
                'text': 't',
                'fromJournal': true,
                'evidence': [
                  'not a map',
                  {'label': 'missing everything else'},
                  jsonDecode(jsonEncode(evidence.toJson())),
                ],
                'dependencies': [jsonDecode(jsonEncode(source.toJson())), 7],
              })!
              as FrontDoorAnswer;

      expect(back.evidence, [evidence]);
      expect(back.dependencies, [source]);
    });
  });

  test(
    'a claim round-trips without an outcome and without optional fields',
    () {
      final bare = FrontDoorRecord(
        segmentIndex: 0,
        text: 'Whatever.',
        kind: FrontDestinationKind.unrouted,
        status: FrontDoorStatus.claimed,
        claimedAt: claimedAt,
      );
      final json = bare.toJson();
      expect(json.containsKey('destinationId'), isFalse);
      expect(json.containsKey('outcome'), isFalse);
      final back = FrontDoorRecord.fromJson(json)!;
      expect(back.outcome, isNull);
      expect(back.destinationId, isNull);
      expect(back.ownerTitle, isNull);
    },
  );

  test('a stored shape this build does not know reads as nothing, not a '
      'crash', () {
    expect(FrontDoorRecord.fromJson(const {}), isNull);
    expect(
      FrontDoorRecord.fromJson({...record().toJson(), 'kind': 'hologram'}),
      isNull,
    );
    expect(
      FrontDoorRecord.fromJson({
        ...record().toJson(),
        'claimedAt': 'yesterday',
      }),
      isNull,
    );
    final unknownOutcome = FrontDoorRecord.fromJson({
      ...record().toJson(),
      'outcome': {'type': 'teleport'},
    });
    expect(unknownOutcome, isNotNull);
    expect(unknownOutcome!.outcome, isNull);
    expect(FrontDoorOutcome.fromJson({'type': 'answer'}), isNull);
    expect(FrontDoorOutcome.fromJson({'type': 'chat'}), isNull);
    expect(
      FrontDoorOutcome.fromJson({'type': 'skipped', 'reason': 'laziness'}),
      isNull,
    );
    expect(
      (FrontDoorOutcome.fromJson({'type': 'failed'})! as FrontDoorFailed)
          .errorType,
      'unknown',
    );
    expect(FrontDoorOutcome.fromJson('text'), isNull);
    expect(FrontDoorOutcome.fromJson({'type': 'proposal'}), isNull);
    expect(FrontDoorOutcome.fromJson({'type': 'projectCreated'}), isNull);
    expect(
      FrontDoorOutcome.fromJson({'type': 'dayPlanned', 'day': 'someday'}),
      isNull,
    );
    final proposal =
        FrontDoorOutcome.fromJson({'type': 'proposal', 'ownerId': 'g'})!
            as FrontDoorProposal;
    expect(proposal.generation, 0);
    expect(proposal.unfiled, isFalse);
    expect(
      (FrontDoorOutcome.fromJson({
                'type': 'proposal',
                'ownerId': 'g',
                'generation': 1,
              })!
              as FrontDoorProposal)
          .unfiled,
      isTrue,
    );
    expect(FrontDoorOutcome.fromJson({'type': 'filed'}), isNull);
    expect(FrontDoorOutcome.fromJson({'type': 'taskCreated'}), isNull);
    expect(
      (FrontDoorOutcome.fromJson({'type': 'inbox', 'newKind': 'hologram'})!
              as FrontDoorInbox)
          .newKind,
      isNull,
    );
  });

  test('a proposal, a change to today and an inbox item wait on the user; '
      'everything else does '
      'not', () {
    expect(frontDoorAwaitsUser(const FrontDoorProposal(ownerId: 'g')), isTrue);
    expect(frontDoorAwaitsUser(const FrontDoorInbox()), isTrue);
    expect(frontDoorAwaitsUser(const FrontDoorDay()), isTrue);
    for (final settled in <FrontDoorOutcome?>[
      null,
      const FrontDoorFiled(entryId: 'e'),
      const FrontDoorDeclined(),
      const FrontDoorTaskCreated(taskId: 't'),
      FrontDoorDayPlanned(day: DateTime(2026, 11)),
      const FrontDoorProjectCreated(projectId: 'p'),
      const FrontDoorSkipped(FrontDoorSkipReason.noDoor),
      const FrontDoorFailed('x'),
      const FrontDoorChatTurn(specialistAgentId: 'a', specialistMessageId: 'm'),
      const FrontDoorAnswer(text: 't', summaryBased: false, incomplete: false),
    ]) {
      expect(frontDoorAwaitsUser(settled), isFalse, reason: '$settled');
    }
  });
}
