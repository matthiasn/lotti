import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_models.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/time_spent_card.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

import '../../../../widget_test_utils.dart';

const _category = DayAgentCategory(
  id: 'cat_work',
  name: 'Work',
  colorHex: '5ED4B7',
);

TimeBlock _session({
  required String id,
  required String title,
  required int startHour,
  int startMinute = 0,
  int durationMinutes = 60,
  bool done = false,
}) {
  final start = DateTime(2026, 5, 26, startHour, startMinute);
  return TimeBlock(
    id: id,
    title: title,
    start: start,
    end: start.add(Duration(minutes: durationMinutes)),
    type: TimeBlockType.manual,
    state: done ? TimeBlockState.completed : TimeBlockState.inProgress,
    category: _category,
    taskId: done ? 'task-$id' : null,
  );
}

Widget _wrap(Widget child) => makeTestableWidget2(
  Material(child: child),
  mediaQueryData: const MediaQueryData(size: Size(1280, 900)),
);

void main() {
  group('TimeSpentCard', () {
    testWidgets(
      'renders the eyebrow, mono summary, and one row per session with '
      'a check on done sessions',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            TimeSpentCard(
              blocks: [
                _session(
                  id: 's1',
                  title: 'Build framework',
                  startHour: 8,
                  durationMinutes: 90,
                  done: true,
                ),
                _session(
                  id: 's2',
                  title: 'UI improvements',
                  startHour: 10,
                  durationMinutes: 65,
                ),
              ],
            ),
          ),
        );

        final messages = tester.element(find.byType(TimeSpentCard)).messages;
        expect(find.text(messages.dailyOsNextTimeSpentTitle), findsOneWidget);
        // 90 + 65 = 2h 35m, 1 done.
        expect(
          find.text(messages.dailyOsNextTimeSpentSummary('2h 35m', 1)),
          findsOneWidget,
        );
        expect(find.text('Build framework'), findsOneWidget);
        expect(find.text('UI improvements'), findsOneWidget);
        expect(find.byIcon(Icons.check_rounded), findsOneWidget);
      },
    );

    testWidgets('a custom title overrides the "Today so far" eyebrow', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          TimeSpentCard(
            blocks: [_session(id: 's1', title: 'One session', startHour: 8)],
            title: 'TIME SPENT',
          ),
        ),
      );

      final messages = tester.element(find.byType(TimeSpentCard)).messages;
      expect(find.text('TIME SPENT'), findsOneWidget);
      expect(find.text(messages.dailyOsNextTimeSpentTitle), findsNothing);
    });

    testWidgets(
      'collapses to maxRows keeping the most recent sessions; the ghost '
      'expander reveals the earlier ones and toggles back',
      (tester) async {
        final blocks = [
          _session(id: 's1', title: 'Earliest session', startHour: 7),
          _session(id: 's2', title: 'Morning session', startHour: 9),
          _session(id: 's3', title: 'Midday session', startHour: 12),
          _session(id: 's4', title: 'Latest session', startHour: 15),
        ];
        await tester.pumpWidget(
          _wrap(TimeSpentCard(blocks: blocks, maxRows: 2)),
        );

        final messages = tester.element(find.byType(TimeSpentCard)).messages;
        // Most recent two visible; the two earlier collapsed.
        expect(find.text('Midday session'), findsOneWidget);
        expect(find.text('Latest session'), findsOneWidget);
        expect(find.text('Earliest session'), findsNothing);
        expect(find.text('Morning session'), findsNothing);
        expect(
          find.text(messages.dailyOsNextTimeSpentEarlierSessions(2)),
          findsOneWidget,
        );

        await tester.tap(
          find.byKey(const Key('daily_os_time_spent_expander')),
        );
        await tester.pump();

        expect(find.text('Earliest session'), findsOneWidget);
        expect(find.text('Morning session'), findsOneWidget);
        expect(
          find.text(messages.dailyOsNextTimeSpentShowLess),
          findsOneWidget,
        );

        await tester.tap(
          find.byKey(const Key('daily_os_time_spent_expander')),
        );
        await tester.pump();
        expect(find.text('Earliest session'), findsNothing);
      },
    );

    testWidgets('compact mode tightens the horizontal padding', (
      tester,
    ) async {
      EdgeInsetsGeometry paddingFor() => tester
          .widget<Container>(
            find.byKey(const Key('daily_os_time_spent_card')),
          )
          .padding!;

      await tester.pumpWidget(
        _wrap(
          TimeSpentCard(
            blocks: [_session(id: 's1', title: 'Session', startHour: 8)],
            compact: true,
          ),
        ),
      );
      final compactPadding = paddingFor().resolve(TextDirection.ltr);

      await tester.pumpWidget(
        _wrap(
          TimeSpentCard(
            blocks: [_session(id: 's1', title: 'Session', startHour: 8)],
          ),
        ),
      );
      final regularPadding = paddingFor().resolve(TextDirection.ltr);

      expect(compactPadding.left, lessThan(regularPadding.left));
      expect(compactPadding.right, lessThan(regularPadding.right));
    });

    testWidgets('no expander when the sessions fit within maxRows', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          TimeSpentCard(
            blocks: [
              _session(id: 's1', title: 'Only session', startHour: 8),
            ],
            maxRows: 3,
          ),
        ),
      );

      expect(
        find.byKey(const Key('daily_os_time_spent_expander')),
        findsNothing,
      );
    });
  });
}
