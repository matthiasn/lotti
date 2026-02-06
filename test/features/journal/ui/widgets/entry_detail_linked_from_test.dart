import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/tag_type_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/logging_db.dart';
import 'package:lotti/features/journal/ui/widgets/entry_detail_linked_from.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
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

JournalDbEntity _journalDbEntity(JournalEntity entity) {
  String type;
  if (entity is JournalEntry) {
    type = 'JournalEntry';
  } else if (entity is JournalImage) {
    type = 'JournalImage';
  } else if (entity is JournalAudio) {
    type = 'JournalAudio';
  } else if (entity is Task) {
    type = 'Task';
  } else {
    type = 'JournalEntry';
  }
  return JournalDbEntity(
    id: entity.meta.id,
    createdAt: entity.meta.createdAt,
    updatedAt: entity.meta.updatedAt,
    dateFrom: entity.meta.dateFrom,
    dateTo: entity.meta.dateTo,
    deleted: false,
    starred: entity.meta.starred ?? false,
    private: entity.meta.private ?? false,
    task: entity is Task,
    flag: 0,
    type: type,
    serialized: jsonEncode(entity),
    schemaVersion: 1,
    category: '',
  );
}

// Simple widget that mimics LinkedFromEntriesWidget structure for testing
class TestLinkedFromWidget extends StatelessWidget {
  const TestLinkedFromWidget({
    required this.hasData,
    required this.hasImageEntries,
    super.key,
  });

  final bool hasData;
  final bool hasImageEntries;

  @override
  Widget build(BuildContext context) {
    if (!hasData) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        Text(
          context.messages.journalLinkedFromLabel,
          style: context.textTheme.titleSmall
              ?.copyWith(color: context.colorScheme.outline),
        ),
        if (hasImageEntries)
          Padding(
            padding: const EdgeInsets.only(
              left: AppTheme.spacingXSmall,
              right: AppTheme.spacingXSmall,
              bottom: AppTheme.spacingXSmall,
            ),
            child: Container(
              key: const ValueKey('image-1'),
              height: 100,
              color: Colors.grey,
              child: const Text('Mock Image Card'),
            ),
          ),
        if (!hasImageEntries)
          Padding(
            padding: const EdgeInsets.only(
              left: AppTheme.spacingXSmall,
              right: AppTheme.spacingXSmall,
              bottom: AppTheme.spacingXSmall,
            ),
            child: Container(
              key: const ValueKey('text-1'),
              height: 80,
              color: Colors.blue,
              child: const Text('Mock Journal Card'),
            ),
          ),
      ],
    );
  }
}

void main() {
  group('LinkedFromWidget Structure Tests', () {
    testWidgets('renders correctly with image entries', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const TestLinkedFromWidget(
            hasData: true,
            hasImageEntries: true,
          ),
        ),
      );

      // Verify the section title is rendered
      expect(find.text('Linked from:'), findsOneWidget);

      // Verify image container is rendered with correct key
      expect(find.byKey(const ValueKey('image-1')), findsOneWidget);

      // Verify padding is applied correctly
      final padding = tester.widget<Padding>(
        find
            .ancestor(
              of: find.byKey(const ValueKey('image-1')),
              matching: find.byType(Padding),
            )
            .first,
      );

      expect(
        padding.padding,
        const EdgeInsets.only(
          left: AppTheme.spacingXSmall,
          right: AppTheme.spacingXSmall,
          bottom: AppTheme.spacingXSmall,
        ),
      );
    });

    testWidgets('renders correctly with regular entries', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const TestLinkedFromWidget(
            hasData: true,
            hasImageEntries: false,
          ),
        ),
      );

      // Verify the section title is rendered
      expect(find.text('Linked from:'), findsOneWidget);

      // Verify text container is rendered with correct key
      expect(find.byKey(const ValueKey('text-1')), findsOneWidget);

      // Verify padding is applied correctly
      final padding = tester.widget<Padding>(
        find
            .ancestor(
              of: find.byKey(const ValueKey('text-1')),
              matching: find.byType(Padding),
            )
            .first,
      );

      expect(
        padding.padding,
        const EdgeInsets.only(
          left: AppTheme.spacingXSmall,
          right: AppTheme.spacingXSmall,
          bottom: AppTheme.spacingXSmall,
        ),
      );
    });

    testWidgets('renders empty when no data', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const TestLinkedFromWidget(
            hasData: false,
            hasImageEntries: false,
          ),
        ),
      );

      // Empty list should show nothing
      expect(find.text('Linked from:'), findsNothing);
      expect(find.byKey(const ValueKey('image-1')), findsNothing);
      expect(find.byKey(const ValueKey('text-1')), findsNothing);
    });
  });

  group('LinkedFromEntriesWidget Collapsible Tests', () {
    TestWidgetsFlutterBinding.ensureInitialized();

    late MockJournalDb mockJournalDb;
    late MockEntitiesCacheService mockEntitiesCacheService;

    setUpAll(setFakeDocumentsPath);

    setUp(() async {
      mockJournalDb = mockJournalDbWithMeasurableTypes([]);
      mockEntitiesCacheService = MockEntitiesCacheService();
      final mockPersistenceLogic = MockPersistenceLogic();
      final mockUpdateNotifications = MockUpdateNotifications();
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

      when(() => mockEntitiesCacheService.sortedCategories).thenReturn([]);
      when(() => mockEntitiesCacheService.getCategoryById(any()))
          .thenReturn(null);
      when(() => mockEntitiesCacheService.showPrivateEntries).thenReturn(true);
      when(() => mockEntitiesCacheService.getLabelById(any())).thenReturn(null);

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
        () => mockEditorStateService.getUnsavedStream(any(), any()),
      ).thenAnswer(
        (_) => Stream<bool>.fromIterable([false]),
      );

      when(mockTimeService.getStream)
          .thenAnswer((_) => Stream<JournalEntity>.fromIterable([]));
    });

    tearDown(getIt.reset);

    void mockLinkedFromEntries(List<JournalEntity> entries) {
      final dbEntries = entries.map(_journalDbEntity).toList();
      when(() => mockJournalDb.linkedToJournalEntities(any()))
          .thenReturn(MockSelectable<JournalDbEntity>(dbEntries));
    }

    testWidgets('shows chevron and label when entries exist', (tester) async {
      mockLinkedFromEntries([testTextEntry]);

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          LinkedFromEntriesWidget(testTask),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.expand_more), findsOneWidget);
      expect(find.text('Linked from:'), findsOneWidget);
    });

    testWidgets('shows AnimatedSize when entries exist', (tester) async {
      mockLinkedFromEntries([testTextEntry]);

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          LinkedFromEntriesWidget(testTask),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSize), findsOneWidget);
    });

    testWidgets('chevron is not rotated when expanded', (tester) async {
      mockLinkedFromEntries([testTextEntry]);

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          LinkedFromEntriesWidget(testTask),
        ),
      );
      await tester.pumpAndSettle();

      final rotation =
          tester.widget<AnimatedRotation>(find.byType(AnimatedRotation));
      expect(rotation.turns, equals(0.0));
    });

    testWidgets('tapping header collapses the section', (tester) async {
      mockLinkedFromEntries([testTextEntry]);

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          LinkedFromEntriesWidget(testTask),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.expand_more));
      await tester.pumpAndSettle();

      final rotation =
          tester.widget<AnimatedRotation>(find.byType(AnimatedRotation));
      expect(rotation.turns, equals(-0.25));
    });

    testWidgets('tapping header twice re-expands', (tester) async {
      mockLinkedFromEntries([testTextEntry]);

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          LinkedFromEntriesWidget(testTask),
        ),
      );
      await tester.pumpAndSettle();

      // Collapse
      await tester.tap(find.byIcon(Icons.expand_more));
      await tester.pumpAndSettle();

      // Re-expand
      await tester.tap(find.byIcon(Icons.expand_more));
      await tester.pumpAndSettle();

      final rotation =
          tester.widget<AnimatedRotation>(find.byType(AnimatedRotation));
      expect(rotation.turns, equals(0.0));
    });

    testWidgets('collapsed section shows SizedBox.shrink content',
        (tester) async {
      mockLinkedFromEntries([testTextEntry]);

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          LinkedFromEntriesWidget(testTask),
        ),
      );
      await tester.pumpAndSettle();

      // Collapse
      await tester.tap(find.byIcon(Icons.expand_more));
      await tester.pump();

      final animatedSize =
          tester.widget<AnimatedSize>(find.byType(AnimatedSize));
      expect(animatedSize.child, isA<SizedBox>());
    });

    testWidgets('renders SizedBox.shrink when no entries', (tester) async {
      mockLinkedFromEntries([]);

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          LinkedFromEntriesWidget(testTask),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.expand_more), findsNothing);
      expect(find.text('Linked from:'), findsNothing);
    });

    testWidgets('filters task entries when hideTaskEntries is true',
        (tester) async {
      // Only provide task entries - should render empty
      mockLinkedFromEntries([testTask]);

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          LinkedFromEntriesWidget(
            testTextEntry,
            hideTaskEntries: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // All entries were tasks, so section should be hidden
      expect(find.byIcon(Icons.expand_more), findsNothing);
    });
  });
}
