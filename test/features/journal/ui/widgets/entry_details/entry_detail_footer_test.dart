import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/editor_db.dart';
import 'package:lotti/features/journal/model/entry_state.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/journal/ui/widgets/entry_details/duration_widget.dart';
import 'package:lotti/features/journal/ui/widgets/entry_details/entry_detail_footer.dart';
import 'package:lotti/features/journal/ui/widgets/entry_details/save_button.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/editor_state_service.dart';
import 'package:lotti/services/time_service.dart';
import 'package:lotti/widgets/misc/map_widget.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../helpers/fake_entry_controller.dart';
import '../../../../../mocks/mocks.dart';
import '../../../../../test_data/test_data.dart';
import '../../../../../widget_test_utils.dart';

/// Fake controller that resolves to an [EntryState] with a `null` entry, used
/// to exercise the footer's empty-state (`SizedBox.shrink`) branch.
class _NullEntryController extends EntryController {
  @override
  Future<EntryState?> build({required String id}) {
    final value = EntryState.saved(
      entryId: id,
      entry: null,
      showMap: false,
      isFocused: false,
      shouldShowEditorToolBar: false,
      formKey: GlobalKey<FormBuilderState>(),
    );
    state = AsyncData(value);
    return SynchronousFuture(value);
  }
}

void main() {
  group('EntryDetailFooter', () {
    final mockTimeService = MockTimeService();
    final mockPersistenceLogic = MockPersistenceLogic();
    final mockEditorDb = MockEditorDb();
    final mockEditorStateService = MockEditorStateService();
    final mockJournalDb = MockJournalDb();

    setUpAll(() async {
      await getIt.reset();
      final mockUpdateNotifications = MockUpdateNotifications();
      registerFallbackValue(FakeEntryText());
      registerFallbackValue(FakeQuillController());

      when(() => mockUpdateNotifications.updateStream).thenAnswer(
        (_) => Stream<Set<String>>.fromIterable([]),
      );

      getIt
        ..registerSingleton<UpdateNotifications>(mockUpdateNotifications)
        ..registerSingleton<JournalDb>(mockJournalDb)
        ..registerSingleton<TimeService>(mockTimeService)
        ..registerSingleton<EditorDb>(mockEditorDb)
        ..registerSingleton<EditorStateService>(mockEditorStateService)
        ..registerSingleton<PersistenceLogic>(mockPersistenceLogic);

      when(
        () => mockEditorStateService.entryWasSaved(
          id: any(named: 'id'),
          lastSaved: any(named: 'lastSaved'),
          controller: any(named: 'controller'),
        ),
      ).thenAnswer(
        (_) async {},
      );

      when(
        () => mockPersistenceLogic.updateJournalEntityText(
          any(),
          any(),
          any(),
        ),
      ).thenAnswer(
        (_) async => true,
      );

      when(() => mockUpdateNotifications.updateStream).thenAnswer(
        (_) => Stream<Set<String>>.fromIterable([]),
      );

      when(
        () => mockJournalDb.journalEntityById(testTextEntry.meta.id),
      ).thenAnswer((_) async => testTextEntry);

      when(
        mockTimeService.getStream,
      ).thenAnswer((_) => Stream<JournalEntity>.fromIterable([]));

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

    testWidgets('map is invisible when not set in cubit', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          EntryDetailFooter(
            entryId: testTextEntry.meta.id,
            linkedFrom: null,
          ),
        ),
      );
      // Render-only assertion: a bounded pump flushes the async entry
      // controller without waiting on unrelated animations.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 10));
      final mapFinder = find.byType(FlutterMap);
      expect(mapFinder, findsNothing);

      // showMap defaults to false, so the map's Visibility child is not built.
      expect(find.byType(MapWidget), findsNothing);
    });

    testWidgets('time record button is not shown for older entry', (
      WidgetTester tester,
    ) async {
      when(
        mockTimeService.getStream,
      ).thenAnswer((_) => Stream<JournalEntity>.fromIterable([]));

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          EntryDetailFooter(
            entryId: testTextEntry.meta.id,
            linkedFrom: null,
          ),
        ),
      );
      // Render-only assertion: bounded pump instead of pumpAndSettle.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 10));

      final recordIconFinder = find.byIcon(Icons.fiber_manual_record_sharp);
      expect(recordIconFinder, findsNothing);
    });

    testWidgets('time record button is tappable', (WidgetTester tester) async {
      when(
        mockTimeService.getStream,
      ).thenAnswer((_) => Stream<JournalEntity>.fromIterable([]));

      // Must be relative to real time — the widget checks isRecent via
      // DateTime.now().difference(dateFrom).inHours < 12 internally.
      final recentDate = DateTime.now(); // ignore: avoid_DateTime_now

      final testEntry = testTextEntry.copyWith(
        meta: testTextEntry.meta.copyWith(
          dateFrom: recentDate,
          dateTo: recentDate,
        ),
      );

      when(
        () => mockJournalDb.journalEntityById(testTextEntry.meta.id),
      ).thenAnswer((_) async => testEntry);

      Future<void> mockStartTimer() => mockTimeService.start(testEntry, null);
      when(mockStartTimer).thenAnswer((_) async {});

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          EntryDetailFooter(
            entryId: testTextEntry.meta.id,
            linkedFrom: null,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final recordIconFinder = find.byIcon(Icons.fiber_manual_record_sharp);
      final stopIconFinder = find.byIcon(Icons.stop);
      expect(recordIconFinder, findsOneWidget);
      expect(stopIconFinder, findsNothing);

      final durationZeroFinder = find.text('00:00:00');
      expect(durationZeroFinder, findsOneWidget);

      await tester.tap(recordIconFinder);
      await tester.pumpAndSettle();

      verify(mockStartTimer).called(1);
    });

    testWidgets('time record stop button is tappable', (
      WidgetTester tester,
    ) async {
      final testDate = DateTime(2024, 3, 15, 10, 30);

      final testEntry = testTextEntry.copyWith(
        meta: testTextEntry.meta.copyWith(
          dateFrom: testDate.subtract(const Duration(seconds: 5)),
          dateTo: testDate,
        ),
      );

      when(
        () => mockJournalDb.journalEntityById(testTextEntry.meta.id),
      ).thenAnswer((_) async => testEntry);

      when(
        mockTimeService.getStream,
      ).thenAnswer((_) => Stream<JournalEntity>.fromIterable([testEntry]));

      Future<void> mockStopTimer() => mockTimeService.stop();
      when(mockStopTimer).thenAnswer((_) async {});

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          EntryDetailFooter(
            entryId: testTextEntry.meta.id,
            linkedFrom: null,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final recordIconFinder = find.byIcon(Icons.fiber_manual_record_sharp);
      final stopIconFinder = find.byIcon(Icons.stop);
      expect(recordIconFinder, findsNothing);
      expect(stopIconFinder, findsOneWidget);

      final durationZeroFinder = find.text('00:00:05');
      expect(durationZeroFinder, findsOneWidget);

      await tester.tap(stopIconFinder);
      await tester.pumpAndSettle();

      verify(mockStopTimer).called(1);
    });

    testWidgets('shows DurationWidget but no SaveButton when not in linked '
        'entries', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          EntryDetailFooter(
            entryId: testTextEntryNoGeo.meta.id,
            linkedFrom: null,
          ),
          overrides: [
            entryControllerProvider(
              id: testTextEntryNoGeo.meta.id,
            ).overrideWith(
              () => FakeEntryController(testTextEntryNoGeo),
            ),
          ],
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 10));

      // A JournalEntry always renders the DurationWidget; the save button is
      // only present inside linked-entries lists.
      expect(find.byType(DurationWidget), findsOneWidget);
      expect(find.byType(SaveButton), findsNothing);
    });

    testWidgets('shows SaveButton when rendered inside linked entries', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          EntryDetailFooter(
            entryId: testTextEntryNoGeo.meta.id,
            linkedFrom: null,
            inLinkedEntries: true,
          ),
          overrides: [
            entryControllerProvider(
              id: testTextEntryNoGeo.meta.id,
            ).overrideWith(
              () => FakeEntryController(testTextEntryNoGeo),
            ),
          ],
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 10));

      expect(find.byType(SaveButton), findsOneWidget);
    });

    testWidgets('map child is built and visible when showMap is true', (
      tester,
    ) async {
      // Use a geolocation-free entry so MapWidget short-circuits to a Center
      // and never instantiates FlutterMap (which would attempt tile fetches).
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          EntryDetailFooter(
            entryId: testTextEntryNoGeo.meta.id,
            linkedFrom: null,
          ),
          overrides: [
            entryControllerProvider(
              id: testTextEntryNoGeo.meta.id,
            ).overrideWith(
              () => FakeEntryController(testTextEntryNoGeo, showMap: true),
            ),
          ],
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 10));

      // With showMap true the Visibility child is built, so MapWidget is in the
      // tree, and its enclosing Visibility reports visible == true.
      final mapFinder = find.byType(MapWidget);
      expect(mapFinder, findsOneWidget);
      // No geolocation -> no FlutterMap (no network tile loading).
      expect(find.byType(FlutterMap), findsNothing);

      // The closest Visibility ancestor of MapWidget is the footer's own
      // map wrapper; first() avoids matching framework Visibility widgets
      // higher up the tree.
      final visibility = tester.widget<Visibility>(
        find.ancestor(of: mapFinder, matching: find.byType(Visibility)).first,
      );
      expect(visibility.visible, isTrue);
    });

    testWidgets('renders nothing when the entry is null', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          EntryDetailFooter(
            entryId: testTextEntryNoGeo.meta.id,
            linkedFrom: null,
          ),
          overrides: [
            entryControllerProvider(
              id: testTextEntryNoGeo.meta.id,
            ).overrideWith(
              _NullEntryController.new,
            ),
          ],
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 10));

      // The footer short-circuits to SizedBox.shrink, so none of its content
      // widgets are present.
      expect(find.byType(DurationWidget), findsNothing);
      expect(find.byType(SaveButton), findsNothing);
      expect(find.byType(MapWidget), findsNothing);
    });
  });
}
