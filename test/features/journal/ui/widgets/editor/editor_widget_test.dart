import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/editor_db.dart';
import 'package:lotti/features/journal/ui/widgets/editor/editor_widget.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/editor_state_service.dart';
import 'package:lotti/services/lotti_logger.dart';
import 'package:lotti/services/tags_service.dart';
import 'package:lotti/services/time_service.dart';
import 'package:lotti/services/vector_clock_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../mocks/mocks.dart';
import '../../../../../test_data/test_data.dart';
import '../../../../../widget_test_utils.dart';

void main() {
  group('EditorWidget', () {
    final mockTimeService = MockTimeService();

    setUpAll(() {
      final mockUpdateNotifications = MockUpdateNotifications();
      when(() => mockUpdateNotifications.updateStream).thenAnswer(
        (_) => Stream<Set<String>>.fromIterable([]),
      );

      getIt
        ..registerSingleton<UpdateNotifications>(mockUpdateNotifications)
        ..registerSingleton<LottiLogger>(LottiLogger())
        ..registerSingleton<VectorClockService>(MockVectorClockService())
        ..registerSingleton<JournalDb>(JournalDb(inMemoryDatabase: true))
        ..registerSingleton<EditorDb>(EditorDb(inMemoryDatabase: true))
        ..registerSingleton<PersistenceLogic>(MockPersistenceLogic())
        ..registerSingleton<TagsService>(TagsService())
        ..registerSingleton<TimeService>(mockTimeService)
        ..registerSingleton<EditorStateService>(EditorStateService());

      when(mockTimeService.getStream)
          .thenAnswer((_) => Stream<JournalEntity>.fromIterable([]));
    });

    testWidgets('editor toolbar is invisible without autofocus',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          EditorWidget(entryId: testTextEntry.meta.id),
        ),
      );

      await tester.pumpAndSettle();

      final boldIconFinder = find.byIcon(Icons.format_bold);
      expect(boldIconFinder, findsNothing);
    });
  });
}
