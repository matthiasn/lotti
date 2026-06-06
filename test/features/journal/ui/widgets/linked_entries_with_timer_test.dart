import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/journal/ui/widgets/entry_detail_linked.dart';
import 'package:lotti/features/journal/ui/widgets/linked_entries_with_timer.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/editor_state_service.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/link_service.dart';
import 'package:lotti/services/time_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';
import '../../../../test_data/test_data.dart';
import '../../../../widget_test_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockJournalDb mockJournalDb;
  late StreamController<JournalEntity?> timerController;

  setUp(() {
    mockJournalDb = MockJournalDb();
    timerController = StreamController<JournalEntity?>.broadcast();

    final mockTimeService = MockTimeService();
    when(mockTimeService.getStream).thenAnswer((_) => timerController.stream);

    final mockUpdateNotifications = MockUpdateNotifications();
    when(
      () => mockUpdateNotifications.updateStream,
    ).thenAnswer((_) => const Stream.empty());

    when(
      () => mockJournalDb.getLinkedEntities(testTask.meta.id),
    ).thenAnswer((_) async => []);
    when(() => mockJournalDb.watchConfigFlags()).thenAnswer(
      (_) => Stream<Set<ConfigFlag>>.fromIterable([<ConfigFlag>{}]),
    );

    getIt
      ..registerSingleton<UserActivityService>(UserActivityService())
      ..registerSingleton<UpdateNotifications>(mockUpdateNotifications)
      ..registerSingleton<EditorStateService>(MockEditorStateService())
      ..registerSingleton<EntitiesCacheService>(MockEntitiesCacheService())
      ..registerSingleton<LinkService>(MockLinkService())
      ..registerSingleton<TimeService>(mockTimeService)
      ..registerSingleton<JournalDb>(mockJournalDb)
      ..registerSingleton<PersistenceLogic>(MockPersistenceLogic());
  });

  tearDown(() async {
    await timerController.close();
    await getIt.reset();
  });

  Future<void> pumpSubject(WidgetTester tester) async {
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        LinkedEntriesWithTimer(
          item: testTask,
          highlightedEntryId: null,
        ),
      ),
    );
    await tester.pump();
  }

  LinkedEntriesWidget linkedWidget(WidgetTester tester) =>
      tester.widget<LinkedEntriesWidget>(find.byType(LinkedEntriesWidget));

  group('LinkedEntriesWithTimer', () {
    testWidgets(
      'passes the active timer entry id through to LinkedEntriesWidget',
      (tester) async {
        await pumpSubject(tester);

        // No timer running yet.
        expect(linkedWidget(tester).activeTimerEntryId, isNull);

        // Timer starts on a linked entry.
        timerController.add(testTextEntry);
        await tester.pump();
        await tester.pump();

        expect(
          linkedWidget(tester).activeTimerEntryId,
          testTextEntry.meta.id,
        );

        // Timer stops: the id is cleared again.
        timerController.add(null);
        await tester.pump();
        await tester.pump();

        expect(linkedWidget(tester).activeTimerEntryId, isNull);
      },
    );

    testWidgets(
      'distinct() suppresses rebuilds when the same entry id arrives twice',
      (tester) async {
        await pumpSubject(tester);

        timerController.add(testTextEntry);
        await tester.pump();
        await tester.pump();
        final firstBuild = linkedWidget(tester);

        // Same id again (e.g. a timer tick re-emitting the entity): the
        // StreamBuilder must NOT rebuild, so the widget instance is
        // unchanged.
        timerController.add(testTextEntry);
        await tester.pump();
        await tester.pump();
        expect(identical(linkedWidget(tester), firstBuild), isTrue);

        // A different entry id does rebuild.
        timerController.add(testTask);
        await tester.pump();
        await tester.pump();
        final thirdBuild = linkedWidget(tester);
        expect(identical(thirdBuild, firstBuild), isFalse);
        expect(thirdBuild.activeTimerEntryId, testTask.meta.id);
      },
    );
  });
}
