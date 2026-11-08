import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/front_agent/model/front_dispatch.dart';
import 'package:lotti/features/front_agent/workflow/front_dispatch_validator.dart';

void main() {
  const input = 'Buy the hose for the garden. Ask Pip about Friday.';
  //             0         1         2         3         4
  //             012345678901234567890123456789012345678901234567890
  const gardenSpan = (0, 28);
  const pipSpan = (29, 50);

  bool exists(FrontDestinationKind kind, String id) =>
      (kind == FrontDestinationKind.task && id == 'garden') ||
      (kind == FrontDestinationKind.person && id == 'pip');

  Map<String, dynamic> segment({
    required (int, int) span,
    String? text,
    String intent = 'instruction',
    String kind = 'task',
    String? id = 'garden',
    String? newKind,
    Object? confidence = 0.9,
    String? note,
  }) => {
    'start': span.$1,
    'end': span.$2,
    'text': text ?? input.substring(span.$1, span.$2),
    'intent': intent,
    'destination': {'kind': kind, 'id': ?id, 'newKind': ?newKind},
    'confidence': confidence,
    'note': ?note,
  };

  FrontDispatchValidation validate(List<Object?> segments) =>
      validateFrontDispatch(
        args: {'segments': segments},
        input: input,
        destinationExists: exists,
      );

  test('a well-formed two-segment dispatch is accepted as given', () {
    final result = validate([
      segment(span: gardenSpan, note: ' Filed. '),
      segment(span: pipSpan, intent: 'question', kind: 'person', id: 'pip'),
    ]);
    expect(result.error, isNull);
    final segments = result.dispatch!.segments;
    expect(segments.map((s) => s.destinationId), ['garden', 'pip']);
    expect(segments.first.note, 'Filed.');
    expect(segments.first.text, 'Buy the hose for the garden.');
    expect(segments[1].intent, FrontSegmentIntent.question);
  });

  group('a new task', () {
    Map<String, dynamic> newTask(String newKind) => {
      ...segment(span: gardenSpan, kind: 'new', id: null, newKind: newKind),
      'task': {
        'title': 'Buy the hose',
        'categoryId': 'home',
        'priority': 'P1',
        'followsUpTaskId': 'roses',
      },
    };

    test('keeps the task the words describe, its category and the task it '
        'follows only when the checks know them', () {
      final known = validateFrontDispatch(
        args: {
          'segments': [newTask('task')],
        },
        input: input.substring(0, 28),
        destinationExists: exists,
        categoryExists: (id) => id == 'home',
        followUpExists: (id) => id == 'roses',
      ).dispatch!.segments.single.task!;
      expect(known.title, 'Buy the hose');
      expect(known.categoryId, 'home');
      expect(known.followsUpTaskId, 'roses');

      final unchecked = validate([
        newTask('task'),
        segment(span: pipSpan, intent: 'question', kind: 'person', id: 'pip'),
      ]).dispatch!.segments.first.task!;
      expect(unchecked.categoryId, isNull);
      expect(unchecked.followsUpTaskId, isNull);
      expect(unchecked.title, 'Buy the hose');
    });

    test('reads a task object only for a new task', () {
      final segments = validate([
        newTask('goal'),
        segment(span: pipSpan, intent: 'question', kind: 'person', id: 'pip'),
      ]).dispatch!.segments;
      expect(segments.first.newKind, FrontNewKind.goal);
      expect(segments.first.task, isNull);
    });
  });

  group('shape', () {
    test('rejects a missing or empty segments array', () {
      expect(validate([]).error, contains('non-empty segments'));
      expect(
        validateFrontDispatch(
          args: const {},
          input: input,
          destinationExists: exists,
        ).error,
        contains('non-empty segments'),
      );
    });

    test('rejects more than the maximum number of segments', () {
      final many = [
        for (var i = 0; i < frontMaxSegments + 1; i++)
          segment(span: (i, i + 1)),
      ];
      expect(validate(many).error, contains('at most $frontMaxSegments'));
    });

    test('rejects a segment that is not an object', () {
      expect(validate(['text']).error, contains('segment 0 is not an object'));
    });

    test('rejects non-integer offsets when the text is not in the message', () {
      final bad = segment(span: gardenSpan, text: 'Buy a hose')
        ..['start'] = '0';
      expect(validate([bad]).error, contains('integer start and end'));
    });
  });

  group('spans', () {
    test('must be ordered and may not overlap', () {
      final result = validate([
        segment(span: pipSpan, kind: 'person', id: 'pip'),
        segment(span: gardenSpan),
      ]);
      expect(result.error, contains('after the previous segment'));
      final overlapping = validate([
        segment(span: (0, 30)),
        segment(span: (29, 50), kind: 'person', id: 'pip'),
      ]);
      expect(overlapping.error, contains('must not overlap'));
    });

    test('must lie inside the input and be non-empty', () {
      expect(validate([segment(span: (0, 0))]).error, contains('inside'));
      expect(
        validate([segment(span: (40, 99), text: 'Saturday.')]).error,
        contains('inside'),
      );
    });

    test('text must equal the input slice verbatim', () {
      final result = validate([segment(span: gardenSpan, text: 'Buy a hose')]);
      expect(result.error, contains('verbatim'));
      expect(result.error, contains('"Buy the hose for the garden."'));
    });

    test('a repeated phrase cannot stand in for skipped words', () {
      // The same span twice: the second must start after the first ends.
      final result = validate([
        segment(span: gardenSpan),
        segment(span: gardenSpan),
      ]);
      expect(result.dispatch, isNull);
      expect(result.error, contains('segment 1'));
    });
  });

  group('miscounted offsets, verbatim words', () {
    (int, int) placed(FrontDispatchValidation result, int i) => (
      result.dispatch!.segments[i].start,
      result.dispatch!.segments[i].end,
    );

    test('a span ending short of the words is placed by them', () {
      // As Mistral Large 4 did: a 63-character message given as [0, 54).
      final result = validate([
        segment(span: (0, 20), text: 'Buy the hose for the garden.'),
      ]);
      expect(result.error, isNull);
      expect(placed(result, 0), gardenSpan);
    });

    test('a span running past the message is placed by its words', () {
      // And then as [0, 64): one past the end.
      final result = validate([
        segment(span: gardenSpan),
        segment(
          span: (29, 51),
          text: 'Ask Pip about Friday.',
          kind: 'person',
          id: 'pip',
        ),
      ]);
      expect(result.error, isNull);
      expect(placed(result, 1), pipSpan);
    });

    test('words with no offsets at all are placed by them', () {
      final bare = segment(span: gardenSpan)
        ..remove('start')
        ..remove('end');
      final result = validate([bare]);
      expect(result.error, isNull);
      expect(placed(result, 0), gardenSpan);
    });

    test('offsets that agree with the words are kept, so a phrase said '
        'twice is the one the model meant', () {
      const twice = 'Call mom. Call mom.';
      final result = validateFrontDispatch(
        args: {
          'segments': [
            {
              'start': 10,
              'end': 19,
              'text': 'Call mom.',
              'intent': 'instruction',
              'destination': {'kind': 'task', 'id': 'garden'},
              'confidence': 0.9,
            },
          ],
        },
        input: twice,
        destinationExists: exists,
      );
      expect(result.error, isNull);
      final routed = result.dispatch!.segments.firstWhere(
        (s) => s.destinationId == 'garden',
      );
      expect((routed.start, routed.end), (10, 19));
    });

    test('words placed by their text still leave nothing dropped: the '
        'skipped part becomes its own unrouted segment', () {
      final result = validate([
        segment(
          span: (40, 60),
          text: 'Ask Pip about Friday.',
          kind: 'person',
          id: 'pip',
        ),
      ]);
      expect(result.error, isNull);
      final texts = result.dispatch!.segments
          .map((s) => s.text.trim())
          .toList();
      expect(texts, contains('Buy the hose for the garden.'));
      expect(texts, contains('Ask Pip about Friday.'));
    });
  });

  group('destinations', () {
    test('an owner kind needs an id that exists', () {
      expect(
        validate([segment(span: gardenSpan, id: null)]).error,
        contains('needs an id'),
      );
      final unknown = validate([segment(span: gardenSpan, id: 'nope')]);
      expect(unknown.error, contains('task:nope'));
      expect(unknown.error, contains('not in <routing_index>'));
    });

    test('a routed destination below the floor is refused', () {
      final result = validate([segment(span: gardenSpan, confidence: 0.49)]);
      expect(result.error, contains('below $frontLowConfidence'));
      expect(
        validate([segment(span: gardenSpan, confidence: 0.5)]).error,
        isNull,
      );
    });

    test('confidence must be a number in 0..1', () {
      expect(
        validate([segment(span: gardenSpan, confidence: 'high')]).error,
        contains('confidence'),
      );
      expect(
        validate([segment(span: gardenSpan, confidence: 1.5)]).error,
        contains('confidence'),
      );
    });

    test('unknown kinds and intents are refused by name', () {
      expect(
        validate([segment(span: gardenSpan, kind: 'hologram')]).error,
        contains('destination.kind'),
      );
      final notAnObject = segment(span: gardenSpan)..['destination'] = 'task';
      expect(validate([notAnObject]).error, contains('destination.kind'));
      final blankNote = validate([
        segment(span: gardenSpan)..['note'] = '   ',
      ]);
      expect(blankNote.dispatch!.segments.first.note, isNull);
      expect(
        validate([segment(span: gardenSpan, intent: 'wish')]).error,
        contains('intent'),
      );
    });

    test('"new" needs a newKind and carries no id', () {
      expect(
        validate([segment(span: gardenSpan, kind: 'new', id: null)]).error,
        contains('newKind'),
      );
      final ok = validate([
        segment(
          span: gardenSpan,
          kind: 'new',
          id: null,
          newKind: 'task',
          confidence: 0.2,
        ),
      ]);
      expect(ok.error, isNull);
      expect(ok.dispatch!.segments.first.newKind, FrontNewKind.task);
      expect(ok.dispatch!.segments.first.destinationId, isNull);
    });

    test('day, journal and unrouted need no id and no floor', () {
      for (final kind in ['day', 'journal', 'unrouted']) {
        final ok = validate([
          segment(span: gardenSpan, kind: kind, id: null, confidence: 0),
        ]);
        expect(ok.error, isNull, reason: kind);
      }
    });
  });

  group('coverage', () {
    test('a large gap between spans becomes an unrouted segment', () {
      // Only the person half is dispatched; the garden half (more than a
      // fifth of the input) is kept as unrouted, in position.
      final result = validate([
        segment(span: pipSpan, intent: 'question', kind: 'person', id: 'pip'),
      ]);
      final segments = result.dispatch!.segments;
      expect(segments, hasLength(2));
      expect(segments.first.kind, FrontDestinationKind.unrouted);
      expect(segments.first.text, 'Buy the hose for the garden. ');
      expect(segments.first.confidence, 0);
      expect(segments[1].destinationId, 'pip');
    });

    test('a trailing gap becomes an unrouted segment too', () {
      final result = validate([segment(span: gardenSpan)]);
      final segments = result.dispatch!.segments;
      expect(segments.map((s) => s.kind), [
        FrontDestinationKind.task,
        FrontDestinationKind.unrouted,
      ]);
      expect(segments[1].text, ' Ask Pip about Friday.');
    });

    test('several small gaps that together reach the share are each kept, '
        'punctuation-only gaps aside', () {
      // "Buy the hose" | " for " dropped | "the garden" | ". " dropped |
      // "Ask Pip about" | " Friday." dropped — no gap reaches 20 % alone,
      // together they do.
      final result = validate([
        segment(span: (0, 12)),
        segment(span: (17, 27)),
        segment(span: (29, 42), intent: 'question', kind: 'person', id: 'pip'),
      ]);
      final segments = result.dispatch!.segments;
      expect(segments.map((s) => (s.kind, s.text)), [
        (FrontDestinationKind.task, 'Buy the hose'),
        (FrontDestinationKind.unrouted, ' for '),
        (FrontDestinationKind.task, 'the garden'),
        // ". " holds no word and is absorbed even now.
        (FrontDestinationKind.person, 'Ask Pip about'),
        (FrontDestinationKind.unrouted, ' Friday.'),
      ]);
    });

    test('a small gap — punctuation, a word — is absorbed', () {
      final result = validate([
        segment(span: (0, 27)), // drops the full stop
        segment(span: pipSpan, intent: 'question', kind: 'person', id: 'pip'),
      ]);
      expect(result.dispatch!.segments, hasLength(2));
    });

    test('whitespace-only input has nothing to cover', () {
      final result = validateFrontDispatch(
        args: {
          'segments': [
            {
              'start': 0,
              'end': 1,
              'text': ' ',
              'intent': 'statement',
              'destination': {'kind': 'unrouted'},
              'confidence': 0,
            },
          ],
        },
        input: '   ',
        destinationExists: exists,
      );
      expect(result.dispatch!.segments, hasLength(1));
    });
  });
}
