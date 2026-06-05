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
import 'package:lotti/features/labels/ui/widgets/entry_labels_display.dart';
import 'package:lotti/features/labels/ui/widgets/label_chip.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/editor_state_service.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/widgets/events/event_form.dart';
import 'package:mocktail/mocktail.dart';

import '../../mocks/mocks.dart';
import '../../test_data/test_data.dart';
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

/// Minimal controller used by the labels tests — only needs to build state.
class _TestEntryControllerSrc extends EntryController {
  _TestEntryControllerSrc(this._entry);

  final JournalEvent _entry;

  @override
  Future<EntryState?> build({required String id}) async {
    return EntryState.saved(
      entryId: id,
      entry: _entry,
      showMap: false,
      isFocused: false,
      shouldShowEditorToolBar: false,
    );
  }
}

JournalEvent _createTestEventSrc({
  List<String>? labelIds,
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
      labelIds: labelIds,
      categoryId: categoryId,
    ),
    data: const EventData(
      title: 'Test Event',
      status: EventStatus.planned,
      stars: 3,
    ),
  );
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

  // ---------------------------------------------------------------------------
  // Tests merged from event_form_labels_test.dart
  // ---------------------------------------------------------------------------
  group('EventForm labels', () {
    late MockEntitiesCacheService cacheServiceSrc;
    late MockEditorStateService editorStateServiceSrc;
    late MockJournalDb journalDbSrc;
    late MockUpdateNotifications updateNotificationsSrc;

    final labelA = testLabelDefinition1.copyWith(id: 'label-a', name: 'Alpha');
    final labelB = testLabelDefinition1.copyWith(id: 'label-b', name: 'Beta');

    setUp(() async {
      cacheServiceSrc = MockEntitiesCacheService();
      editorStateServiceSrc = MockEditorStateService();
      journalDbSrc = MockJournalDb();
      updateNotificationsSrc = MockUpdateNotifications();

      await getIt.reset();
      getIt
        ..registerSingleton<EntitiesCacheService>(cacheServiceSrc)
        ..registerSingleton<EditorStateService>(editorStateServiceSrc)
        ..registerSingleton<JournalDb>(journalDbSrc)
        ..registerSingleton<UpdateNotifications>(updateNotificationsSrc);

      when(() => cacheServiceSrc.showPrivateEntries).thenReturn(true);
      when(() => cacheServiceSrc.getLabelById(any())).thenAnswer((invocation) {
        final id = invocation.positionalArguments.first as String;
        switch (id) {
          case 'label-a':
            return labelA;
          case 'label-b':
            return labelB;
          default:
            return null;
        }
      });
      when(() => cacheServiceSrc.getCategoryById(any())).thenReturn(null);
    });

    tearDown(() async {
      await getIt.reset();
    });

    ProviderScope buildWrapperSrc(JournalEvent event) {
      return ProviderScope(
        overrides: [
          entryControllerProvider(id: event.id).overrideWith(
            () => _TestEntryControllerSrc(event),
          ),
          labelsStreamProvider.overrideWith(
            (ref) => Stream<List<LabelDefinition>>.value([labelA, labelB]),
          ),
        ],
        child: makeTestableWidgetWithScaffold(
          EventForm(event),
        ),
      );
    }

    group('EventForm labels section', () {
      testWidgets('renders EntryLabelsDisplay widget', (tester) async {
        final event = _createTestEventSrc();

        await tester.pumpWidget(buildWrapperSrc(event));
        await tester.pumpAndSettle();

        expect(find.byType(EntryLabelsDisplay), findsOneWidget);
      });

      testWidgets('shows Labels header', (tester) async {
        final event = _createTestEventSrc();

        await tester.pumpWidget(buildWrapperSrc(event));
        await tester.pumpAndSettle();

        expect(find.text('Labels'), findsOneWidget);
      });

      testWidgets('shows edit button for labels', (tester) async {
        final event = _createTestEventSrc();

        await tester.pumpWidget(buildWrapperSrc(event));
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
        expect(find.byTooltip('Edit labels'), findsOneWidget);
      });

      testWidgets('shows "No labels assigned" when event has no labels', (
        tester,
      ) async {
        final event = _createTestEventSrc(labelIds: []);

        await tester.pumpWidget(buildWrapperSrc(event));
        await tester.pumpAndSettle();

        expect(find.text('No labels assigned'), findsOneWidget);
      });

      testWidgets('displays assigned labels as chips', (tester) async {
        final event = _createTestEventSrc(labelIds: ['label-a', 'label-b']);

        await tester.pumpWidget(buildWrapperSrc(event));
        await tester.pumpAndSettle();

        expect(find.byType(LabelChip), findsNWidgets(2));
        expect(find.text('Alpha'), findsOneWidget);
        expect(find.text('Beta'), findsOneWidget);
      });

      testWidgets('shows labels below category/status/stars row', (
        tester,
      ) async {
        final event = _createTestEventSrc(labelIds: ['label-a']);

        await tester.pumpWidget(buildWrapperSrc(event));
        await tester.pumpAndSettle();

        final labelsHeader = find.text('Labels');
        expect(labelsHeader, findsOneWidget);

        final statusDropdown = find.text('Status:');
        expect(statusDropdown, findsOneWidget);

        final labelsPosition = tester.getTopLeft(labelsHeader);
        final statusPosition = tester.getTopLeft(statusDropdown);

        expect(labelsPosition.dy, greaterThan(statusPosition.dy));
      });
    });

    group('EventForm labels with null labelIds', () {
      testWidgets('handles null labelIds gracefully', (tester) async {
        final event = _createTestEventSrc();

        await tester.pumpWidget(buildWrapperSrc(event));
        await tester.pumpAndSettle();

        expect(find.text('Labels'), findsOneWidget);
        expect(find.text('No labels assigned'), findsOneWidget);
        expect(find.byType(LabelChip), findsNothing);
      });
    });

    group('EventForm labels private filtering', () {
      testWidgets('hides private labels when showPrivate is false', (
        tester,
      ) async {
        final privateLabel = testLabelDefinition1.copyWith(
          id: 'label-private',
          name: 'Private Label',
          private: true,
        );

        when(() => cacheServiceSrc.showPrivateEntries).thenReturn(false);
        when(
          () => cacheServiceSrc.getLabelById('label-private'),
        ).thenReturn(privateLabel);

        final event = _createTestEventSrc(
          labelIds: ['label-a', 'label-private'],
        );

        await tester.pumpWidget(buildWrapperSrc(event));
        await tester.pumpAndSettle();

        expect(find.byType(LabelChip), findsOneWidget);
        expect(find.text('Alpha'), findsOneWidget);
        expect(find.text('Private Label'), findsNothing);
      });
    });
  });
}
