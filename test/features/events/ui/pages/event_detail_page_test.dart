import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rating/flutter_rating.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/event_data.dart';
import 'package:lotti/classes/event_status.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/agents/state/task_agent_providers.dart';
import 'package:lotti/features/events/ui/pages/event_detail_page.dart';
import 'package:lotti/features/events/ui/widgets/event_cover_image.dart';
import 'package:lotti/features/events/ui/widgets/event_cover_picker.dart';
import 'package:lotti/features/events/ui/widgets/event_detail_view.dart';
import 'package:lotti/features/journal/model/entry_state.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/journal/state/linked_entries_controller.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
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

/// Records the inline-edit mutations the page wires to, so we can assert the
/// page calls the controller (rather than bouncing to the old editor).
class _RecordingEntryController extends FakeEntryController {
  // ignore: use_super_parameters, parent uses a private `_entity` field
  _RecordingEntryController(JournalEvent entity) : super(entity);

  final titles = <String>[];
  final ratings = <double>[];
  final categories = <String?>[];
  final statuses = <EventStatus>[];
  final covers = <String?>[];
  int deletes = 0;

  @override
  Future<void> updateEventTitle(String title) async => titles.add(title);

  @override
  Future<void> updateRating(double stars) async => ratings.add(stars);

  @override
  Future<bool> updateCategoryId(String? categoryId) async {
    categories.add(categoryId);
    return true;
  }

  @override
  Future<void> updateEventStatus(EventStatus status) async =>
      statuses.add(status);

  @override
  Future<void> updateEventCover(String? imageId, {double? cropX}) async =>
      covers.add(imageId);

  @override
  Future<bool> delete({required bool beamBack}) async {
    deletes++;
    return true;
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

CategoryDefinition _category(String id, String name, String color) =>
    CategoryDefinition(
      id: id,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      name: name,
      vectorClock: null,
      private: false,
      active: true,
      color: color,
    );

void main() {
  late MockPersistenceLogic persistence;

  setUpAll(() {
    registerFallbackValue(FakeTaskData());
    registerFallbackValue(const EntryText(plainText: ''));
  });

  // EntryController resolves several services through getIt at construction
  // time, so even the loading/error fakes need them registered.
  setUp(() async {
    persistence = MockPersistenceLogic();
    await setUpTestGetIt(
      additionalSetup: () {
        final cache = MockEntitiesCacheService();
        when(() => cache.getCategoryById(any())).thenAnswer((invocation) {
          final id = invocation.positionalArguments.first as String?;
          return id == 'work'
              ? _category('work', 'Work', '#3B82F6')
              : _category('cat-1', 'Friends', '#E91E63');
        });
        when(
          () => cache.sortedCategories,
        ).thenReturn([_category('work', 'Work', '#3B82F6')]);
        when(
          () => persistence.createTaskEntry(
            data: any(named: 'data'),
            entryText: any(named: 'entryText'),
            linkedId: any(named: 'linkedId'),
            categoryId: any(named: 'categoryId'),
          ),
        ).thenAnswer((_) async => null);
        getIt
          ..registerSingleton<EntitiesCacheService>(cache)
          ..registerSingleton<PersistenceLogic>(persistence)
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
      EntryController Function()? controllerBuilder,
      List<Override> extraOverrides = const [],
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
              entryControllerProvider(id: _eventId).overrideWith(
                controllerBuilder ?? () => FakeEntryController(_event()),
              ),
              resolvedOutgoingLinkedEntriesProvider(
                _eventId,
              ).overrideWithValue(linked),
              ...extraOverrides,
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

    testWidgets('renames inline through the controller (not the old editor)', (
      tester,
    ) async {
      final rec = _RecordingEntryController(_event());
      await pumpResolved(
        tester,
        linked: const [],
        controllerBuilder: () => rec,
      );

      await tester.tap(find.text('Launch Party'));
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'Launch Party v2');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      expect(rec.titles, ['Launch Party v2']);
    });

    testWidgets('sets the rating inline through the controller', (
      tester,
    ) async {
      final rec = _RecordingEntryController(_event());
      await pumpResolved(
        tester,
        linked: const [],
        controllerBuilder: () => rec,
      );

      await tester.tap(find.byType(StarRating));
      await tester.pump();

      expect(rec.ratings, isNotEmpty);
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

    testWidgets('the category pill picks a category through the controller', (
      tester,
    ) async {
      final rec = _RecordingEntryController(_event());
      await pumpResolved(
        tester,
        linked: const [],
        controllerBuilder: () => rec,
      );

      await tester.tap(find.text('Friends')); // category pill
      await tester.pumpAndSettle();
      await tester.tap(find.text('Work')); // a row from sortedCategories
      await tester.pumpAndSettle();

      expect(rec.categories, ['work']);
    });

    testWidgets('clearing the category through the picker', (tester) async {
      final rec = _RecordingEntryController(_event());
      await pumpResolved(
        tester,
        linked: const [],
        controllerBuilder: () => rec,
      );

      await tester.tap(find.text('Friends'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Clear')); // the explicit "none" row
      await tester.pumpAndSettle();

      expect(rec.categories, [null]);
    });

    testWidgets('tapping the date opens the shared date-time editor', (
      tester,
    ) async {
      await pumpResolved(tester, linked: const []);
      await tester.tap(find.textContaining('May 2026')); // hero date line
      await tester.pumpAndSettle();
      expect(find.text('Date & Time'), findsOneWidget);
    });

    testWidgets('the status pill sets a status through the controller', (
      tester,
    ) async {
      final rec = _RecordingEntryController(_event());
      await pumpResolved(
        tester,
        linked: const [],
        controllerBuilder: () => rec,
      );

      await tester.tap(find.text('Completed')); // status pill
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancelled')); // a status row
      await tester.pumpAndSettle();

      expect(rec.statuses, [EventStatus.cancelled]);
    });

    testWidgets('the overflow menu deletes the event through the controller', (
      tester,
    ) async {
      final rec = _RecordingEntryController(_event());
      await pumpResolved(
        tester,
        linked: const [],
        controllerBuilder: () => rec,
      );

      await tester.tap(find.byIcon(Icons.more_horiz));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete event'));
      await tester.pumpAndSettle();
      // The destructive confirm action carries the warning glyph.
      await tester.tap(find.byIcon(Icons.warning_rounded));
      await tester.pumpAndSettle();

      expect(rec.deletes, 1);
    });

    testWidgets('the overflow menu opens the cover picker and sets the cover', (
      tester,
    ) async {
      final rec = _RecordingEntryController(_event());
      // A linked photo gives the event a cover, so "Change cover" is offered.
      await pumpResolved(
        tester,
        linked: [testImageEntry],
        controllerBuilder: () => rec,
      );

      await tester.tap(find.byIcon(Icons.more_horiz));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Change cover'));
      await tester.pumpAndSettle();

      expect(find.byType(EventCoverPicker), findsOneWidget);
      final pickerTile = find.descendant(
        of: find.byType(EventCoverPicker),
        matching: find.byType(EventCoverImage),
      );
      expect(pickerTile, findsOneWidget);
      await tester.tap(pickerTile);
      await tester.pumpAndSettle();

      expect(rec.covers, [testImageEntry.meta.id]);
    });

    testWidgets('the back button is wired to maybePop', (tester) async {
      await pumpResolved(tester, linked: const []);
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pump();
      // maybePop on the root no-ops, but the handler ran without leaving.
      expect(find.byType(EventDetailView), findsOneWidget);
    });

    testWidgets('the Tasks "+ Add" creates a task linked to the event', (
      tester,
    ) async {
      await pumpResolved(tester, linked: const []);
      // Empty event → Timeline + Tasks each show "+ Add"; the last is Tasks.
      await tester.tap(find.text('Add').last);
      await tester.pump();

      verify(
        () => persistence.createTaskEntry(
          data: any(named: 'data'),
          entryText: any(named: 'entryText'),
          linkedId: _eventId,
          categoryId: any(named: 'categoryId'),
        ),
      ).called(1);
    });

    testWidgets(
      'creating a task assigns the category agent and beams to the new task',
      (tester) async {
        // The created task is returned (not null), so the page runs the
        // post-create glue: auto-assigning the category agent and beaming to
        // the new task's detail page.
        when(
          () => persistence.createTaskEntry(
            data: any(named: 'data'),
            entryText: any(named: 'entryText'),
            linkedId: any(named: 'linkedId'),
            categoryId: any(named: 'categoryId'),
          ),
        ).thenAnswer((_) async => testTask);

        final beamed = <String>[];
        beamToNamedOverride = beamed.add;

        final taskAgentService = MockTaskAgentService();

        await pumpResolved(
          tester,
          linked: const [],
          extraOverrides: [
            taskAgentServiceProvider.overrideWithValue(taskAgentService),
          ],
        );

        await tester.tap(find.text('Add').last); // the Tasks "+ Add"
        await tester.pump();

        // The page navigates to the freshly created task's detail page.
        expect(beamed, ['/tasks/${testTask.meta.id}']);
        // The event's category ('cat-1', Friends) has no default task
        // template, so no agent is created — but the service was resolved.
        verifyNever(
          () => taskAgentService.createTaskAgent(
            taskId: any(named: 'taskId'),
            templateId: any(named: 'templateId'),
            allowedCategoryIds: any(named: 'allowedCategoryIds'),
          ),
        );
      },
    );

    testWidgets('tapping a linked task opens its task detail page', (
      tester,
    ) async {
      final beamed = <String>[];
      beamToNamedOverride = beamed.add;

      await pumpResolved(tester, linked: [testTask]);

      await tester.tap(find.text('Add tests for journal page'));
      await tester.pump();

      expect(beamed, ['/tasks/${testTask.meta.id}']);
    });
  });
}
