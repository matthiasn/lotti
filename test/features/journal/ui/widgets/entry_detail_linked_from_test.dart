import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/project_data.dart';
import 'package:lotti/classes/relationship_data.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/journal/ui/widgets/entry_detail_linked_from.dart';
import 'package:lotti/features/journal/ui/widgets/list_cards/journal_card.dart';
import 'package:lotti/features/journal/ui/widgets/list_cards/journal_image_card.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/health_import.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/editor_state_service.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/link_service.dart';
import 'package:lotti/services/time_service.dart';
import 'package:material_ui/material_ui.dart';
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
  } else if (entity is ProjectEntry) {
    type = 'ProjectEntry';
  } else if (entity is RelationshipEntry) {
    type = 'Relationship';
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

void main() {
  group('LinkedFromEntriesWidget', () {
    TestWidgetsFlutterBinding.ensureInitialized();

    late MockJournalDb mockJournalDb;
    late MockEntitiesCacheService mockEntitiesCacheService;

    setUpAll(setFakeDocumentsPath);

    setUp(() async {
      mockJournalDb = mockJournalDbWithMeasurableTypes([]);
      mockEntitiesCacheService = MockEntitiesCacheService();
      final mockPersistenceLogic = MockPersistenceLogic();
      final mockUpdateNotifications = MockUpdateNotifications();
      final mockTimeService = MockTimeService();
      final mockEditorStateService = MockEditorStateService();
      final mockHealthImport = MockHealthImport();

      getIt
        ..registerSingleton<Directory>(await getApplicationDocumentsDirectory())
        ..registerSingleton<UserActivityService>(UserActivityService())
        ..registerSingleton<UpdateNotifications>(mockUpdateNotifications)
        ..registerSingleton<EditorStateService>(mockEditorStateService)
        ..registerSingleton<EntitiesCacheService>(mockEntitiesCacheService)
        ..registerSingleton<LinkService>(MockLinkService())
        ..registerSingleton<HealthImport>(mockHealthImport)
        ..registerSingleton<TimeService>(mockTimeService)
        ..registerSingleton<JournalDb>(mockJournalDb)
        ..registerSingleton<PersistenceLogic>(mockPersistenceLogic);

      when(() => mockEntitiesCacheService.sortedCategories).thenReturn([]);
      when(
        () => mockEntitiesCacheService.getCategoryById(any()),
      ).thenReturn(null);
      when(() => mockEntitiesCacheService.showPrivateEntries).thenReturn(true);
      when(() => mockEntitiesCacheService.getLabelById(any())).thenReturn(null);

      when(() => mockUpdateNotifications.updateStream).thenAnswer(
        (_) => Stream<Set<String>>.fromIterable([]),
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

      when(
        mockTimeService.getStream,
      ).thenAnswer((_) => Stream<JournalEntity>.fromIterable([]));
    });

    tearDown(getIt.reset);

    void mockLinkedFromEntries(List<JournalEntity> entries) {
      final dbEntries = entries.map(_journalDbEntity).toList();
      when(
        () => mockJournalDb.getLinkedToEntities(any()),
      ).thenAnswer((_) async => dbEntries);
    }

    testWidgets('shows label when entries exist', (tester) async {
      mockLinkedFromEntries([testTextEntry]);

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          LinkedFromEntriesWidget(testTask),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Linked from:'), findsOneWidget);
    });

    testWidgets('renders a linked image as an image card and other entries '
        'as journal cards', (tester) async {
      mockLinkedFromEntries([testImageEntry, testTextEntry]);

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          LinkedFromEntriesWidget(testTask),
        ),
      );
      await tester.pumpAndSettle();

      final imageCard = tester.widget<ModernJournalImageCard>(
        find.byType(ModernJournalImageCard),
      );
      expect(imageCard.item, testImageEntry);
      final textCard = tester.widget<ModernJournalCard>(
        find.byType(ModernJournalCard),
      );
      expect(textCard.item, testTextEntry);
      expect(textCard.showLinkedDuration, isTrue);
    });

    testWidgets('renders SizedBox.shrink when no entries', (tester) async {
      mockLinkedFromEntries([]);

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          LinkedFromEntriesWidget(testTask),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Linked from:'), findsNothing);
    });

    testWidgets('filters task entries when hideTaskEntries is true', (
      tester,
    ) async {
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

      expect(find.text('Linked from:'), findsNothing);
    });

    ProjectEntry buildProject(String id) {
      final now = DateTime(2026, 5, 5, 21);
      return ProjectEntry(
        meta: Metadata(
          id: id,
          createdAt: now,
          updatedAt: now,
          dateFrom: now,
          dateTo: now,
        ),
        data: ProjectData(
          title: 'Demo project',
          status: ProjectStatus.active(
            id: 'project-status-$id',
            createdAt: now,
            utcOffset: 0,
          ),
          dateFrom: now,
          dateTo: now,
        ),
      );
    }

    testWidgets('hides ProjectEntry when it is the only linked entry', (
      tester,
    ) async {
      mockLinkedFromEntries([buildProject('project-only')]);
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          LinkedFromEntriesWidget(testTask),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Linked from:'), findsNothing);
    });

    testWidgets('hides ProjectEntry but keeps other linked entries', (
      tester,
    ) async {
      mockLinkedFromEntries([buildProject('project-mixed'), testTextEntry]);
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          LinkedFromEntriesWidget(testTask),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Linked from:'), findsOneWidget);
      expect(find.text('Demo project'), findsNothing);
      // The non-project linked entry must still render — without this
      // assertion the test would pass even if every entry got filtered out.
      expect(find.byKey(ValueKey(testTextEntry.meta.id)), findsOneWidget);
    });

    RelationshipEntry buildRelationship(String id) {
      final now = DateTime(2026, 5, 5, 21);
      return RelationshipEntry(
        meta: Metadata(
          id: id,
          createdAt: now,
          updatedAt: now,
          dateFrom: now,
          dateTo: now,
        ),
        data: RelationshipData(
          title: 'Anna Example',
          status: RelationshipStatus.active(
            id: 'relationship-status-$id',
            createdAt: now,
            utcOffset: 0,
          ),
        ),
      );
    }

    testWidgets(
      'hides RelationshipEntry but keeps other linked entries — a person '
      'links many tasks and owns a page this card cannot route to',
      (tester) async {
        mockLinkedFromEntries([
          buildRelationship('relationship-mixed'),
          testTextEntry,
        ]);
        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            LinkedFromEntriesWidget(testTask),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Linked from:'), findsOneWidget);
        expect(find.text('Anna Example'), findsNothing);
        expect(find.byKey(ValueKey(testTextEntry.meta.id)), findsOneWidget);
      },
    );
  });
}
