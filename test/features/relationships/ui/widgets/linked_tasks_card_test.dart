import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/fts5_db.dart';
import 'package:lotti/features/design_system/components/chips/ds_pill.dart';
import 'package:lotti/features/design_system/components/lists/design_system_list_item.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/relationships/repository/relationship_repository.dart';
import 'package:lotti/features/relationships/ui/widgets/linked_tasks_card.dart';
import 'package:lotti/features/tasks/ui/linked_tasks/linked_task_row.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/fallbacks.dart';
import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';

/// The card's rendering contract. The link/create/unlink flows run through
/// the person page and are exercised end to end in its test, where the
/// repository, picker and toasts are all wired.
void main() {
  final testDate = DateTime(2026, 8, 13, 10, 30);
  late MockRelationshipRepository repository;

  setUpAll(registerAllFallbackValues);

  setUp(() {
    repository = MockRelationshipRepository();
  });

  Task task(
    String id, {
    String title = 'Prepare the call',
    TaskStatus? status,
  }) =>
      JournalEntity.task(
            meta: Metadata(
              id: id,
              createdAt: testDate,
              updatedAt: testDate,
              dateFrom: testDate,
              dateTo: testDate,
            ),
            data: TaskData(
              status:
                  status ??
                  TaskStatus.open(
                    id: 'ts-$id',
                    createdAt: testDate,
                    utcOffset: 0,
                  ),
              dateFrom: testDate,
              dateTo: testDate,
              statusHistory: const [],
              title: title,
            ),
          )
          as Task;

  Future<void> pump(WidgetTester tester, List<Task> tasks) async {
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        LinkedTasksCard(relationshipId: 'rel-1', tasks: tasks),
        overrides: [
          relationshipRepositoryProvider.overrideWithValue(repository),
        ],
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('the empty state names the section, offers Link task and says '
      'nothing is linked', (tester) async {
    await pump(tester, const []);

    expect(find.text('Tasks'), findsOneWidget);
    expect(find.byKey(const ValueKey('person-link-task')), findsOneWidget);
    expect(find.text('No tasks linked yet.'), findsOneWidget);
    expect(find.byKey(const ValueKey('person-tasks-count')), findsNothing);
    expect(find.byType(DesignSystemListItem), findsNothing);
  });

  testWidgets('rows carry the title, the localized status, the status glyph '
      'and an unlink action; the header counts them', (tester) async {
    await pump(tester, [
      task('t1'),
      task(
        't2',
        title: 'Draft the comms plan',
        status: TaskStatus.groomed(
          id: 'ts-t2',
          createdAt: testDate,
          utcOffset: 0,
        ),
      ),
    ]);

    final count = tester
        .widgetList<DsPill>(find.byType(DsPill))
        .firstWhere((pill) => pill.label == '2 linked');
    expect(count.shape, DsPillShape.tag);
    expect(find.text('Prepare the call'), findsOneWidget);
    expect(find.text('Draft the comms plan'), findsOneWidget);
    expect(find.text('Open'), findsOneWidget);
    expect(find.text('Groomed'), findsOneWidget);
    expect(find.byType(StatusGlyph), findsNWidgets(2));
    expect(find.byIcon(LottiIcons.linkOff), findsNWidgets(2));
    expect(find.text('No tasks linked yet.'), findsNothing);
  });

  testWidgets('an untitled task uses the localized fallback', (tester) async {
    await pump(tester, [task('t1', title: '')]);

    expect(find.text('(untitled)'), findsOneWidget);
  });

  testWidgets('tapping a row beams to the task', (tester) async {
    await pump(tester, [task('t1')]);
    final beamedTo = <String>[];
    beamToNamedOverride = beamedTo.add;
    addTearDown(() => beamToNamedOverride = null);

    await tester.tap(find.text('Prepare the call'));
    await tester.pump();

    expect(beamedTo, ['/tasks/t1']);
  });

  testWidgets('Link task opens the picker, excluding the tasks already '
      'linked', (tester) async {
    final db = MockJournalDb();
    final fts = MockFts5Db();
    final cache = MockEntitiesCacheService();
    when(() => cache.sortedCategories).thenReturn([]);
    when(
      () => db.getTasks(
        starredStatuses: any(named: 'starredStatuses'),
        taskStatuses: any(named: 'taskStatuses'),
        categoryIds: any(named: 'categoryIds'),
        limit: any(named: 'limit'),
      ),
    ).thenAnswer((_) async => [task('t1'), task('t9', title: 'Send photos')]);
    when(
      () => fts.watchFullTextMatches(any()),
    ).thenAnswer((_) => Stream.value(const <String>[]));
    getIt
      ..registerSingleton<JournalDb>(db)
      ..registerSingleton<Fts5Db>(fts)
      ..registerSingleton<EntitiesCacheService>(cache);
    addTearDown(() async {
      await getIt.unregister<JournalDb>();
      await getIt.unregister<Fts5Db>();
      await getIt.unregister<EntitiesCacheService>();
    });

    await pump(tester, [task('t1')]);
    await tester.tap(find.byKey(const ValueKey('person-link-task')));
    await tester.pumpAndSettle();

    // The picker lists the other task and not the one already linked.
    expect(find.text('Send photos'), findsOneWidget);
    expect(find.text('Prepare the call'), findsOneWidget);
  });
}
