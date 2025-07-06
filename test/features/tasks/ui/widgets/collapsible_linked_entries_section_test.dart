import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/journal/state/linked_entries_controller.dart';
import 'package:lotti/features/tasks/ui/widgets/collapsible_linked_entries_section.dart';
import 'package:lotti/features/tasks/ui/widgets/collapsible_task_section.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:mocktail/mocktail.dart';

class MockUpdateNotifications extends Mock implements UpdateNotifications {}

class MockPersistenceLogic extends Mock implements PersistenceLogic {}

// Test controller for linked entries
class TestLinkedEntriesController extends LinkedEntriesController {
  TestLinkedEntriesController(this._links);

  final List<EntryLink> _links;

  @override
  void listen() {
    // No-op: don't set up real listeners in tests
  }

  @override
  Future<List<EntryLink>> build({required String id}) async {
    state = AsyncValue.data(_links);
    return _links;
  }
}

// Test controller for include AI entries
class TestIncludeAiEntriesController extends IncludeAiEntriesController {
  TestIncludeAiEntriesController({required bool value}) : _value = value;

  final bool _value;

  @override
  bool build({required String id}) {
    state = _value;
    return _value;
  }
}

void main() {
  setUpAll(getIt.reset);

  group('CollapsibleLinkedEntriesSection', () {
    late ScrollController scrollController;
    late MockUpdateNotifications mockUpdateNotifications;
    late MockPersistenceLogic mockPersistenceLogic;

    setUp(() {
      scrollController = ScrollController();

      // Set up mocks
      mockUpdateNotifications = MockUpdateNotifications();
      mockPersistenceLogic = MockPersistenceLogic();

      // Configure mock behavior
      when(() => mockUpdateNotifications.updateStream)
          .thenAnswer((_) => const Stream<Set<String>>.empty());

      // Register mocks with getIt
      getIt
        ..reset()
        ..registerSingleton<UpdateNotifications>(mockUpdateNotifications)
        ..registerSingleton<PersistenceLogic>(mockPersistenceLogic);
    });

    tearDown(() {
      scrollController.dispose();
      getIt.reset();
    });

    Widget createTestWidget({
      required Widget child,
      required List<Override> overrides,
    }) {
      return ProviderScope(
        overrides: overrides,
        child: MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
          ],
          home: Scaffold(
            body: SingleChildScrollView(
              controller: scrollController,
              child: child,
            ),
          ),
        ),
      );
    }

    Task createTask() {
      final now = DateTime.now();
      return Task(
        meta: Metadata(
          id: 'test-task-id',
          createdAt: now,
          updatedAt: now,
          dateFrom: now,
          dateTo: now,
        ),
        data: TaskData(
          title: 'Test Task',
          status: TaskStatus.open(
            id: 'status-id',
            createdAt: now,
            utcOffset: now.timeZoneOffset.inMinutes,
          ),
          dateFrom: now,
          dateTo: now,
          statusHistory: [],
        ),
      );
    }

    EntryLink createEntryLink(String fromId, String toId) {
      final now = DateTime.now();
      return EntryLink.basic(
        id: '$fromId-$toId',
        fromId: fromId,
        toId: toId,
        createdAt: now,
        updatedAt: now,
        vectorClock: null,
      );
    }

    testWidgets('shows nothing when no linked entries exist', (tester) async {
      final task = createTask();

      await tester.pumpWidget(
        createTestWidget(
          overrides: [
            linkedEntriesControllerProvider(id: 'test-task-id').overrideWith(
              () => TestLinkedEntriesController([]),
            ),
            includeAiEntriesControllerProvider(id: 'test-task-id').overrideWith(
              () => TestIncludeAiEntriesController(value: true),
            ),
          ],
          child: CollapsibleLinkedEntriesSection(
            task: task,
            scrollController: scrollController,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(CollapsibleLinkedEntriesSection), findsOneWidget);
      expect(find.byIcon(MdiIcons.linkVariant), findsNothing);
    });

    testWidgets('shows single linked entry preview', (tester) async {
      final task = createTask();
      final link = createEntryLink('test-task-id', 'linked-entry-1');

      await tester.pumpWidget(
        createTestWidget(
          overrides: [
            linkedEntriesControllerProvider(id: 'test-task-id').overrideWith(
              () => TestLinkedEntriesController([link]),
            ),
            includeAiEntriesControllerProvider(id: 'test-task-id').overrideWith(
              () => TestIncludeAiEntriesController(value: true),
            ),
          ],
          child: CollapsibleLinkedEntriesSection(
            task: task,
            scrollController: scrollController,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byIcon(MdiIcons.linkVariant), findsOneWidget);
      expect(find.text('Linked Entries'), findsOneWidget);
      expect(find.text('1 linked entry'), findsOneWidget);
    });

    testWidgets('shows multiple linked entries preview', (tester) async {
      final task = createTask();
      final links = [
        createEntryLink('test-task-id', 'linked-entry-1'),
        createEntryLink('test-task-id', 'linked-entry-2'),
        createEntryLink('test-task-id', 'linked-entry-3'),
      ];

      await tester.pumpWidget(
        createTestWidget(
          overrides: [
            linkedEntriesControllerProvider(id: 'test-task-id').overrideWith(
              () => TestLinkedEntriesController(links),
            ),
            includeAiEntriesControllerProvider(id: 'test-task-id').overrideWith(
              () => TestIncludeAiEntriesController(value: true),
            ),
          ],
          child: CollapsibleLinkedEntriesSection(
            task: task,
            scrollController: scrollController,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byIcon(MdiIcons.linkVariant), findsOneWidget);
      expect(find.text('Linked Entries'), findsOneWidget);
      expect(find.text('3 linked entries'), findsOneWidget);
    });

    testWidgets('shows "tap to view all" for more than 3 entries',
        (tester) async {
      final task = createTask();
      final links = List.generate(
        5,
        (index) => createEntryLink('test-task-id', 'linked-entry-$index'),
      );

      await tester.pumpWidget(
        createTestWidget(
          overrides: [
            linkedEntriesControllerProvider(id: 'test-task-id').overrideWith(
              () => TestLinkedEntriesController(links),
            ),
            includeAiEntriesControllerProvider(id: 'test-task-id').overrideWith(
              () => TestIncludeAiEntriesController(value: true),
            ),
          ],
          child: CollapsibleLinkedEntriesSection(
            task: task,
            scrollController: scrollController,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('5 linked entries'), findsOneWidget);
      expect(find.text('Tap to view all'), findsOneWidget);
    });

    testWidgets('shows collapsible task section widget', (tester) async {
      final task = createTask();
      final link = createEntryLink('test-task-id', 'linked-entry-1');

      await tester.pumpWidget(
        createTestWidget(
          overrides: [
            linkedEntriesControllerProvider(id: 'test-task-id').overrideWith(
              () => TestLinkedEntriesController([link]),
            ),
            includeAiEntriesControllerProvider(id: 'test-task-id').overrideWith(
              () => TestIncludeAiEntriesController(value: true),
            ),
          ],
          child: CollapsibleLinkedEntriesSection(
            task: task,
            scrollController: scrollController,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(CollapsibleTaskSection), findsOneWidget);
    });
  });
}
