import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/classes/check_in_data.dart';
import 'package:lotti/features/relationships/model/check_in_dictation_facts.dart';
import 'package:lotti/features/relationships/model/check_in_dictation_fill.dart';

final _now = DateTime(2026, 3, 15, 16, 30);

final _opening = CheckInContext(
  type: CheckInInteractionType.inPerson,
  start: _now,
  duration: Duration.zero,
);

/// What takes say, from nothing to all three fields at once.
const _phrases = [
  'a video call',
  'we met up',
  'at 10 am',
  'at 3 pm',
  'for 20 minutes',
  'about an hour',
  'she called me at 9 am for 45 minutes',
  'nothing worth noting',
];

/// What a user picks: values no phrase above produces, so a picked value is
/// always told apart from a dictated one.
const CheckInInteractionType _pickedType = CheckInInteractionType.message;
final DateTime _pickedStart = DateTime(2026, 3, 15, 8, 5);
const _pickedDuration = Duration(minutes: 7);

CheckInDictationFill _fill(
  List<String?> words, {
  Set<CheckInContextField> held = const {},
  CheckInContext? current,
}) => fillCheckInContextFromTakes(
  current: current ?? _opening,
  takeWords: words,
  held: held,
  now: _now,
);

/// A composer's life: takes made in order, their words arriving in
/// [arrival] order, and the user picking fields in between.
class _Scenario {
  _Scenario(this.takes, List<int> arrivalKeys, List<int> picks)
    : arrival = [for (var i = 0; i < takes.length; i++) i]
        ..sort(
          (a, b) => arrivalKeys[a % arrivalKeys.length].compareTo(
            arrivalKeys[b % arrivalKeys.length],
          ),
        ),
      // Each pick: which field, and before which arrival (or after the last).
      picks = [
        for (final code in picks)
          (
            field: CheckInContextField.values[code % 3],
            step: (code ~/ 3) % (takes.length + 1),
          ),
      ];

  /// Indexes into [_phrases], in the order the takes were made.
  final List<int> takes;

  /// Take indexes, in the order their words arrive.
  final List<int> arrival;

  final List<({CheckInContextField field, int step})> picks;

  @override
  String toString() =>
      '_Scenario(takes: ${[for (final t in takes) _phrases[t]]}, '
      'arrival: $arrival, picks: $picks)';
}

void main() {
  group('CheckInContext', () {
    test('equals a context with the same fields only, and names them', () {
      final context = CheckInContext(
        type: CheckInInteractionType.call,
        start: DateTime(2026, 3, 15, 9),
        duration: const Duration(minutes: 45),
      );
      final same = CheckInContext(
        type: CheckInInteractionType.call,
        start: DateTime(2026, 3, 15, 9),
        duration: const Duration(minutes: 45),
      );
      expect(context, same);
      expect(context.hashCode, same.hashCode);
      expect(context, isNot(_opening));
      expect(
        context.toString(),
        allOf(contains('call'), contains('09:00'), contains('0:45')),
      );
    });
  });

  group('fillCheckInContextFromTakes', () {
    test('fills every field the words name, and says which', () {
      final fill = _fill(['she called me at 9 am for 45 minutes']);
      expect(
        fill.context,
        CheckInContext(
          type: CheckInInteractionType.call,
          start: DateTime(2026, 3, 15, 9),
          duration: const Duration(minutes: 45),
        ),
      );
      expect(fill.filled, CheckInContextField.values.toSet());
    });

    test('leaves a held field as it was', () {
      final fill = _fill(
        ['she called me at 9 am for 45 minutes'],
        held: {CheckInContextField.type, CheckInContextField.duration},
      );
      expect(fill.context.type, _opening.type);
      expect(fill.context.duration, _opening.duration);
      expect(fill.context.start, DateTime(2026, 3, 15, 9));
      expect(fill.filled, {CheckInContextField.start});
    });

    test('the newest take that names a field wins; a take that does not '
        'name it leaves the older one', () {
      final fill = _fill([
        'for 20 minutes, a video call',
        'about an hour',
        'nothing worth noting',
      ]);
      expect(fill.context.duration, const Duration(hours: 1));
      expect(fill.context.type, CheckInInteractionType.videoCall);
    });

    test('a take still waiting for words reads as nothing', () {
      expect(
        _fill([null, 'for 20 minutes', null]).context.duration,
        const Duration(minutes: 20),
      );
      final none = _fill([null, null]);
      expect(none.context, _opening);
      expect(none.filled, isEmpty);
    });
  });

  glados.Glados3(
    glados.any.listWithLengthInRange(
      1,
      6,
      glados.any.intInRange(0, _phrases.length),
    ),
    glados.any.listWithLengthInRange(1, 6, glados.any.intInRange(0, 1000)),
    glados.any.listWithLengthInRange(0, 6, glados.any.intInRange(0, 18)),
    glados.ExploreConfig(numRuns: 200),
  ).test(
    'whatever order the words arrive in, a picked field keeps its pick and '
    'every other field ends on the newest take that names it',
    (takes, arrivalKeys, pickCodes) {
      final scenario = _Scenario(takes, arrivalKeys, pickCodes);

      // Drive the composer the way the form does: a pick holds its field and
      // takes it out of the dictated set; each arrival re-reads every take.
      var context = _opening;
      final held = <CheckInContextField>{};
      final dictated = <CheckInContextField>{};
      final words = List<String?>.filled(scenario.takes.length, null);

      void pickAt(int step) {
        for (final pick in scenario.picks.where((p) => p.step == step)) {
          context = switch (pick.field) {
            CheckInContextField.type => CheckInContext(
              type: _pickedType,
              start: context.start,
              duration: context.duration,
            ),
            CheckInContextField.start => CheckInContext(
              type: context.type,
              start: _pickedStart,
              duration: context.duration,
            ),
            CheckInContextField.duration => CheckInContext(
              type: context.type,
              start: context.start,
              duration: _pickedDuration,
            ),
          };
          held.add(pick.field);
          dictated.remove(pick.field);
        }
      }

      for (var step = 0; step < scenario.arrival.length; step++) {
        pickAt(step);
        final take = scenario.arrival[step];
        words[take] = _phrases[scenario.takes[take]];
        final fill = fillCheckInContextFromTakes(
          current: context,
          takeWords: words,
          held: held,
          now: _now,
        );
        context = fill.context;
        dictated.addAll(fill.filled);
      }
      pickAt(scenario.arrival.length);

      // The reference: what the newest take naming each field says,
      // read in the order the takes were made.
      final facts = [
        for (final t in scenario.takes)
          extractCheckInDictationFacts(_phrases[t], now: _now),
      ];
      T? newest<T>(T? Function(CheckInDictationFacts) of) =>
          facts.map(of).whereType<T>().lastOrNull;
      final namedType = newest((f) => f.interactionType);
      final namedStart = newest((f) => f.startedAt);
      final namedDuration = newest((f) => f.duration);

      expect(
        context.type,
        held.contains(CheckInContextField.type)
            ? _pickedType
            : namedType ?? _opening.type,
        reason: '$scenario',
      );
      expect(
        context.start,
        held.contains(CheckInContextField.start)
            ? _pickedStart
            : namedStart ?? _opening.start,
        reason: '$scenario',
      );
      expect(
        context.duration,
        held.contains(CheckInContextField.duration)
            ? _pickedDuration
            : namedDuration ?? _opening.duration,
        reason: '$scenario',
      );
      expect(
        dictated,
        {
          if (namedType != null && !held.contains(CheckInContextField.type))
            CheckInContextField.type,
          if (namedStart != null && !held.contains(CheckInContextField.start))
            CheckInContextField.start,
          if (namedDuration != null &&
              !held.contains(CheckInContextField.duration))
            CheckInContextField.duration,
        },
        reason: '$scenario',
      );
    },
    tags: 'glados',
  );
}
