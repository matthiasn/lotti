import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/front_agent/model/front_dispatch.dart';

void main() {
  const routed = FrontDispatchSegment(
    start: 0,
    end: 12,
    text: 'buy the hose',
    intent: FrontSegmentIntent.instruction,
    kind: FrontDestinationKind.task,
    destinationId: 'task-1',
    confidence: 0.9,
    note: 'Filed under the garden task.',
  );
  const newThing = FrontDispatchSegment(
    start: 14,
    end: 30,
    text: 'start a goal: 10k',
    intent: FrontSegmentIntent.statement,
    kind: FrontDestinationKind.newThing,
    newKind: FrontNewKind.goal,
    confidence: 0.4,
  );
  const unrouted = FrontDispatchSegment(
    start: 31,
    end: 40,
    text: 'and so on',
    intent: FrontSegmentIntent.statement,
    kind: FrontDestinationKind.unrouted,
    confidence: 0,
  );

  test("thresholds and caps are the day agent's and the plan's", () {
    expect(frontStrongConfidence, 0.75);
    expect(frontLowConfidence, 0.5);
    expect(frontMaxSegments, 8);
    expect(frontUnroutedGapShare, 0.2);
  });

  test('only the four owner kinds need an id, and "new" is spelled new', () {
    expect(
      FrontDestinationKind.values.where((k) => k.needsId),
      [
        FrontDestinationKind.task,
        FrontDestinationKind.project,
        FrontDestinationKind.goal,
        FrontDestinationKind.person,
      ],
    );
    expect(FrontDestinationKind.newThing.wireName, 'new');
    expect(
      FrontDestinationKind.fromWireName('new'),
      FrontDestinationKind.newThing,
    );
    expect(FrontDestinationKind.fromWireName('newThing'), isNull);
    expect(
      FrontSegmentIntent.fromName('question'),
      FrontSegmentIntent.question,
    );
    expect(FrontNewKind.fromName('project'), FrontNewKind.project);
    expect(FrontNewKind.fromName(42), isNull);
  });

  test('hasDestination is true only for an owner kind with an id', () {
    expect(routed.hasDestination, isTrue);
    expect(newThing.hasDestination, isFalse);
    expect(unrouted.hasDestination, isFalse);
  });

  test('a dispatch round-trips through JSON, segment by segment', () {
    const dispatch = FrontDispatch(segments: [routed, newThing, unrouted]);
    final json = dispatch.toJson();
    expect(json['segments'], hasLength(3));
    final first = (json['segments']! as List).first as Map<String, Object?>;
    expect(first['destination'], {'kind': 'task', 'id': 'task-1'});
    expect(first['note'], 'Filed under the garden task.');
    final second = (json['segments']! as List)[1] as Map<String, Object?>;
    expect(second['destination'], {'kind': 'new', 'newKind': 'goal'});
    expect(second.containsKey('note'), isFalse);

    final back = FrontDispatch.fromJson(json);
    expect(back.segments, hasLength(3));
    expect(back.segments.first.destinationId, 'task-1');
    expect(back.segments.first.confidence, 0.9);
    expect(back.segments.first.intent, FrontSegmentIntent.instruction);
    expect(back.segments[1].newKind, FrontNewKind.goal);
    expect(back.segments[1].kind, FrontDestinationKind.newThing);
    expect(back.segments[2].kind, FrontDestinationKind.unrouted);
    expect(back.routed.map((s) => s.destinationId), ['task-1']);
    expect(back.unrouted.map((s) => s.text), ['and so on']);
  });

  test('a stored segment with a retired kind or a bad shape is dropped, '
      'not a crash', () {
    final back = FrontDispatch.fromJson({
      'segments': [
        routed.toJson(),
        {
          ...routed.toJson(),
          'destination': {'kind': 'hologram', 'id': 'x'},
        },
        {...routed.toJson(), 'start': 'zero'},
        {...routed.toJson(), 'intent': 'wish'},
        'not a map',
      ],
    });
    expect(back.segments.map((s) => s.destinationId), ['task-1']);
    expect(FrontDispatch.fromJson(const {}).segments, isEmpty);
  });

  test('an integer confidence reads back as a double', () {
    final segment = FrontDispatchSegment.fromJson({
      ...routed.toJson(),
      'confidence': 1,
    });
    expect(segment?.confidence, 1.0);
  });
}
