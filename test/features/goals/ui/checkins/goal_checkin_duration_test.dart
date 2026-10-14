import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/goals/model/goal_timeline_item.dart';
import 'package:lotti/features/goals/ui/checkins/goal_checkin_duration.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';

void main() {
  final start = DateTime(2026, 8, 18, 9);

  JournalEntry note(Duration spent) => JournalEntry(
    meta: Metadata(
      id: 'note-1',
      createdAt: start,
      updatedAt: start,
      dateFrom: start,
      dateTo: start.add(spent),
    ),
    entryText: const EntryText(plainText: 'Walked after lunch.'),
  );

  group('goalCheckInDurationLabel', () {
    testWidgets('reads minutes, a few seconds, and nothing at all', (
      tester,
    ) async {
      late BuildContext context;
      await tester.pumpWidget(
        makeTestableWidget(
          Builder(
            builder: (c) {
              context = c;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(goalCheckInDurationLabel(context, Duration.zero), isNull);
      expect(
        goalCheckInDurationLabel(context, const Duration(seconds: 40)),
        '< 1 min',
      );
      expect(
        goalCheckInDurationLabel(context, const Duration(minutes: 3)),
        '3 min',
      );
      // Minutes only, even past the hour: a reflection is not a timesheet.
      expect(
        goalCheckInDurationLabel(context, const Duration(minutes: 75)),
        '75 min',
      );
    });
  });

  group('GoalCheckInTimeChip', () {
    Future<List<(JournalEntity, Duration)>> tapChip(
      WidgetTester tester, {
      required Duration spent,
      required Duration? picked,
    }) async {
      final writes = <(JournalEntity, Duration)>[];
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          GoalCheckInTimeChip(
            checkIn: GoalTextCheckIn(note(spent)),
            pickDuration: ({required context, required initialDuration}) async {
              expect(initialDuration, spent);
              return picked;
            },
            writeTime: (entity, timeSpent) async {
              writes.add((entity, timeSpent));
              return true;
            },
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('goal-checkin-time-note-1')));
      await tester.pump();
      return writes;
    }

    testWidgets('shows the time the check-in counts for', (tester) async {
      await tapChip(tester, spent: const Duration(minutes: 3), picked: null);
      expect(find.text('3 min'), findsOneWidget);
    });

    testWidgets('a check-in with no time offers to add some', (tester) async {
      await tapChip(tester, spent: Duration.zero, picked: null);
      expect(find.text('Add time'), findsOneWidget);
    });

    testWidgets('a corrected time is written to the entry', (tester) async {
      final writes = await tapChip(
        tester,
        spent: const Duration(minutes: 1),
        picked: const Duration(minutes: 5),
      );
      expect(writes, hasLength(1));
      expect(writes.single.$1.meta.id, 'note-1');
      expect(writes.single.$2, const Duration(minutes: 5));
    });

    testWidgets('backing out, or keeping the same time, writes nothing', (
      tester,
    ) async {
      expect(
        await tapChip(tester, spent: const Duration(minutes: 3), picked: null),
        isEmpty,
      );
      expect(
        await tapChip(
          tester,
          spent: const Duration(minutes: 3),
          picked: const Duration(minutes: 3),
        ),
        isEmpty,
      );
    });
  });

  group('writeGoalCheckInTime', () {
    setUpAll(() => registerFallbackValue(DateTime(2026)));

    test('keeps the start and ends the entry the chosen time later', () async {
      final repository = MockJournalRepository();
      when(
        () => repository.updateJournalEntityDate(
          any(),
          dateFrom: any(named: 'dateFrom'),
          dateTo: any(named: 'dateTo'),
        ),
      ).thenAnswer((_) async => true);

      final stored = await writeGoalCheckInTime(
        repository,
        note(const Duration(minutes: 1)),
        const Duration(minutes: 5),
      );

      expect(stored, isTrue);
      verify(
        () => repository.updateJournalEntityDate(
          'note-1',
          dateFrom: start,
          dateTo: start.add(const Duration(minutes: 5)),
        ),
      ).called(1);
    });
  });

  group('showGoalCheckInDurationPicker', () {
    testWidgets('a quick pick resolves to that length', (tester) async {
      Duration? result;
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          Builder(
            builder: (context) => TextButton(
              onPressed: () async =>
                  result = await showGoalCheckInDurationPicker(
                    context: context,
                    initialDuration: const Duration(minutes: 1),
                  ),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      final context = tester.element(find.text('open'));
      expect(
        find.text(context.messages.goalCheckInTimeSpentTitle),
        findsWidgets,
      );
      await tester.tap(
        find.byKey(const ValueKey('goal-checkin-time-pick-5')),
      );
      await tester.pumpAndSettle();

      expect(result, const Duration(minutes: 5));
    });
  });
}
