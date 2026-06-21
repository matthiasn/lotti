import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/journal/ui/widgets/entry_details/entry_datetime_widget.dart';
import 'package:lotti/features/journal/util/entry_tools.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/editor_state_service.dart';
import 'package:lotti/themes/theme.dart' show numericBadgeFontFeatures;
import 'package:mocktail/mocktail.dart';

import '../../../../../mocks/mocks.dart';
import '../../../../../test_data/test_data.dart';
import '../../../../../widget_test_utils.dart';

void main() {
  group('EntryDetailFooter', () {
    final mockPersistenceLogic = MockPersistenceLogic();
    final mockJournalDb = MockJournalDb();
    final mockEditorStateService = MockEditorStateService();

    setUpAll(() async {
      await getIt.reset();
      final mockUpdateNotifications = MockUpdateNotifications();
      when(() => mockUpdateNotifications.updateStream).thenAnswer(
        (_) => Stream<Set<String>>.fromIterable([]),
      );

      getIt
        ..registerSingleton<UpdateNotifications>(mockUpdateNotifications)
        ..registerSingleton<JournalDb>(mockJournalDb)
        ..registerSingleton<PersistenceLogic>(mockPersistenceLogic)
        ..registerSingleton<EditorStateService>(mockEditorStateService);

      when(
        () => mockJournalDb.journalEntityById(testTextEntry.meta.id),
      ).thenAnswer((_) async => testTextEntry);

      when(
        () => mockEditorStateService.getUnsavedStream(
          any(),
          any(),
        ),
      ).thenAnswer(
        (_) => Stream<bool>.fromIterable([false]),
      );
    });

    tearDownAll(() async {
      await getIt.reset();
    });

    testWidgets('tap entry date opens modal', (WidgetTester tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          EntryDatetimeWidget(
            entryId: testTextEntry.meta.id,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final entryDateFromFinder = find.text(
        dfShorter.format(testTextEntry.meta.dateFrom),
      );
      expect(entryDateFromFinder, findsOneWidget);

      await tester.tap(entryDateFromFinder);
      await tester.pumpAndSettle();

      // The redesigned single-page editor opened: one shared date plus the
      // paired start/end time wheels (the date is no longer entered twice).
      expect(find.text('Date & Time'), findsOneWidget);
      expect(find.text('Start time'), findsOneWidget);
      expect(find.text('End time'), findsOneWidget);

      // Close modal by tapping outside
      await tester.tapAt(Offset.zero);
      await tester.pumpAndSettle();
    });

    testWidgets('date text uses the shared numeric badge font features', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          EntryDatetimeWidget(
            entryId: testTextEntry.meta.id,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final finder = find.text(dfShorter.format(testTextEntry.meta.dateFrom));
      expect(finder, findsOneWidget);

      final text = tester.widget<Text>(finder);
      // The date is a small numeric readout, so it carries the shared
      // numericBadgeFontFeatures (tabular + open four/six/nine + slashed zero)
      // for steady, legible digits — matching the audio timecodes and duration.
      expect(text.style?.fontFeatures, numericBadgeFontFeatures);

      // Legible secondary colour (mediumEmphasis ≈ 10:1 on the card), not the
      // faint decorative hairline tone the timestamp used to inherit.
      final BuildContext ctx = tester.element(finder);
      expect(text.style?.color, ctx.designTokens.colors.text.mediumEmphasis);
    });
  });
}
