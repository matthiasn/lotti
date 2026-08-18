import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/goals/model/goal_checkin_summary.dart';

void main() {
  final recordedAt = DateTime.utc(2026, 8, 18, 14, 20);

  GoalCheckInSummary summary({
    String? committedTo = 'take the long route home',
    String? blockers,
    String? mood,
    String? asks,
  }) => GoalCheckInSummary(
    id: 'goal-1:audio-1',
    sourceEntryId: 'audio-1',
    recordedAt: recordedAt,
    whatHappened: 'Skipped the lunch walk.',
    committedTo: committedTo,
    blockers: blockers,
    mood: mood,
    asks: asks,
  );

  group('round trip', () {
    test('survives content encoding with every slot intact', () {
      final original = summary(
        blockers: 'back-to-back calls',
        mood: 'a bit flat',
        asks: 'remind me at four',
      );

      final restored = GoalCheckInSummary.fromContent(
        original.id,
        original.toContent(),
      );

      expect(restored, isNotNull);
      expect(restored!.sourceEntryId, 'audio-1');
      // The date is what makes a commitment quotable back to the user.
      expect(restored.recordedAt, recordedAt);
      expect(restored.whatHappened, 'Skipped the lunch walk.');
      expect(restored.committedTo, 'take the long route home');
      expect(restored.blockers, 'back-to-back calls');
      expect(restored.mood, 'a bit flat');
      expect(restored.asks, 'remind me at four');
    });

    test('keeps absent slots absent rather than inventing them', () {
      final restored = GoalCheckInSummary.fromContent(
        'id',
        summary(committedTo: null).toContent(),
      );

      expect(restored!.committedTo, isNull);
      expect(restored.blockers, isNull);
    });
  });

  group('decoding a payload that cannot be trusted', () {
    Map<String, Object?> content({
      Object? source = 'audio-1',
      Object? happened = 'Walked.',
      Object? at = '2026-08-18T14:20:00.000Z',
    }) => <String, Object?>{
      'sourceEntryId': source,
      'whatHappened': happened,
      'recordedAt': at,
    };

    test('a payload with no source entry is refused', () {
      // Without it the summary cannot be traced back to the user's own words,
      // which is the whole contract.
      expect(
        GoalCheckInSummary.fromContent('id', content(source: null)),
        isNull,
      );
      expect(GoalCheckInSummary.fromContent('id', content(source: 42)), isNull);
    });

    test('a payload with no record of what happened is refused', () {
      expect(
        GoalCheckInSummary.fromContent('id', content(happened: null)),
        isNull,
      );
    });

    test('an unparseable date is refused rather than defaulted', () {
      // Defaulting would date a commitment to the epoch and let the agent
      // quote it as if the user had just said it.
      expect(
        GoalCheckInSummary.fromContent('id', content(at: 'not a date')),
        isNull,
      );
      expect(GoalCheckInSummary.fromContent('id', content(at: null)), isNull);
    });

    test('a well-formed payload decodes', () {
      expect(GoalCheckInSummary.fromContent('id', content()), isNotNull);
    });
  });
}
