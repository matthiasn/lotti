import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/fts5_db.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/day_block_task_picker.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/tasks/ui/utils.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/entity_factories.dart';
import '../../../../helpers/fts5_stubs.dart';
import '../../../../helpers/service_overrides.dart';
import '../../../../mocks/mocks.dart';
import '../../../../test_helper.dart';
import '../../../categories/test_utils.dart';

void main() {
  late MockJournalDb journalDb;
  final now = DateTime(2026, 5, 1, 12);
  final sardines = TestTaskFactory.create(
    id: 'task-sardines',
    title: 'Negotiate sardine futures',
    createdAt: now,
    dateFrom: now,
    dateTo: now,
  );

  setUp(() async {
    await getIt.reset();
    journalDb = MockJournalDb();
    final fts5Db = MockFts5Db();
    final notifications = MockUpdateNotifications();
    when(
      () => notifications.updateStream,
    ).thenAnswer((_) => const Stream.empty());
    when(
      () => journalDb.getTasks(
        starredStatuses: any(named: 'starredStatuses'),
        taskStatuses: any(named: 'taskStatuses'),
        categoryIds: any(named: 'categoryIds'),
        limit: any(named: 'limit'),
      ),
    ).thenAnswer((_) async => [sardines]);
    when(() => anyMatchIds(fts5Db)).thenAnswer((_) async => <String>[]);
    final cache = MockEntitiesCacheService();
    when(() => cache.sortedCategories).thenReturn([
      CategoryTestUtils.createTestCategory(id: 'cat-a', name: 'A'),
    ]);
    getIt
      ..registerSingleton<EntitiesCacheService>(cache)
      ..registerSingleton<JournalDb>(journalDb)
      ..registerSingleton<Fts5Db>(fts5Db)
      ..registerSingleton<UpdateNotifications>(notifications);
  });

  tearDown(() async => getIt.reset());

  Future<Completer<Task?>> open(WidgetTester tester) async {
    final picked = Completer<Task?>();
    await tester.pumpWidget(
      ProviderScope(
        overrides: getItServiceOverrides(),
        child: WidgetTestBench(
          child: Consumer(
            builder: (context, ref, _) => ElevatedButton(
              onPressed: () async => picked.complete(
                ref.read(dayBlockTaskPickerProvider)(context),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    return picked;
  }

  testWidgets('lists open tasks and resolves with the one picked', (
    tester,
  ) async {
    final picked = await open(tester);

    await tester.tap(find.text('Negotiate sardine futures'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(await picked.future, sardines);
    // Only open work is offered for planning.
    verify(
      () => journalDb.getTasks(
        starredStatuses: any(named: 'starredStatuses'),
        taskStatuses: openTaskStatuses,
        categoryIds: any(named: 'categoryIds'),
        limit: any(named: 'limit'),
      ),
    ).called(greaterThanOrEqualTo(1));
  });

  testWidgets('closing it resolves with nothing', (tester) async {
    final picked = await open(tester);

    await tester.tap(find.byIcon(LottiIcons.close));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(await picked.future, isNull);
  });
}
