import 'dart:async';

import 'package:beamer/beamer.dart';
import 'package:flutter/widgets.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/history_db.dart';
import 'package:lotti/features/history/domain/history_entry.dart';
import 'package:lotti/features/history/state/history_service.dart';
import 'package:lotti/features/history/state/history_title_resolver.dart';
import 'package:mocktail/mocktail.dart';

import '../../mocks/mocks.dart';
import '../../test_data/test_data.dart';

/// A real in-memory [HistoryDb] behind a real [HistoryService], whose titles
/// come from a journal the test edits: [entities], [dashboards] and [habits]
/// are what "exists now", so renaming or deleting an entity between two reads
/// is one map write.
class HistoryTestBench {
  HistoryTestBench() {
    when(() => journalDb.getJournalEntitiesForIds(any())).thenAnswer(
      (invocation) async {
        final ids = invocation.positionalArguments.first as Set<String>;
        return [
          for (final id in ids) ?entities[id],
        ];
      },
    );
    when(() => journalDb.getDashboardById(any())).thenAnswer(
      (invocation) async => dashboards[invocation.positionalArguments.first],
    );
    when(() => journalDb.getHabitById(any())).thenAnswer(
      (invocation) async => habits[invocation.positionalArguments.first],
    );
  }

  final db = HistoryDb(inMemoryDatabase: true, background: false);
  final journalDb = MockJournalDb();
  final entities = <String, JournalEntity>{};
  final dashboards = <String, DashboardDefinition>{};
  final habits = <String, HabitDefinition>{};

  late final titleResolver = HistoryTitleResolver(journalDb);
  late final service = HistoryService(db: db, titleResolver: titleResolver);

  /// Puts a task titled [title] into the journal under [id].
  void putTask(String id, String title) {
    entities[id] = testTask.copyWith(
      meta: testTask.meta.copyWith(id: id),
      data: testTask.data.copyWith(title: title),
    );
  }

  /// Appends a visit to task [id] straight into the log, bypassing the
  /// consecutive-visit rule, and returns its row id.
  Future<int> appendTaskVisit(String id, DateTime visitedAt) => db.appendEntry(
    kind: HistoryEntityKind.task.name,
    entityId: id,
    route: '/tasks/$id',
    visitedAt: visitedAt,
  );

  Future<void> close() => db.close();
}

HistoryTarget taskTarget(String id) => HistoryTarget(
  kind: HistoryEntityKind.task,
  entityId: id,
  route: '/tasks/$id',
);

/// Tab delegates, desktop selections and the tab index of a [MockNavService],
/// all real objects the test moves the way the app would.
class HistoryNavFixture {
  HistoryNavFixture() {
    when(() => nav.tasksDelegate).thenReturn(tasks);
    when(() => nav.journalDelegate).thenReturn(journal);
    when(() => nav.projectsDelegate).thenReturn(projects);
    when(() => nav.eventsDelegate).thenReturn(events);
    when(() => nav.relationshipsDelegate).thenReturn(people);
    when(() => nav.dashboardsDelegate).thenReturn(dashboards);
    when(() => nav.habitsDelegate).thenReturn(habits);
    // The tab order the tests select by index.
    when(
      () => nav.beamerDelegates,
    ).thenReturn([tasks, journal, projects, people, dashboards]);
    when(() => nav.index).thenAnswer((_) => index);
    when(nav.getIndexStream).thenAnswer((_) => indexes.stream);
    when(() => nav.desktopSelectedTaskId).thenReturn(selectedTask);
    when(() => nav.desktopSelectedEntryId).thenReturn(selectedEntry);
    when(() => nav.desktopSelectedProjectId).thenReturn(selectedProject);
    when(() => nav.desktopSelectedRelationshipId).thenReturn(selectedPerson);
    when(() => nav.desktopSelectedDashboardId).thenReturn(selectedDashboard);
    when(() => nav.desktopTaskDetailStack).thenReturn(taskStack);
    when(() => nav.isDesktopMode).thenAnswer((_) => desktop);
  }

  final nav = MockNavService();
  final BeamerDelegate tasks = _delegate('/tasks');
  final BeamerDelegate journal = _delegate('/journal');
  final BeamerDelegate projects = _delegate('/projects');
  final BeamerDelegate events = _delegate('/events');
  final BeamerDelegate people = _delegate('/people');
  final BeamerDelegate dashboards = _delegate('/dashboards');
  final BeamerDelegate habits = _delegate('/habits');
  final selectedTask = ValueNotifier<String?>(null);
  final selectedEntry = ValueNotifier<String?>(null);
  final selectedProject = ValueNotifier<String?>(null);
  final selectedPerson = ValueNotifier<String?>(null);
  final selectedDashboard = ValueNotifier<String?>(null);
  final taskStack = ValueNotifier<List<String>>(const []);
  final indexes = StreamController<int>.broadcast();
  int index = 0;

  /// The layout `NavService.isDesktopMode` reports.
  bool desktop = false;

  /// Brings the tab at [newIndex] to the front, as `NavService.setIndex`
  /// does: index first, then the stream.
  void selectTab(int newIndex) {
    index = newIndex;
    indexes.add(newIndex);
  }

  static BeamerDelegate _delegate(String initialPath) => BeamerDelegate(
    initialPath: initialPath,
    locationBuilder: RoutesLocationBuilder(
      routes: {'*': (context, state, data) => const SizedBox.shrink()},
    ).call,
  );

  Future<void> dispose() async {
    await indexes.close();
    for (final delegate in [
      tasks,
      journal,
      projects,
      events,
      people,
      dashboards,
      habits,
    ]) {
      delegate.dispose();
    }
  }
}
