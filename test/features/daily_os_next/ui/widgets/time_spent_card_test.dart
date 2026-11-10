import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_models.dart';
import 'package:lotti/features/daily_os_next/ui/category_color.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/live_task_metadata.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/time_spent_card.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/nav_service.dart' show beamToNamedOverride;
import 'package:material_ui/material_ui.dart';

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
        expect(find.byIcon(LottiIcons.confirm), findsOneWidget);
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

    testWidgets("the folded earlier sessions are the card's first row", (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          TimeSpentCard(
            blocks: [
              _session(id: 's1', title: 'Early', startHour: 7),
              _session(id: 's2', title: 'Late', startHour: 15),
            ],
            maxRows: 1,
          ),
        ),
      );

      final fold = tester.getRect(
        find.byKey(const Key('daily_os_time_spent_expander')),
      );
      final late = tester.getRect(find.text('Late'));
      expect(fold.bottom, lessThanOrEqualTo(late.top));
      // It starts at the first folded session's time.
      expect(
        find.descendant(
          of: find.byKey(const Key('daily_os_time_spent_expander')),
          matching: find.text('7:00 AM'),
        ),
        findsOneWidget,
      );
    });

    testWidgets(
      "a session's dot wears its task's live category, as its timeline "
      'block does',
      (tester) async {
        await setUpTestGetIt();
        addTearDown(tearDownTestGetIt);
        final start = DateTime(2026, 5, 26, 9);
        await tester.pumpWidget(
          makeTestableWidget2(
            Material(
              child: TimeSpentCard(
                blocks: [
                  TimeBlock(
                    id: 'moved',
                    title: 'Moved',
                    start: start,
                    end: start.add(const Duration(hours: 1)),
                    type: TimeBlockType.manual,
                    state: TimeBlockState.inProgress,
                    category: _category,
                    taskId: 'task-moved',
                  ),
                ],
              ),
            ),
            mediaQueryData: const MediaQueryData(size: Size(1280, 900)),
            overrides: [
              liveTaskMetadataProvider.overrideWith(
                (ref, taskId) async => const LiveTaskMetadata(
                  title: 'Moved and renamed',
                  categoryId: 'ops',
                  categoryName: 'Operations',
                  categoryColorHex: '#00AA88',
                ),
              ),
            ],
          ),
        );
        await tester.pump();

        final dot = tester.widget<DecoratedBox>(
          find.descendant(
            of: find.byType(TimeSpentCard),
            matching: find.byWidgetPredicate(
              (w) =>
                  w is DecoratedBox &&
                  w.decoration is BoxDecoration &&
                  (w.decoration as BoxDecoration).shape == BoxShape.circle,
            ),
          ),
        );
        expect(
          (dot.decoration as BoxDecoration).color,
          categoryColorFromHex('#00AA88'),
        );
        // Named as the task is now, as its agenda row and block are.
        expect(find.text('Moved and renamed'), findsOneWidget);
        expect(find.text('Moved'), findsNothing);
        // The dot names its category.
        expect(
          find.byWidgetPredicate(
            (w) => w is Tooltip && w.message == 'Operations',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      "the session under way carries the agenda's Now and teal edge",
      (tester) async {
        final start = DateTime(2026, 5, 26, 9);
        await tester.pumpWidget(
          _wrap(
            TimeSpentCard(
              blocks: [
                TimeBlock(
                  id: 'running',
                  title: 'Running',
                  start: start,
                  end: start.add(const Duration(minutes: 30)),
                  type: TimeBlockType.manual,
                  state: TimeBlockState.inProgress,
                  category: _category,
                ),
                _session(id: 'done', title: 'Done', startHour: 7, done: true),
              ],
            ),
          ),
        );
        final messages = tester.element(find.byType(TimeSpentCard)).messages;

        expect(find.text(messages.dailyOsNextAgendaNow), findsOneWidget);
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('running')),
            matching: find.byKey(const Key('day_row_active_edge')),
          ),
          findsOneWidget,
        );
        expect(find.byKey(const Key('day_row_active_edge')), findsOneWidget);
      },
    );

    testWidgets(
      "a done session wears the check in the time's ink, and every row "
      'keeps its length',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            TimeSpentCard(
              blocks: [
                _session(
                  id: 'done',
                  title: 'Done',
                  startHour: 7,
                  durationMinutes: 50,
                  done: true,
                ),
              ],
            ),
          ),
        );
        final tokens = tester.element(find.byType(TimeSpentCard)).designTokens;

        expect(
          tester.widget<Icon>(find.byIcon(LottiIcons.confirm)).color,
          tokens.colors.text.mediumEmphasis,
        );
        expect(find.text('50m'), findsOneWidget);
      },
    );

    testWidgets('an unfinished session shows its length, a done one a check', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          TimeSpentCard(
            blocks: [
              _session(
                id: 'open',
                title: 'Open',
                startHour: 8,
                durationMinutes: 45,
              ),
              _session(id: 'done', title: 'Done', startHour: 10, done: true),
            ],
          ),
        ),
      );

      expect(find.text('45m'), findsOneWidget);
      expect(find.byIcon(LottiIcons.confirm), findsOneWidget);
    });

    testWidgets('a session with a task opens it; one without has no chevron', (
      tester,
    ) async {
      final routes = <String>[];
      beamToNamedOverride = routes.add;
      addTearDown(() => beamToNamedOverride = null);
      await tester.pumpWidget(
        _wrap(
          TimeSpentCard(
            blocks: [
              _session(id: 'loose', title: 'Loose', startHour: 8),
              _session(
                id: 'linked',
                title: 'Linked',
                startHour: 10,
                done: true,
              ),
            ],
          ),
        ),
      );

      expect(find.byIcon(LottiIcons.chevronRight), findsOneWidget);
      await tester.tap(find.text('Loose'));
      expect(routes, isEmpty);

      await tester.tap(find.text('Linked'));
      expect(routes, ['/tasks/task-linked']);
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
