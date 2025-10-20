import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/event_data.dart';
import 'package:lotti/classes/event_status.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/journal/ui/widgets/create/create_entry_items.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/utils/consts.dart';
import 'package:lotti/widgets/modal/modern_modal_entry_type_item.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../mocks/mocks.dart';
import '../../../../../widget_test_utils.dart';

class MockPersistenceLogic extends Mock implements PersistenceLogic {}

class MockJournalDb extends Mock implements JournalDb {}

void main() {
  group('Navigation Tests Setup', () {
    late MockNavService mockNavService;
    late MockPersistenceLogic mockPersistenceLogic;
    late MockJournalDb mockDb;

    setUpAll(() {
      registerFallbackValue(StackTrace.empty);
      registerFallbackValue(const EventData(
        title: '',
        status: EventStatus.tentative,
        stars: 0,
      ));
      registerFallbackValue(const EntryText(plainText: ''));
    });

    setUp(() {
      mockNavService = MockNavService();
      mockPersistenceLogic = MockPersistenceLogic();
      mockDb = MockJournalDb();

      // Mock watchConfigFlags to return enableEventsFlag: true for these tests
      when(() => mockDb.watchConfigFlags()).thenAnswer(
        (_) => Stream<Set<ConfigFlag>>.fromIterable([
          {
            const ConfigFlag(
              name: enableEventsFlag,
              description: 'Enable Events?',
              status: true,
            ),
          },
        ]),
      );

      getIt
        ..registerSingleton<NavService>(mockNavService)
        ..registerSingleton<PersistenceLogic>(mockPersistenceLogic)
        ..registerSingleton<JournalDb>(mockDb);
    });

    tearDown(getIt.reset);

    group('ModernCreateTaskItem Tests', () {
      testWidgets('renders task item correctly', (tester) async {
        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            const CreateTaskItem(
              'linked-id',
              categoryId: 'category-id',
            ),
          ),
        );

        // Verify the task item is rendered
        expect(find.byType(ModernModalEntryTypeItem), findsOneWidget);
        expect(find.text('Task'), findsOneWidget);
        expect(find.byIcon(Icons.task_alt_rounded), findsOneWidget);
      });

      testWidgets('shows task item in modal', (tester) async {
        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            Builder(
              builder: (context) => Column(
                children: [
                  ElevatedButton(
                    onPressed: () {
                      showModalBottomSheet<void>(
                        context: context,
                        builder: (_) => const CreateTaskItem(
                          'linked-id',
                          categoryId: 'category-id',
                        ),
                      );
                    },
                    child: const Text('Show Modal'),
                  ),
                ],
              ),
            ),
          ),
        );

        // Open the modal
        await tester.tap(find.text('Show Modal'));
        await tester.pumpAndSettle();

        // Verify the task item is shown
        expect(find.byType(ModernModalEntryTypeItem), findsOneWidget);
        expect(find.text('Task'), findsOneWidget);
        expect(find.byIcon(Icons.task_alt_rounded), findsOneWidget);
      });
    });

    group('CreateEventItem Navigation Tests', () {
      testWidgets('navigates to event after creation when not linked',
          (tester) async {
        const testEventId = 'test-event-id';
        final testEvent = JournalEvent(
          meta: Metadata(
            id: testEventId,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            dateFrom: DateTime.now(),
            dateTo: DateTime.now(),
          ),
          data: const EventData(
            title: 'Test Event',
            status: EventStatus.tentative,
            stars: 0,
          ),
        );

        // Mock the persistence logic to return our test event
        when(() => mockPersistenceLogic.createEventEntry(
              data: any(named: 'data'),
              entryText: any(named: 'entryText'),
              linkedId: any(named: 'linkedId'),
              categoryId: any(named: 'categoryId'),
            )).thenAnswer((_) async => testEvent);

        // Track navigation calls
        var navCalled = false;
        String? navPath;
        when(() => mockNavService.beamToNamed(any())).thenAnswer((invocation) {
          navCalled = true;
          navPath = invocation.positionalArguments[0] as String;
        });

        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            const CreateEventItem(
              null, // no linkedId
              categoryId: 'test-category',
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Tap the event creation item
        await tester.tap(find.byType(ModernModalEntryTypeItem));
        await tester.pumpAndSettle();

        // Verify navigation was called with the correct path
        expect(navCalled, true);
        expect(navPath, '/journal/$testEventId');
      });

      testWidgets('navigates to event after creation with linked ID',
          (tester) async {
        const testEventId = 'test-event-id';
        const linkedFromId = 'linked-entry-id';
        final testEvent = JournalEvent(
          meta: Metadata(
            id: testEventId,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            dateFrom: DateTime.now(),
            dateTo: DateTime.now(),
          ),
          data: const EventData(
            title: 'Test Event',
            status: EventStatus.tentative,
            stars: 0,
          ),
        );

        // Mock the persistence logic to return our test event
        when(() => mockPersistenceLogic.createEventEntry(
              data: any(named: 'data'),
              entryText: any(named: 'entryText'),
              linkedId: any(named: 'linkedId'),
              categoryId: any(named: 'categoryId'),
            )).thenAnswer((_) async => testEvent);

        // Track navigation calls
        var navCalled = false;
        String? navPath;
        when(() => mockNavService.beamToNamed(any())).thenAnswer((invocation) {
          navCalled = true;
          navPath = invocation.positionalArguments[0] as String;
        });

        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            const CreateEventItem(
              linkedFromId,
              categoryId: 'test-category',
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Tap the event creation item
        await tester.tap(find.byType(ModernModalEntryTypeItem));
        await tester.pumpAndSettle();

        // Verify navigation was called even with linked ID
        expect(navCalled, true);
        expect(navPath, '/journal/$testEventId');
      });

      testWidgets('does not navigate when event creation fails',
          (tester) async {
        // Mock the persistence logic to return null (failure)
        when(() => mockPersistenceLogic.createEventEntry(
              data: any(named: 'data'),
              entryText: any(named: 'entryText'),
              linkedId: any(named: 'linkedId'),
              categoryId: any(named: 'categoryId'),
            )).thenAnswer((_) async => null);

        // Track navigation calls
        var navCalled = false;
        when(() => mockNavService.beamToNamed(any())).thenAnswer((invocation) {
          navCalled = true;
        });

        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            const CreateEventItem(
              null,
              categoryId: 'test-category',
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Tap the event creation item
        await tester.tap(find.byType(ModernModalEntryTypeItem));
        await tester.pumpAndSettle();

        // Verify navigation was not called
        expect(navCalled, false);
      });
    });
  });

  group('ModernCreateEventItem Tests', () {
    late MockJournalDb mockDb;

    setUp(() {
      mockDb = MockJournalDb();

      // Mock watchConfigFlags to return enableEventsFlag: true
      when(() => mockDb.watchConfigFlags()).thenAnswer(
        (_) => Stream<Set<ConfigFlag>>.fromIterable([
          {
            const ConfigFlag(
              name: enableEventsFlag,
              description: 'Enable Events?',
              status: true,
            ),
          },
        ]),
      );

      getIt.registerSingleton<JournalDb>(mockDb);
    });

    tearDown(() async {
      await getIt.reset();
    });

    testWidgets('renders correctly', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const CreateEventItem(
            'linked-id',
            categoryId: 'category-id',
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify the event item is rendered
      expect(find.byType(ModernModalEntryTypeItem), findsOneWidget);
      expect(find.text('Event'), findsOneWidget);
      expect(find.byIcon(Icons.event_rounded), findsOneWidget);
    });
  });

  group('ModernCreateAudioItem Tests', () {
    testWidgets('renders correctly', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const CreateAudioItem(
            'linked-id',
            categoryId: 'category-id',
          ),
        ),
      );

      // Verify the audio item is rendered
      expect(find.byType(ModernModalEntryTypeItem), findsOneWidget);
      expect(find.text('Audio'), findsOneWidget);
      expect(find.byIcon(Icons.mic_none_rounded), findsOneWidget);
    });
  });

  // ModernCreateTimerItem requires GetIt services and EntryController
  // which makes it more complex to test. Consider integration tests
  // or a more complete test setup for this widget.

  group('ModernCreateTextItem Tests', () {
    testWidgets('renders correctly', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const CreateTextItem(
            'linked-id',
            categoryId: 'category-id',
          ),
        ),
      );

      // Verify the text item is rendered
      expect(find.byType(ModernModalEntryTypeItem), findsOneWidget);
      expect(find.text('Text'), findsOneWidget);
      expect(find.byIcon(Icons.notes_rounded), findsOneWidget);
    });
  });

  group('ModernImportImageItem Tests', () {
    testWidgets('renders correctly', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const ImportImageItem(
            'linked-id',
            categoryId: 'category-id',
          ),
        ),
      );

      // Verify the import image item is rendered
      expect(find.byType(ModernModalEntryTypeItem), findsOneWidget);
      expect(find.text('Import Image'), findsOneWidget);
      expect(find.byIcon(Icons.photo_library_rounded), findsOneWidget);
    });
  });

  group('ModernCreateScreenshotItem Tests', () {
    testWidgets('renders correctly', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const CreateScreenshotItem(
            'linked-id',
            categoryId: 'category-id',
          ),
        ),
      );

      // Verify the screenshot item is rendered
      expect(find.byType(ModernModalEntryTypeItem), findsOneWidget);
      expect(find.text('Screenshot'), findsOneWidget);
      expect(find.byIcon(Icons.screenshot_monitor_rounded), findsOneWidget);
    });
  });

  group('CreateEventItem Flag Tests', () {
    late MockJournalDb mockDb;

    setUp(() {
      mockDb = MockJournalDb();
    });

    tearDown(() async {
      await getIt.reset();
    });

    testWidgets('hides Event item when enableEventsFlag is OFF',
        (tester) async {
      // Mock JournalDb.watchConfigFlags() to return enableEventsFlag: false
      when(() => mockDb.watchConfigFlags()).thenAnswer(
        (_) => Stream<Set<ConfigFlag>>.fromIterable([
          {
            const ConfigFlag(
              name: enableEventsFlag,
              description: 'Enable Events?',
              status: false,
            ),
          },
        ]),
      );

      getIt.registerSingleton<JournalDb>(mockDb);

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const CreateEventItem(
            'linked-id',
            categoryId: 'category-id',
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Assert: SizedBox.shrink() behavior (ModernModalEntryTypeItem not found)
      expect(find.byType(ModernModalEntryTypeItem), findsNothing);
      expect(find.text('Event'), findsNothing);
    });

    testWidgets('shows Event item when enableEventsFlag is ON', (tester) async {
      // Mock JournalDb.watchConfigFlags() to return enableEventsFlag: true
      when(() => mockDb.watchConfigFlags()).thenAnswer(
        (_) => Stream<Set<ConfigFlag>>.fromIterable([
          {
            const ConfigFlag(
              name: enableEventsFlag,
              description: 'Enable Events?',
              status: true,
            ),
          },
        ]),
      );

      getIt.registerSingleton<JournalDb>(mockDb);

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const CreateEventItem(
            'linked-id',
            categoryId: 'category-id',
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Assert: ModernModalEntryTypeItem is found
      expect(find.byType(ModernModalEntryTypeItem), findsOneWidget);
      // Assert: 'Event' text is found
      expect(find.text('Event'), findsOneWidget);
      // Assert: Icons.event_rounded is found
      expect(find.byIcon(Icons.event_rounded), findsOneWidget);
    });

    testWidgets('defaults to hidden when flag data is null/empty',
        (tester) async {
      // Mock stream returns empty set
      when(() => mockDb.watchConfigFlags()).thenAnswer(
        (_) => Stream<Set<ConfigFlag>>.fromIterable([{}]),
      );

      getIt.registerSingleton<JournalDb>(mockDb);

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const CreateEventItem(
            'linked-id',
            categoryId: 'category-id',
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Assert: Widget is hidden (defaults to false)
      expect(find.byType(ModernModalEntryTypeItem), findsNothing);
      expect(find.text('Event'), findsNothing);
    });
  });
}
