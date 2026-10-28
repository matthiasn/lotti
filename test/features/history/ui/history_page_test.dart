// ignore_for_file: avoid_redundant_argument_values

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/spinners/design_system_spinner.dart';
import 'package:lotti/features/design_system/theme/icon_tokens.dart';
import 'package:lotti/features/history/domain/history_entry.dart';
import 'package:lotti/features/history/state/history_providers.dart';
import 'package:lotti/features/history/ui/history_page.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../../../test_data/test_data.dart';
import '../../../widget_test_utils.dart';
import '../history_test_bench.dart';

/// Today, for every test: visits are stamped relative to it, so the labels
/// never drift with the real date.
final _now = DateTime(2026, 3, 15, 12);

void main() {
  setUpAll(registerAllFallbackValues);

  late HistoryTestBench bench;
  late MockNavService navService;

  setUp(() {
    bench = HistoryTestBench();
    navService = MockNavService();
    when(() => navService.beamToNamed(any())).thenReturn(null);
    when(() => navService.openTask(any())).thenReturn(null);
  });

  tearDown(() => bench.close());

  /// Runs [body] with the clock fixed at [_now]; every build and read inside
  /// sees the same "today".
  void historyTest(String description, WidgetTesterCallback body) {
    testWidgets(
      description,
      (tester) => withClock(Clock.fixed(_now), () => body(tester)),
    );
  }

  /// Pumps a host page and opens the history over it.
  Future<void> openHistory(WidgetTester tester) async {
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () => showHistoryModal(context),
              child: const Text('open'),
            ),
          ),
        ),
        overrides: [
          historyDbProvider.overrideWithValue(bench.db),
          journalDbProvider.overrideWithValue(bench.journalDb),
          navServiceProvider.overrideWithValue(navService),
          domainLoggerProvider.overrideWithValue(MockDomainLogger()),
        ],
      ),
    );
    await tester.tap(find.text('open'));
    await settle(tester);
  }

  historyTest('lists current titles with section and time, newest first', (
    tester,
  ) async {
    bench
      ..putTask('older', 'Write release notes')
      ..putTask('newer', 'Old title');
    await bench.appendTaskVisit('older', DateTime(2026, 3, 1, 15, 45));
    await bench.appendTaskVisit('newer', DateTime(2026, 3, 14, 9, 5));
    // Renamed after the visit: the row shows the name it has now.
    bench.putTask('newer', 'Fix login bug');

    await openHistory(tester);

    expect(find.text('History'), findsOneWidget);
    expect(find.text('Fix login bug'), findsOneWidget);
    expect(find.text('Old title'), findsNothing);
    expect(find.text('Tasks · Yesterday, 9:05 AM'), findsOneWidget);
    expect(find.text('Tasks · Mar 1 3:45 PM'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Fix login bug')).dy,
      lessThan(tester.getTopLeft(find.text('Write release notes')).dy),
    );
  });

  historyTest('opens behind the shared darkened scrim', (tester) async {
    await openHistory(tester);

    final barrier = tester.widget<ModalBarrier>(
      find.byType(ModalBarrier).last,
    );
    final context = tester.element(find.byType(HistoryPage));
    expect(
      barrier.color,
      ModalUtils.getModalBarrierColor(isDark: false, context: context),
    );
  });

  historyTest('the close button closes without navigating', (tester) async {
    await openHistory(tester);

    await tester.tap(find.byKey(const ValueKey('history-close')));
    await settle(tester);

    expect(find.byType(HistoryPage), findsNothing);
    verifyNever(() => navService.beamToNamed(any()));
  });

  historyTest('tapping a row closes the page and opens the entity', (
    tester,
  ) async {
    bench.putTask('t1', 'Fix login bug');
    await bench.appendTaskVisit('t1', DateTime(2026, 3, 15, 9));
    await openHistory(tester);

    await tester.tap(find.text('Fix login bug'));
    await settle(tester);

    expect(find.byType(HistoryPage), findsNothing);
    // A task is opened by its id, never by beaming its route.
    verify(() => navService.openTask('t1')).called(1);
    verifyNever(() => navService.beamToNamed(any()));
  });

  historyTest('any other kind beams to its route', (tester) async {
    bench.entities['p1'] = testTask.copyWith(
      meta: testTask.meta.copyWith(id: 'p1'),
      data: testTask.data.copyWith(title: 'Colony launch'),
    );
    await bench.db.appendEntry(
      kind: HistoryEntityKind.project.name,
      entityId: 'p1',
      route: '/projects/p1',
      visitedAt: DateTime(2026, 3, 15, 9),
    );
    await openHistory(tester);

    await tester.tap(find.text('Colony launch'));
    await settle(tester);

    verify(() => navService.beamToNamed('/projects/p1')).called(1);
    verifyNever(() => navService.openTask(any()));
  });

  historyTest('deleting a row keeps the rows after it in place', (
    tester,
  ) async {
    bench
      ..putTask('a', 'Alpha')
      ..putTask('b', 'Bravo');
    await bench.appendTaskVisit('a', DateTime(2026, 3, 15, 9));
    final bravo = await bench.appendTaskVisit('b', DateTime(2026, 3, 15, 10));
    await openHistory(tester);
    final alphaBefore = tester.element(find.text('Alpha'));

    await tester.tap(find.byKey(ValueKey('history-delete-$bravo')));
    await settle(tester);
    await tester.tap(find.text('Remove'));
    await settle(tester);

    // Alpha moved up one index and kept its element.
    expect(find.text('Bravo'), findsNothing);
    expect(identical(tester.element(find.text('Alpha')), alphaBefore), isTrue);
  });

  historyTest('untitled and deleted entities get placeholders', (
    tester,
  ) async {
    bench.putTask('untitled', '');
    await bench.appendTaskVisit('untitled', DateTime(2026, 3, 15, 9));
    await bench.appendTaskVisit('deleted', DateTime(2026, 3, 15, 10));
    await openHistory(tester);

    expect(find.text('Untitled'), findsOneWidget);
    expect(find.text('No longer available'), findsOneWidget);

    // A deleted entity has nowhere to go back to.
    await tester.tap(find.text('No longer available'));
    await settle(tester);
    expect(find.byType(HistoryPage), findsOneWidget);
    verifyNever(() => navService.beamToNamed(any()));
  });

  historyTest('search filters by the current title', (tester) async {
    bench
      ..putTask('a', 'Bug fix for login')
      ..putTask('b', 'Write docs');
    await bench.appendTaskVisit('a', DateTime(2026, 3, 15, 9));
    await bench.appendTaskVisit('b', DateTime(2026, 3, 15, 10));
    await openHistory(tester);

    await tester.enterText(find.byType(TextField), 'bug fix');
    await settle(tester);

    expect(find.text('Bug fix for login'), findsOneWidget);
    expect(find.text('Write docs'), findsNothing);

    await tester.enterText(find.byType(TextField), 'nothing like it');
    await settle(tester);
    expect(find.text('No matches'), findsOneWidget);
  });

  historyTest('an empty history says what it will hold', (tester) async {
    await openHistory(tester);

    expect(find.text('Nothing here yet'), findsOneWidget);
    expect(
      find.text('Tasks, entries and projects you open show up here.'),
      findsOneWidget,
    );
  });

  historyTest('a time range hides older visits', (tester) async {
    bench
      ..putTask('old', 'Old task')
      ..putTask('new', 'New task');
    await bench.appendTaskVisit('old', DateTime(2026, 2, 1));
    await bench.appendTaskVisit('new', DateTime(2026, 3, 14));
    await openHistory(tester);
    expect(find.text('Old task'), findsOneWidget);

    await tester.tap(find.text('7 days').last);
    await settle(tester);

    expect(find.text('New task'), findsOneWidget);
    expect(find.text('Old task'), findsNothing);
  });

  historyTest('a custom range is picked as two dates and shown', (
    tester,
  ) async {
    await openHistory(tester);

    await tester.tap(find.text('Custom').last);
    await settle(tester);
    expect(find.text('Start date'), findsOneWidget);
    await tester.tap(find.text('Done'));
    await settle(tester);
    expect(find.text('End date'), findsOneWidget);
    await tester.tap(find.text('Done'));
    await settle(tester);

    // Start defaults to a week back, end to today.
    expect(find.text('Mar 9, 2026 – Mar 15, 2026'), findsOneWidget);
  });

  historyTest('dismissing the custom range picker keeps the range', (
    tester,
  ) async {
    bench.putTask('old', 'Old task');
    await bench.appendTaskVisit('old', DateTime(2025, 1, 1));
    await openHistory(tester);

    await tester.tap(find.text('Custom').last);
    await settle(tester);
    await tester.tapAt(const Offset(5, 5));
    await settle(tester);

    expect(find.text('Start date'), findsNothing);
    expect(find.byKey(const ValueKey('history-custom-range')), findsNothing);
    expect(find.text('Old task'), findsOneWidget);
  });

  historyTest('delete asks first, then removes the visit for good', (
    tester,
  ) async {
    bench.putTask('t1', 'Fix login bug');
    final id = await bench.appendTaskVisit('t1', DateTime(2026, 3, 15, 9));
    await openHistory(tester);

    await tester.tap(find.byKey(ValueKey('history-delete-$id')));
    await settle(tester);
    expect(find.text('Remove from history?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await settle(tester);
    expect(find.text('Fix login bug'), findsOneWidget);
    expect(await bench.db.entriesPage(limit: 10), hasLength(1));

    await tester.tap(find.byKey(ValueKey('history-delete-$id')));
    await settle(tester);
    await tester.tap(find.text('Remove'));
    await settle(tester);

    expect(find.text('Fix login bug'), findsNothing);
    expect(await bench.db.entriesPage(limit: 10), isEmpty);
  });

  historyTest('every kind shows its section', (tester) async {
    // Tall enough that all seven rows are built at once.
    tester.view
      ..physicalSize = const Size(1000, 1600)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    for (final (index, kind) in HistoryEntityKind.values.indexed) {
      final id = 'k$index';
      // A task stands in for every journal kind; definitions have their own.
      bench.putTask(id, 'Item ${kind.name}');
      if (kind == HistoryEntityKind.dashboard) {
        bench.dashboards[id] = testDashboardConfig.copyWith(
          name: 'Item ${kind.name}',
        );
      }
      if (kind == HistoryEntityKind.habit) {
        bench.habits[id] = habitFlossing.copyWith(name: 'Item ${kind.name}');
      }
      await bench.db.appendEntry(
        kind: kind.name,
        entityId: id,
        route: '/x/$id',
        visitedAt: DateTime(2026, 3, 15, 9, index),
      );
    }
    await openHistory(tester);

    for (final section in [
      'Tasks',
      'Logbook',
      'Projects',
      'Events',
      'People',
      'Insights',
      'Habits',
    ]) {
      expect(find.textContaining('$section · Today'), findsOneWidget);
    }
  });

  historyTest('a failed read says so', (tester) async {
    when(
      () => bench.journalDb.getJournalEntitiesForIds(any()),
    ).thenThrow(StateError('broken'));
    await bench.appendTaskVisit('t', DateTime(2026, 3, 15, 9));
    await openHistory(tester);

    expect(find.text("Couldn't load your history."), findsOneWidget);
  });

  historyTest('clearing the search lists everything again', (tester) async {
    bench
      ..putTask('a', 'Bug fix')
      ..putTask('b', 'Write docs');
    await bench.appendTaskVisit('a', DateTime(2026, 3, 15, 9));
    await bench.appendTaskVisit('b', DateTime(2026, 3, 15, 10));
    await openHistory(tester);
    await tester.enterText(find.byType(TextField), 'bug');
    await settle(tester);
    expect(find.text('Write docs'), findsNothing);

    await tester.tap(find.byIcon(LottiIcons.closeCircled));
    await settle(tester);

    expect(find.text('Write docs'), findsOneWidget);
    expect(find.text('Bug fix'), findsOneWidget);
  });

  historyTest('the custom range label reopens the pickers', (tester) async {
    await openHistory(tester);
    Future<void> pickBoth() async {
      for (var i = 0; i < 2; i++) {
        await tester.tap(find.text('Done'));
        await settle(tester);
      }
    }

    await tester.tap(find.text('Custom').last);
    await settle(tester);
    await pickBoth();
    await tester.tap(find.byKey(const ValueKey('history-custom-range')));
    await settle(tester);

    expect(find.text('Start date'), findsOneWidget);
    await pickBoth();
    expect(find.text('Mar 9, 2026 – Mar 15, 2026'), findsOneWidget);
  });

  historyTest('a failed next page is not retried every frame', (
    tester,
  ) async {
    for (var i = 0; i < 25; i++) {
      bench.putTask('t$i', 'Task $i');
      await bench.appendTaskVisit('t$i', DateTime(2026, 3, 15, 0, i));
    }
    await openHistory(tester);
    var reads = 0;
    when(() => bench.journalDb.getJournalEntitiesForIds(any())).thenAnswer((
      _,
    ) async {
      reads++;
      throw StateError('broken');
    });

    await tester.drag(find.byType(Scrollable).last, const Offset(0, -3000));
    await settle(tester);
    await settle(tester);

    expect(reads, 1);
    expect(find.byType(DesignSystemSpinner), findsNothing);
    expect(find.text('Task 24'), findsNothing); // scrolled past the top
    expect(find.text('Task 5'), findsOneWidget);
  });

  historyTest('scrolling down loads the next page', (tester) async {
    for (var i = 0; i < 30; i++) {
      bench.putTask('t$i', 'Task $i');
      await bench.appendTaskVisit('t$i', DateTime(2026, 3, 15, 0, i));
    }
    await openHistory(tester);
    expect(find.text('Task 0'), findsNothing);

    await tester.scrollUntilVisible(
      find.text('Task 0'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await settle(tester);

    expect(find.text('Task 0'), findsOneWidget);
  });
}

/// Lets the database reads, the dialog transition and the rebuilds land.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}
