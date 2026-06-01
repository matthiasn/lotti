import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_rating/flutter_rating.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/event_data.dart';
import 'package:lotti/classes/event_status.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/categories/ui/widgets/category_field.dart';
import 'package:lotti/features/journal/model/entry_state.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/labels/state/labels_list_controller.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/editor_state_service.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/widgets/events/event_form.dart';
import 'package:mocktail/mocktail.dart';

import '../../mocks/mocks.dart';
import '../../widget_test_utils.dart';

/// Records the [EventForm] callback invocations so each form-field handler can
/// be asserted on without exercising the real persistence/repository layers.
class _RecordingEntryController extends EntryController {
  _RecordingEntryController(this._entry);

  final JournalEvent _entry;

  final List<({bool value, bool requestFocus})> setDirtyCalls = [];
  final List<String?> updateCategoryIdCalls = [];
  final List<double> updateRatingCalls = [];
  int saveCalls = 0;

  @override
  Future<EntryState?> build({required String id}) async {
    return EntryState.saved(
      entryId: id,
      entry: _entry,
      showMap: false,
      isFocused: false,
      shouldShowEditorToolBar: false,
      formKey: formKey,
    );
  }

  @override
  void setDirty({required bool value, bool requestFocus = true}) {
    setDirtyCalls.add((value: value, requestFocus: requestFocus));
  }

  @override
  Future<bool> updateCategoryId(String? categoryId) async {
    updateCategoryIdCalls.add(categoryId);
    return true;
  }

  @override
  Future<void> updateRating(double stars) async {
    updateRatingCalls.add(stars);
  }

  @override
  Future<void> save({
    Duration? estimate,
    String? title,
    DateTime? dueDate,
    bool clearDueDate = false,
    bool stopRecording = false,
  }) async {
    saveCalls++;
  }
}

JournalEvent _createEvent({
  String title = 'Test Event',
  double stars = 3,
  EventStatus status = EventStatus.planned,
  String? categoryId,
}) {
  final now = DateTime(2023);
  return JournalEvent(
    meta: Metadata(
      id: 'event-123',
      createdAt: now,
      updatedAt: now,
      dateFrom: now,
      dateTo: now.add(const Duration(hours: 1)),
      categoryId: categoryId,
    ),
    data: EventData(
      title: title,
      status: status,
      stars: stars,
    ),
  );
}

void main() {
  late MockEntitiesCacheService cacheService;
  late MockEditorStateService editorStateService;
  late MockJournalDb journalDb;
  late MockUpdateNotifications updateNotifications;

  setUp(() async {
    cacheService = MockEntitiesCacheService();
    editorStateService = MockEditorStateService();
    journalDb = MockJournalDb();
    updateNotifications = MockUpdateNotifications();

    await getIt.reset();
    getIt
      ..registerSingleton<EntitiesCacheService>(cacheService)
      ..registerSingleton<EditorStateService>(editorStateService)
      ..registerSingleton<JournalDb>(journalDb)
      ..registerSingleton<UpdateNotifications>(updateNotifications);

    when(() => cacheService.showPrivateEntries).thenReturn(true);
    when(() => cacheService.getLabelById(any())).thenReturn(null);
    when(() => cacheService.getCategoryById(any())).thenReturn(null);
  });

  tearDown(() async {
    await getIt.reset();
  });

  Future<_RecordingEntryController> pumpForm(
    WidgetTester tester,
    JournalEvent event, {
    bool focusOnTitle = false,
  }) async {
    final controller = _RecordingEntryController(event);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          entryControllerProvider(id: event.id).overrideWith(() => controller),
          labelsStreamProvider.overrideWith(
            (ref) => Stream<List<LabelDefinition>>.value(const []),
          ),
        ],
        child: makeTestableWidgetWithScaffold(
          EventForm(event, focusOnTitle: focusOnTitle),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return controller;
  }

  group('EventForm title field label (line 72)', () {
    testWidgets('shows event name label when title is empty', (tester) async {
      await pumpForm(tester, _createEvent(title: ''));

      // "Event:" is the localized eventNameLabel, shown only when title is empty.
      expect(find.text('Event:'), findsOneWidget);
    });

    testWidgets('hides event name label when title is present', (tester) async {
      await pumpForm(tester, _createEvent(title: 'Has Title'));

      expect(find.text('Event:'), findsNothing);
      // The populated title is rendered in the field.
      expect(find.text('Has Title'), findsOneWidget);
    });
  });

  group('EventForm title onChanged (line 81)', () {
    testWidgets('marks entry dirty without requesting focus on edit', (
      tester,
    ) async {
      final controller = await pumpForm(tester, _createEvent(title: 'Start'));
      expect(controller.setDirtyCalls, isEmpty);

      await tester.enterText(
        find.byType(FormBuilderTextField).first,
        'Edited title',
      );
      await tester.pump();

      expect(controller.setDirtyCalls, hasLength(1));
      expect(controller.setDirtyCalls.single.value, isTrue);
      expect(controller.setDirtyCalls.single.requestFocus, isFalse);
    });
  });

  group('EventForm category onSave (lines 96-97)', () {
    testWidgets('forwards selected category id to updateCategoryId', (
      tester,
    ) async {
      final controller = await pumpForm(tester, _createEvent());

      final categoryField = tester.widget<CategoryField>(
        find.byType(CategoryField),
      );

      final category = CategoryDefinition(
        id: 'cat-77',
        name: 'Work',
        createdAt: DateTime(2023),
        updatedAt: DateTime(2023),
        vectorClock: null,
        private: false,
        active: true,
      );
      categoryField.onSave(category);
      expect(controller.updateCategoryIdCalls, ['cat-77']);

      // Clearing the category forwards null.
      categoryField.onSave(null);
      expect(controller.updateCategoryIdCalls, ['cat-77', null]);
    });
  });

  group('EventForm status dropdown onChanged (line 107)', () {
    testWidgets('triggers save when a new status is selected', (tester) async {
      final controller = await pumpForm(tester, _createEvent());
      expect(controller.saveCalls, 0);

      await tester.tap(find.byType(FormBuilderDropdown<EventStatus>));
      await tester.pumpAndSettle();

      // Pick a status different from the initial "planned".
      await tester.tap(find.text('COMPLETED').last);
      await tester.pumpAndSettle();

      expect(controller.saveCalls, 1);
    });
  });

  group('EventForm star rating onRatingChanged (lines 132-136)', () {
    testWidgets('updates local rating state and persists new rating', (
      tester,
    ) async {
      final controller = await pumpForm(tester, _createEvent(stars: 1));

      StarRating starRating() =>
          tester.widget<StarRating>(find.byType(StarRating));
      expect(starRating().rating, 1);

      // Tapping the 4th star (index 3) reports rating 4.0.
      final stars = find.descendant(
        of: find.byType(StarRating),
        matching: find.byType(InkResponse),
      );
      await tester.tap(stars.at(3));
      await tester.pumpAndSettle();

      // setState rebuilt StarRating with the new rating (observable UI change).
      expect(starRating().rating, 4);
      // updateRating persisted the same value.
      expect(controller.updateRatingCalls, [4.0]);
    });
  });
}
