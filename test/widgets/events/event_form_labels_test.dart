import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/event_data.dart';
import 'package:lotti/classes/event_status.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
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

class _TestEntryController extends EntryController {
  _TestEntryController(this._entry);

  final JournalEntity _entry;

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

JournalEvent createTestEvent({
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

void main() {
  late MockEntitiesCacheService cacheService;
  late MockEditorStateService editorStateService;
  late MockJournalDb journalDb;
  late MockUpdateNotifications updateNotifications;

  final labelA = testLabelDefinition1.copyWith(id: 'label-a', name: 'Alpha');
  final labelB = testLabelDefinition1.copyWith(id: 'label-b', name: 'Beta');

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
    when(() => cacheService.getLabelById(any())).thenAnswer((invocation) {
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
    when(() => cacheService.getCategoryById(any())).thenReturn(null);
  });

  tearDown(() async {
    await getIt.reset();
  });

  ProviderScope buildWrapper(JournalEvent event) {
    return ProviderScope(
      overrides: [
        entryControllerProvider(id: event.id).overrideWith(
          () => _TestEntryController(event),
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
      final event = createTestEvent();

      await tester.pumpWidget(buildWrapper(event));
      await tester.pumpAndSettle();

      expect(find.byType(EntryLabelsDisplay), findsOneWidget);
    });

    testWidgets('shows Labels header', (tester) async {
      final event = createTestEvent();

      await tester.pumpWidget(buildWrapper(event));
      await tester.pumpAndSettle();

      expect(find.text('Labels'), findsOneWidget);
    });

    testWidgets('shows edit button for labels', (tester) async {
      final event = createTestEvent();

      await tester.pumpWidget(buildWrapper(event));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
      expect(find.byTooltip('Edit labels'), findsOneWidget);
    });

    testWidgets('shows "No labels assigned" when event has no labels',
        (tester) async {
      final event = createTestEvent(labelIds: []);

      await tester.pumpWidget(buildWrapper(event));
      await tester.pumpAndSettle();

      expect(find.text('No labels assigned'), findsOneWidget);
    });

    testWidgets('displays assigned labels as chips', (tester) async {
      final event = createTestEvent(labelIds: ['label-a', 'label-b']);

      await tester.pumpWidget(buildWrapper(event));
      await tester.pumpAndSettle();

      expect(find.byType(LabelChip), findsNWidgets(2));
      expect(find.text('Alpha'), findsOneWidget);
      expect(find.text('Beta'), findsOneWidget);
    });

    testWidgets('shows labels below category/status/stars row', (tester) async {
      final event = createTestEvent(labelIds: ['label-a']);

      await tester.pumpWidget(buildWrapper(event));
      await tester.pumpAndSettle();

      // Find the labels section
      final labelsHeader = find.text('Labels');
      expect(labelsHeader, findsOneWidget);

      // Find the status dropdown (above labels)
      final statusDropdown = find.text('Status:');
      expect(statusDropdown, findsOneWidget);

      // Verify labels appears after status in the widget tree
      final labelsPosition = tester.getTopLeft(labelsHeader);
      final statusPosition = tester.getTopLeft(statusDropdown);

      // Labels should be below status (larger Y value)
      expect(labelsPosition.dy, greaterThan(statusPosition.dy));
    });
  });

  group('EventForm labels with null labelIds', () {
    testWidgets('handles null labelIds gracefully', (tester) async {
      final event = createTestEvent();

      await tester.pumpWidget(buildWrapper(event));
      await tester.pumpAndSettle();

      // Should show header with "No labels assigned" message
      expect(find.text('Labels'), findsOneWidget);
      expect(find.text('No labels assigned'), findsOneWidget);
      expect(find.byType(LabelChip), findsNothing);
    });
  });

  group('EventForm labels private filtering', () {
    testWidgets('hides private labels when showPrivate is false',
        (tester) async {
      final privateLabel = testLabelDefinition1.copyWith(
        id: 'label-private',
        name: 'Private Label',
        private: true,
      );

      when(() => cacheService.showPrivateEntries).thenReturn(false);
      when(() => cacheService.getLabelById('label-private'))
          .thenReturn(privateLabel);

      final event = createTestEvent(labelIds: ['label-a', 'label-private']);

      await tester.pumpWidget(buildWrapper(event));
      await tester.pumpAndSettle();

      // Only public label should be shown
      expect(find.byType(LabelChip), findsOneWidget);
      expect(find.text('Alpha'), findsOneWidget);
      expect(find.text('Private Label'), findsNothing);
    });
  });
}
