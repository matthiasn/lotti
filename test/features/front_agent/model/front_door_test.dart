import 'package:flutter_test/flutter_test.dart';
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
    const outcomes = <FrontDoorOutcome>[
      FrontDoorAnswer(
        text: 'The seam is next.',
        summaryBased: true,
        incomplete: false,
        ownerIds: ['task-1'],
      ),
      FrontDoorChatTurn(
        specialistAgentId: 'goal-a',
        specialistMessageId: 'm-1',
      ),
      FrontDoorSkipped(FrontDoorSkipReason.noAgent),
      FrontDoorFailed('StateError'),
      FrontDoorProposal(ownerId: 'garden'),
      FrontDoorProposal(ownerId: 'garden', generation: 2),
      FrontDoorFiled(entryId: 'entry-1', ownerId: 'garden', generation: 1),
      FrontDoorFiled(entryId: 'entry-2'),
      FrontDoorDeclined(),
      FrontDoorInbox(),
      FrontDoorInbox(newKind: FrontNewKind.goal),
      FrontDoorTaskCreated(taskId: 'task-1'),
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

  test('a proposal and an inbox item wait on the user; everything else does '
      'not', () {
    expect(frontDoorAwaitsUser(const FrontDoorProposal(ownerId: 'g')), isTrue);
    expect(frontDoorAwaitsUser(const FrontDoorInbox()), isTrue);
    for (final settled in const <FrontDoorOutcome?>[
      null,
      FrontDoorFiled(entryId: 'e'),
      FrontDoorDeclined(),
      FrontDoorTaskCreated(taskId: 't'),
      FrontDoorSkipped(FrontDoorSkipReason.noDoor),
      FrontDoorFailed('x'),
      FrontDoorChatTurn(specialistAgentId: 'a', specialistMessageId: 'm'),
      FrontDoorAnswer(text: 't', summaryBased: false, incomplete: false),
    ]) {
      expect(frontDoorAwaitsUser(settled), isFalse, reason: '$settled');
    }
  });
}
