import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/fts5_db.dart';
import 'package:lotti/features/relationships/repository/relationship_repository.dart';
import 'package:lotti/features/relationships/ui/widgets/person_task_actions.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/fallbacks.dart';
import '../../../../helpers/fts5_stubs.dart';
import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';

/// Runs one of the actions from a button, the way the person page does.
class _Host extends ConsumerWidget {
  const _Host(this.onPressed);

  final void Function(BuildContext context, WidgetRef ref) onPressed;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Center(
    child: TextButton(
      key: const ValueKey('go'),
      onPressed: () => onPressed(context, ref),
      child: const Text('go'),
    ),
  );
}

void main() {
  final testDate = DateTime(2026, 8, 13, 10, 30);
  late MockRelationshipRepository repository;

  const actions = PersonTaskActions(
    relationshipId: 'rel-1',
    linkedTaskIds: {'t1'},
    personName: 'Pip',
  );

  setUpAll(registerAllFallbackValues);

  setUp(() {
    repository = MockRelationshipRepository();
  });

  Task task(String id, {String title = 'Prepare the call'}) =>
      JournalEntity.task(
            meta: Metadata(
              id: id,
              createdAt: testDate,
              updatedAt: testDate,
              dateFrom: testDate,
              dateTo: testDate,
            ),
            data: TaskData(
              status: TaskStatus.open(
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

  Future<void> pump(
    WidgetTester tester,
    void Function(BuildContext context, WidgetRef ref) onPressed,
  ) async {
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        _Host(onPressed),
        overrides: [
          relationshipRepositoryProvider.overrideWithValue(repository),
        ],
      ),
    );
    await tester.tap(find.byKey(const ValueKey('go')));
    await tester.pumpAndSettle();
  }

  group('pickTask', () {
    late MockJournalDb db;

    setUp(() {
      db = MockJournalDb();
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
      ).thenAnswer(
        (_) async => [task('t1'), task('t9', title: 'Send photos')],
      );
      when(
        () => anyMatchIds(fts),
      ).thenAnswer((_) async => const <String>[]);
      getIt
        ..registerSingleton<JournalDb>(db)
        ..registerSingleton<Fts5Db>(fts)
        ..registerSingleton<EntitiesCacheService>(cache);
    });

    tearDown(() async {
      await getIt.unregister<JournalDb>();
      await getIt.unregister<Fts5Db>();
      await getIt.unregister<EntitiesCacheService>();
    });

    testWidgets("the picker says what the create menu's row said, and "
        'leaves out the tasks already linked', (tester) async {
      await pump(tester, actions.pickTask);

      expect(find.text('Add a task for Pip'), findsOneWidget);
      expect(find.text('Send photos'), findsOneWidget);
      expect(find.text('Prepare the call'), findsNothing);
    });

    testWidgets('picking a task links it to the person and closes the '
        'picker', (tester) async {
      when(
        () => repository.linkTask(
          relationshipId: any(named: 'relationshipId'),
          taskId: any(named: 'taskId'),
        ),
      ).thenAnswer((_) async => true);
      await pump(tester, actions.pickTask);

      await tester.tap(find.text('Send photos'));
      await tester.pumpAndSettle();

      verify(
        () => repository.linkTask(relationshipId: 'rel-1', taskId: 't9'),
      ).called(1);
      expect(find.text('Add a task for Pip'), findsNothing);
      expect(
        find.text('Could not link the task. Please try again.'),
        findsNothing,
      );
    });

    testWidgets('a link that did not land says so', (tester) async {
      when(
        () => repository.linkTask(
          relationshipId: any(named: 'relationshipId'),
          taskId: any(named: 'taskId'),
        ),
      ).thenAnswer((_) async => false);
      await pump(tester, actions.pickTask);

      await tester.tap(find.text('Send photos'));
      await tester.pumpAndSettle();

      expect(
        find.text('Could not link the task. Please try again.'),
        findsOneWidget,
      );
    });
  });

  group('unlinkTask', () {
    void Function(BuildContext, WidgetRef) unlink(Task task) =>
        (context, ref) => actions.unlinkTask(context, ref, task);

    testWidgets('asks first, naming the task, then unlinks it', (
      tester,
    ) async {
      when(
        () => repository.unlinkTask(
          relationshipId: any(named: 'relationshipId'),
          taskId: any(named: 'taskId'),
        ),
      ).thenAnswer((_) async => true);
      await pump(tester, unlink(task('t1')));

      expect(
        find.text('Unlink “Prepare the call”? The task itself is not deleted.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Unlink Task'));
      await tester.pumpAndSettle();

      verify(
        () => repository.unlinkTask(relationshipId: 'rel-1', taskId: 't1'),
      ).called(1);
      expect(
        find.text("Couldn't unlink the task. Please try again."),
        findsNothing,
      );
    });

    testWidgets('cancelling unlinks nothing', (tester) async {
      await pump(tester, unlink(task('t1')));

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      verifyNever(
        () => repository.unlinkTask(
          relationshipId: any(named: 'relationshipId'),
          taskId: any(named: 'taskId'),
        ),
      );
    });

    testWidgets('an unlink that was refused says so', (tester) async {
      when(
        () => repository.unlinkTask(
          relationshipId: any(named: 'relationshipId'),
          taskId: any(named: 'taskId'),
        ),
      ).thenAnswer((_) async => false);
      await pump(tester, unlink(task('t1')));

      await tester.tap(find.text('Unlink Task'));
      await tester.pumpAndSettle();

      expect(
        find.text("Couldn't unlink the task. Please try again."),
        findsOneWidget,
      );
    });
  });
}
