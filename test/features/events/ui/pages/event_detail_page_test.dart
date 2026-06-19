import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/event_data.dart';
import 'package:lotti/classes/event_status.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/events/ui/pages/event_detail_page.dart';
import 'package:lotti/features/events/ui/widgets/event_detail_view.dart';
import 'package:lotti/features/journal/model/entry_state.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/journal/state/linked_entries_controller.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/editor_state_service.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/fake_entry_controller.dart';
import '../../../../mocks/mocks.dart';
import '../../../../test_data/test_data.dart';
import '../../../../widget_test_utils.dart';

const _eventId = 'event-1';

/// Yields a null entry to exercise the page's loading / not-yet-resolved
/// branch. The resolved branch's data shaping (cover, timeline, tasks, summary)
/// is the pure `eventDetailDataFromEntities`, covered directly in
/// `event_view_mapping_test`; here we cover the page glue that wires it.
class _NullEntryController extends EntryController {
  @override
  Future<EntryState?> build({required String id}) {
    state = const AsyncData(null);
    return SynchronousFuture(null);
  }
}

/// Fails to load the entry, to exercise the page's terminal-error branch.
class _ErrorEntryController extends EntryController {
  @override
  Future<EntryState?> build({required String id}) {
    state = AsyncError(Exception('load failed'), StackTrace.current);
    return Future<EntryState?>.error(Exception('load failed'));
  }
}

JournalEvent _event() {
  final now = DateTime(2026, 5, 12);
  return JournalEvent(
    meta: Metadata(
      id: _eventId,
      createdAt: now,
      updatedAt: now,
      dateFrom: now,
      dateTo: now,
      categoryId: 'cat-1',
    ),
    data: const EventData(
      title: 'Launch Party',
      stars: 5,
      status: EventStatus.completed,
    ),
    entryText: const EntryText(plainText: 'What a night.'),
  );
}

void main() {
  // EntryController resolves several services through getIt at construction
  // time, so even the loading/error fakes need them registered.
  setUp(() async {
    await setUpTestGetIt(
      additionalSetup: () {
        final cache = MockEntitiesCacheService();
        when(() => cache.getCategoryById(any())).thenReturn(
          CategoryDefinition(
            id: 'cat-1',
            createdAt: DateTime(2026),
            updatedAt: DateTime(2026),
            name: 'Friends',
            vectorClock: null,
            private: false,
            active: true,
            color: '#E91E63',
          ),
        );
        getIt
          ..registerSingleton<EntitiesCacheService>(cache)
          ..registerSingleton<EditorStateService>(MockEditorStateService())
          ..registerSingleton<Directory>(Directory.systemTemp);
      },
    );
  });

  tearDown(() async {
    beamToNamedOverride = null;
    await tearDownTestGetIt();
  });

  testWidgets('shows a loading indicator when no event is resolved', (
    tester,
  ) async {
    await tester.pumpWidget(
      makeTestableWidget2(
        ProviderScope(
          overrides: [
            entryControllerProvider(
              id: _eventId,
            ).overrideWith(_NullEntryController.new),
          ],
          child: const EventDetailPage(eventId: _eventId),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('shows an error glyph when the entry fails to load', (
    tester,
  ) async {
    await tester.pumpWidget(
      makeTestableWidget2(
        ProviderScope(
          overrides: [
            entryControllerProvider(
              id: _eventId,
            ).overrideWith(_ErrorEntryController.new),
          ],
          child: const EventDetailPage(eventId: _eventId),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 10));

    expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  group('resolved event', () {
    Future<void> pumpResolved(
      WidgetTester tester, {
      required List<JournalEntity> linked,
      Size size = const Size(500, 2400),
    }) async {
      tester.view
        ..physicalSize = size
        ..devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        makeTestableWidget2(
          ProviderScope(
            overrides: [
              entryControllerProvider(
                id: _eventId,
              ).overrideWith(() => FakeEntryController(_event())),
              resolvedOutgoingLinkedEntriesProvider(
                _eventId,
              ).overrideWithValue(linked),
            ],
            child: const EventDetailPage(eventId: _eventId),
          ),
          mediaQueryData: MediaQueryData(size: size),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 10));
    }

    testWidgets('maps the resolved event + links into the detail view', (
      tester,
    ) async {
      await pumpResolved(
        tester,
        linked: [testImageEntry, testTextEntry, testTask],
      );

      expect(find.byType(EventDetailView), findsOneWidget);
      expect(find.text('Launch Party'), findsOneWidget);
      // Category resolved via EntitiesCacheService renders in the hero.
      expect(find.text('Friends'), findsOneWidget);
      // The event's own note becomes the summary (no linked AI response).
      expect(find.textContaining('What a night.'), findsOneWidget);
      // Linked photo + note render as timeline entries; the task as a task.
      expect(find.text('Timeline'), findsOneWidget);
      expect(find.text('Tasks'), findsOneWidget);
    });

    testWidgets('wires back / edit / add-to-timeline / add-task navigation', (
      tester,
    ) async {
      final beamed = <String>[];
      beamToNamedOverride = beamed.add;

      await pumpResolved(
        tester,
        linked: [testImageEntry, testTextEntry, testTask],
      );

      // Back maps to Navigator.maybePop (no route to pop → no-op, but runs).
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pump();

      // Edit + both section "Add" actions beam to the underlying journal entry.
      await tester.tap(find.byIcon(Icons.more_horiz));
      await tester.pump();
      await tester.ensureVisible(find.text('Add').first);
      await tester.tap(find.text('Add').first);
      await tester.pump();
      await tester.ensureVisible(find.text('Add').last);
      await tester.tap(find.text('Add').last);
      await tester.pump();

      expect(
        beamed.where((p) => p == '/journal/$_eventId').length,
        3,
      );
    });

    testWidgets('tapping a timeline row opens its linked source entry', (
      tester,
    ) async {
      final beamed = <String>[];
      beamToNamedOverride = beamed.add;

      await pumpResolved(tester, linked: [testTextEntry]);

      await tester.tap(find.text('test entry text'));
      await tester.pump();

      expect(beamed, ['/journal/${testTextEntry.meta.id}']);
    });
  });
}
