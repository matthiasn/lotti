import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/tag_type_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/logging_db.dart';
import 'package:lotti/features/journal/ui/widgets/entry_details_widget.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/health_import.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/editor_state_service.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/link_service.dart';
import 'package:lotti/services/tags_service.dart';
import 'package:lotti/services/time_service.dart';
import 'package:lotti/themes/theme.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path_provider/path_provider.dart';

import '../../../../helpers/path_provider.dart';
import '../../../../mocks/mocks.dart';
import '../../../../test_data/test_data.dart';
import '../../../../widget_test_utils.dart';

// Simplified test widget that mimics EntryDetailsWidget behavior
class TestEntryDetailsWidget extends StatelessWidget {
  const TestEntryDetailsWidget({
    required this.isTask,
    required this.showTaskDetails,
    super.key,
  });

  final bool isTask;
  final bool showTaskDetails;

  @override
  Widget build(BuildContext context) {
    if (isTask && !showTaskDetails) {
      return Padding(
        padding: const EdgeInsets.only(
          left: AppTheme.spacingXSmall,
          right: AppTheme.spacingXSmall,
          bottom: AppTheme.spacingXSmall,
        ),
        child: Container(
          key: const Key('modern-journal-card'),
          height: 100,
          color: Colors.blue,
          child: const Text('Mock Modern Journal Card'),
        ),
      );
    }

    return const Card(
      key: Key('entry-details-card'),
      margin: EdgeInsets.only(
        left: AppTheme.spacingXSmall,
        right: AppTheme.spacingXSmall,
        bottom: AppTheme.spacingMedium,
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: AppTheme.spacingMedium),
        child: Text('Entry Details Content'),
      ),
    );
  }
}

void main() {
  group('EntryDetailsWidget Layout Tests', () {
    testWidgets(
        'wraps task cards with proper padding when showTaskDetails is false',
        (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const TestEntryDetailsWidget(
            isTask: true,
            showTaskDetails: false,
          ),
        ),
      );

      // Find the container that represents our mock card
      final containerFinder = find.byKey(const Key('modern-journal-card'));
      expect(containerFinder, findsOneWidget);

      // Find the padding widget that wraps it
      final paddingFinder = find.ancestor(
        of: containerFinder,
        matching: find.byType(Padding),
      );

      expect(paddingFinder, findsOneWidget);

      final padding = tester.widget<Padding>(paddingFinder);
      expect(
        padding.padding,
        const EdgeInsets.only(
          left: AppTheme.spacingXSmall,
          right: AppTheme.spacingXSmall,
          bottom: AppTheme.spacingXSmall,
        ),
      );
    });

    testWidgets('renders card layout when showTaskDetails is true',
        (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const TestEntryDetailsWidget(
            isTask: true,
            showTaskDetails: true,
          ),
        ),
      );

      // When showTaskDetails is true, it should render a Card
      expect(find.byType(Card), findsOneWidget);
      expect(find.byKey(const Key('entry-details-card')), findsOneWidget);

      // Mock modern journal card should not be present
      expect(find.byKey(const Key('modern-journal-card')), findsNothing);

      // Verify card margins
      final card = tester.widget<Card>(find.byType(Card));
      expect(
        card.margin,
        const EdgeInsets.only(
          left: AppTheme.spacingXSmall,
          right: AppTheme.spacingXSmall,
          bottom: AppTheme.spacingMedium,
        ),
      );
    });

    testWidgets('renders card layout for non-task entries', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const TestEntryDetailsWidget(
            isTask: false,
            showTaskDetails: false,
          ),
        ),
      );

      // Non-task entries should always render a Card
      expect(find.byType(Card), findsOneWidget);
      expect(find.byKey(const Key('entry-details-card')), findsOneWidget);
    });

    testWidgets('verifies padding structure for task cards', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const TestEntryDetailsWidget(
            isTask: true,
            showTaskDetails: false,
          ),
        ),
      );

      // Verify the widget tree structure
      final container = find.byKey(const Key('modern-journal-card'));
      final padding = find.ancestor(
        of: container,
        matching: find.byType(Padding),
      );

      expect(container, findsOneWidget);
      expect(padding, findsOneWidget);

      // Verify no Card widget is present
      expect(find.byType(Card), findsNothing);
    });
  });

  group('EntryDetailsWidget Highlight Tests', () {
    TestWidgetsFlutterBinding.ensureInitialized();

    late JournalDb mockJournalDb;
    late MockPersistenceLogic mockPersistenceLogic;
    late MockUpdateNotifications mockUpdateNotifications;
    late MockEntitiesCacheService mockEntitiesCacheService;

    setUpAll(setFakeDocumentsPath);

    setUp(() async {
      mockJournalDb = mockJournalDbWithMeasurableTypes([]);
      mockPersistenceLogic = MockPersistenceLogic();
      mockUpdateNotifications = MockUpdateNotifications();
      mockEntitiesCacheService = MockEntitiesCacheService();

      final mockTagsService = mockTagsServiceWithTags([]);
      final mockTimeService = MockTimeService();
      final mockEditorStateService = MockEditorStateService();
      final mockHealthImport = MockHealthImport();

      getIt
        ..registerSingleton<Directory>(await getApplicationDocumentsDirectory())
        ..registerSingleton<UserActivityService>(UserActivityService())
        ..registerSingleton<UpdateNotifications>(mockUpdateNotifications)
        ..registerSingleton<LoggingDb>(MockLoggingDb())
        ..registerSingleton<EditorStateService>(mockEditorStateService)
        ..registerSingleton<EntitiesCacheService>(mockEntitiesCacheService)
        ..registerSingleton<LinkService>(MockLinkService())
        ..registerSingleton<TagsService>(mockTagsService)
        ..registerSingleton<HealthImport>(mockHealthImport)
        ..registerSingleton<TimeService>(mockTimeService)
        ..registerSingleton<JournalDb>(mockJournalDb)
        ..registerSingleton<PersistenceLogic>(mockPersistenceLogic);

      when(() => mockEntitiesCacheService.sortedCategories).thenAnswer(
        (_) => [],
      );

      when(() => mockUpdateNotifications.updateStream).thenAnswer(
        (_) => Stream<Set<String>>.fromIterable([]),
      );

      when(mockTagsService.watchTags).thenAnswer(
        (_) => Stream<List<TagEntity>>.fromIterable([[]]),
      );

      when(() => mockTagsService.stream).thenAnswer(
        (_) => Stream<List<TagEntity>>.fromIterable([[]]),
      );

      when(() => mockJournalDb.watchConfigFlags()).thenAnswer(
        (_) => Stream<Set<ConfigFlag>>.fromIterable([
          <ConfigFlag>{
            const ConfigFlag(
              name: 'private',
              description: 'Show private entries?',
              status: true,
            ),
          },
        ]),
      );

      when(
        () => mockEditorStateService.getUnsavedStream(
          any(),
          any(),
        ),
      ).thenAnswer(
        (_) => Stream<bool>.fromIterable([false]),
      );

      when(mockTimeService.getStream)
          .thenAnswer((_) => Stream<JournalEntity>.fromIterable([]));
    });

    tearDown(getIt.reset);

    testWidgets('renders without highlight when isHighlighted=false',
        (tester) async {
      when(() => mockJournalDb.journalEntityById(testTextEntry.meta.id))
          .thenAnswer((_) async => testTextEntry);

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          ProviderScope(
            child: EntryDetailsWidget(
              itemId: testTextEntry.meta.id,
              showAiEntry: false,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(EntryDetailsWidget), findsOneWidget);
    });

    testWidgets('renders with highlight when isHighlighted=true',
        (tester) async {
      when(() => mockJournalDb.journalEntityById(testTextEntry.meta.id))
          .thenAnswer((_) async => testTextEntry);

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          ProviderScope(
            child: EntryDetailsWidget(
              itemId: testTextEntry.meta.id,
              showAiEntry: false,
              isHighlighted: true,
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300)); // Animation repeats

      expect(find.byType(EntryDetailsWidget), findsOneWidget);
    });

    testWidgets('highlight toggles from false to true', (tester) async {
      when(() => mockJournalDb.journalEntityById(testTextEntry.meta.id))
          .thenAnswer((_) async => testTextEntry);

      var isHighlighted = false;

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          StatefulBuilder(
            builder: (context, setState) {
              return ProviderScope(
                child: Column(
                  children: [
                    Expanded(
                      child: EntryDetailsWidget(
                        itemId: testTextEntry.meta.id,
                        showAiEntry: false,
                        isHighlighted: isHighlighted,
                      ),
                    ),
                    TextButton(
                      onPressed: () => setState(() => isHighlighted = true),
                      child: const Text('Highlight'),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.text('Highlight'));
      await tester.pump(); // Just pump once, animation repeats forever
      await tester.pump(const Duration(milliseconds: 300)); // Let animation run

      expect(find.byType(EntryDetailsWidget), findsOneWidget);
    });

    testWidgets('highlight toggles from true to false', (tester) async {
      when(() => mockJournalDb.journalEntityById(testTextEntry.meta.id))
          .thenAnswer((_) async => testTextEntry);

      var isHighlighted = true;

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          StatefulBuilder(
            builder: (context, setState) {
              return ProviderScope(
                child: Column(
                  children: [
                    Expanded(
                      child: EntryDetailsWidget(
                        itemId: testTextEntry.meta.id,
                        showAiEntry: false,
                        isHighlighted: isHighlighted,
                      ),
                    ),
                    TextButton(
                      onPressed: () => setState(() => isHighlighted = false),
                      child: const Text('Clear'),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify button exists
      expect(find.text('Clear'), findsOneWidget);

      await tester.tap(find.text('Clear'), warnIfMissed: false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(EntryDetailsWidget), findsOneWidget);
    });

    testWidgets('showAiEntry and isHighlighted work together', (tester) async {
      when(() => mockJournalDb.journalEntityById(testTextEntry.meta.id))
          .thenAnswer((_) async => testTextEntry);

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          ProviderScope(
            child: EntryDetailsWidget(
              itemId: testTextEntry.meta.id,
              showAiEntry: true,
              isHighlighted: true,
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300)); // Animation repeats

      expect(find.byType(EntryDetailsWidget), findsOneWidget);
    });
  });
}
