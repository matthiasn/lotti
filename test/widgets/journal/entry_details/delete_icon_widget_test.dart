import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/editor_state_service.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/widgets/journal/entry_details/delete_icon_widget.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../../test_data/test_data.dart';
import '../../../widget_test_utils.dart';

void main() {
  group('DeleteIconWidget', () {
    final mockJournalDb = MockJournalDb();
    final mockEditorStateService = MockEditorStateService();
    final mockPersistenceLogic = MockPersistenceLogic();
    final mockUpdateNotifications = MockUpdateNotifications();
    final mockNavService = MockNavService();

    setUpAll(() {
      getIt
        ..registerSingleton<UpdateNotifications>(mockUpdateNotifications)
        ..registerSingleton<EditorStateService>(mockEditorStateService)
        ..registerSingleton<JournalDb>(mockJournalDb)
        ..registerSingleton<NavService>(mockNavService)
        ..registerSingleton<PersistenceLogic>(mockPersistenceLogic);

      when(() => mockUpdateNotifications.updateStream).thenAnswer(
        (_) => Stream<Set<String>>.fromIterable([]),
      );
      when(() => mockPersistenceLogic.deleteJournalEntity(any())).thenAnswer(
        (_) async => true,
      );
    });

    testWidgets('calls delete in cubit', (WidgetTester tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          DeleteIconWidget(
            entryId: testTextEntry.meta.id,
            beamBack: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final trashIconFinder = find.byIcon(Icons.delete_outline_rounded);
      expect(trashIconFinder, findsOneWidget);

      await tester.tap(trashIconFinder);
      await tester.pumpAndSettle();

      final warningIconFinder = find.byIcon(Icons.warning_rounded);
      expect(warningIconFinder, findsOneWidget);

      await tester.tap(warningIconFinder);
      await tester.pumpAndSettle();

      // TODO: check that provider method is called instead
      // verify(() => entryCubit.delete(beamBack: any(named: 'beamBack')))
      //     .called(1);
    });
  });
}
