import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/history/state/history_recorder.dart';
import 'package:lotti/features/history/state/history_service.dart';
import 'package:lotti/services/logging_domains.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../history_test_bench.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(registerAllFallbackValues);

  late HistoryTestBench bench;
  late HistoryNavFixture fixture;
  late MockDomainLogger logger;
  late HistoryRecorder recorder;

  setUp(() {
    bench = HistoryTestBench();
    fixture = HistoryNavFixture();
    logger = MockDomainLogger();
    recorder = HistoryRecorder(
      navService: fixture.nav,
      service: bench.service,
      logger: logger,
    )..start();
  });

  tearDown(() async {
    await recorder.dispose();
    await fixture.dispose();
    await bench.close();
  });

  /// The visits recorded so far, oldest first, as `kind:id route`.
  Future<List<String>> recorded() async {
    await pumpEventQueue();
    final rows = await bench.db.entriesPage(limit: 100);
    return [
      for (final row in rows.reversed)
        '${row.kind}:${row.entityId} ${row.route}',
    ];
  }

  test('a route change in the front tab is recorded', () async {
    fixture.tasks.beamToNamed('/tasks/t1');
    fixture.tasks.beamToNamed('/tasks');
    fixture.tasks.beamToNamed('/tasks/t2');

    expect(await recorded(), ['task:t1 /tasks/t1', 'task:t2 /tasks/t2']);
  });

  test('a background tab moving on its own is not', () async {
    fixture.journal.beamToNamed('/journal/e1');
    expect(await recorded(), isEmpty);
  });

  test('bringing a tab to the front records the entity it shows', () async {
    fixture.journal.beamToNamed('/journal/e1');
    fixture.selectTab(1);
    expect(await recorded(), ['entry:e1 /journal/e1']);
  });

  test('a tab index out of range is ignored', () async {
    fixture.selectTab(9);
    expect(await recorded(), isEmpty);
  });

  test('a linked task pushed on desktop is recorded by its id', () async {
    fixture.desktop = true;
    fixture.taskStack.value = ['base'];
    // Pushed above base: the URL stays at /tasks/base.
    fixture.taskStack.value = ['base', 'linked'];
    fixture.taskStack.value = const [];
    expect(await recorded(), [
      'task:base /tasks/base',
      'task:linked /tasks/linked',
    ]);
  });

  test('the task stack means nothing on the phone', () async {
    fixture.taskStack.value = ['x'];
    expect(await recorded(), isEmpty);
  });

  test('a stack change while Tasks is in the background is not a '
      'visit', () async {
    fixture
      ..desktop = true
      ..selectTab(1);
    fixture.taskStack.value = ['z'];
    expect(await recorded(), isEmpty);
  });

  test('an open from another tab is recorded, even of the task already '
      'shown', () async {
    fixture.desktop = true;
    fixture.taskStack.value = ['A'];
    fixture.journal.beamToNamed('/journal/e1');
    fixture.selectTab(1);
    // The Logbook visit lands before the user opens anything else, as it
    // does in the app, where the index stream delivers asynchronously.
    await pumpEventQueue();

    // NavService.openTask: the tab comes forward, then the stack becomes
    // a new [A] even though it already held A.
    fixture.selectTab(0);
    fixture.taskStack.value = ['A'];

    expect(await recorded(), [
      'task:A /tasks/A',
      'entry:e1 /journal/e1',
      'task:A /tasks/A',
    ]);
  });

  test('a desktop selection in a background tab is not', () async {
    fixture.selectedProject.value = 'p1';
    fixture.selectTab(2);
    fixture.selectedProject.value = 'p2';
    // Tab 2 shows the projects list on its route; only the selection made
    // while it was in front counts.
    expect(await recorded(), ['project:p2 /projects/p2']);
  });

  test('every desktop selection maps to its entity route', () async {
    final cases = <(int, ValueNotifier<String?>, String)>[
      (1, fixture.selectedEntry, 'entry:x1 /journal/x1'),
      (2, fixture.selectedProject, 'project:x2 /projects/x2'),
      (3, fixture.selectedPerson, 'person:x3 /people/x3'),
      (4, fixture.selectedDashboard, 'dashboard:x4 /dashboards/x4'),
    ];
    for (final (tab, selection, _) in cases) {
      fixture.selectTab(tab);
      selection.value = 'x$tab';
    }
    expect(await recorded(), [for (final (_, _, row) in cases) row]);
  });

  test('on desktop the tasks tab goes by the task in view, never the '
      'route', () async {
    fixture.desktop = true;
    // The URL alone records nothing: the stack follows it.
    fixture.tasks.beamToNamed('/tasks/A');
    expect(await recorded(), isEmpty);

    fixture.taskStack.value = ['A'];
    // A linked task replaces A in the pane; the URL stays at /tasks/A.
    fixture.taskStack.value = ['A', 'B'];
    fixture.journal.beamToNamed('/journal/e1');
    fixture
      ..selectTab(1)
      ..selectTab(0);

    expect(await recorded(), [
      'task:A /tasks/A',
      'task:B /tasks/B',
      'entry:e1 /journal/e1',
      // Switching back to the tab is not a visit, as in a browser.
    ]);
  });

  test('a beam into the desktop tasks tab records the new task, never '
      'the stale one', () async {
    fixture.desktop = true;
    fixture.taskStack.value = ['A'];
    fixture.journal.beamToNamed('/journal/e1');
    fixture.selectTab(1);

    // A notification opens task B: the tab comes forward and the route
    // moves while the stack still says A, for a frame.
    fixture.tasks.beamToNamed('/tasks/B');
    fixture.selectTab(0);
    expect(await recorded(), ['task:A /tasks/A', 'entry:e1 /journal/e1']);

    fixture.taskStack.value = ['B'];
    expect(await recorded(), [
      'task:A /tasks/A',
      'entry:e1 /journal/e1',
      'task:B /tasks/B',
    ]);
  });

  test('recordVisit records what navigation cannot see', () async {
    await recorder.recordVisit(taskTarget('pushed'));
    expect(await recorded(), ['task:pushed /tasks/pushed']);
  });

  test('the route and an explicit report of one task make one visit', () async {
    fixture.tasks.beamToNamed('/tasks/t1');
    await recorder.recordVisit(taskTarget('t1'));
    expect(await recorded(), ['task:t1 /tasks/t1']);
  });

  test('dispose stops recording', () async {
    await recorder.dispose();
    fixture.tasks.beamToNamed('/tasks/t1');
    fixture
      ..desktop = true
      ..selectTab(0);
    fixture.taskStack.value = ['t2'];
    expect(await recorded(), isEmpty);
  });

  test('start twice listens once', () async {
    recorder.start();
    fixture.tasks.beamToNamed('/tasks/t1');
    fixture.tasks.beamToNamed('/tasks/t2');
    expect(await recorded(), ['task:t1 /tasks/t1', 'task:t2 /tasks/t2']);
  });

  test('a failed write is logged, not thrown', () async {
    await recorder.dispose();
    final db = MockHistoryDb();
    when(db.latestEntry).thenThrow(StateError('disk full'));
    final failing = HistoryRecorder(
      navService: fixture.nav,
      service: HistoryService(db: db, titleResolver: bench.titleResolver),
      logger: logger,
    )..start();
    addTearDown(failing.dispose);

    fixture.tasks.beamToNamed('/tasks/t1');
    await pumpEventQueue();

    verify(
      () => logger.error(
        LogDomain.navigation,
        any<Object>(that: isA<StateError>()),
        stackTrace: any(named: 'stackTrace'),
        subDomain: 'history.record',
      ),
    ).called(1);
  });
}
