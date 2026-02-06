import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/tag_type_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/logging_db.dart';
import 'package:lotti/features/journal/ui/widgets/entry_details/entry_datetime_widget.dart';
import 'package:lotti/features/journal/ui/widgets/entry_details/header/entry_detail_header.dart';
import 'package:lotti/features/journal/ui/widgets/entry_details_widget.dart';
import 'package:lotti/features/journal/ui/widgets/entry_image_widget.dart';
import 'package:lotti/features/journal/ui/widgets/tags/tags_list_widget.dart';
import 'package:lotti/features/speech/ui/widgets/audio_player.dart';
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
import 'package:mocktail/mocktail.dart';
import 'package:path_provider/path_provider.dart';

import '../../../../helpers/path_provider.dart';
import '../../../../mocks/mocks.dart';
import '../../../../test_data/test_data.dart';
import '../../../../widget_test_utils.dart';

void main() {
  group('EntryDetailsWidget Collapsible Tests', () {
    TestWidgetsFlutterBinding.ensureInitialized();

    late JournalDb mockJournalDb;
    late MockPersistenceLogic mockPersistenceLogic;
    late MockUpdateNotifications mockUpdateNotifications;
    late MockEntitiesCacheService mockEntitiesCacheService;

    setUpAll(() {
      setFakeDocumentsPath();
      registerFallbackValue(
        EntryLink.basic(
          id: 'fallback',
          fromId: 'from',
          toId: 'to',
          createdAt: DateTime(2024),
          updatedAt: DateTime(2024),
          vectorClock: null,
        ),
      );
    });

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

    group('non-collapsible entries', () {
      testWidgets('text entry without link is NOT collapsible', (tester) async {
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

        // No collapse arrow should be shown for text entries
        expect(find.byIcon(Icons.expand_more), findsNothing);
      });

      testWidgets('image entry without linkedFrom is NOT collapsible',
          (tester) async {
        when(() => mockJournalDb.journalEntityById(testImageEntry.meta.id))
            .thenAnswer((_) async => testImageEntry);

        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            ProviderScope(
              child: EntryDetailsWidget(
                itemId: testImageEntry.meta.id,
                showAiEntry: false,
                // No linkedFrom = not in linked context
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.expand_more), findsNothing);
      });
    });

    group('collapsible image entry', () {
      final testLink = EntryLink.basic(
        id: 'link-1',
        fromId: testTask.meta.id,
        toId: testImageEntry.meta.id,
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024),
        vectorClock: null,
      );

      testWidgets('shows collapse arrow for image in linked context',
          (tester) async {
        when(() => mockJournalDb.journalEntityById(testImageEntry.meta.id))
            .thenAnswer((_) async => testImageEntry);

        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            ProviderScope(
              child: EntryDetailsWidget(
                itemId: testImageEntry.meta.id,
                showAiEntry: false,
                linkedFrom: testTask,
                link: testLink,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.expand_more), findsOneWidget);
      });

      testWidgets('shows AnimatedSize for collapsible entry', (tester) async {
        when(() => mockJournalDb.journalEntityById(testImageEntry.meta.id))
            .thenAnswer((_) async => testImageEntry);

        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            ProviderScope(
              child: EntryDetailsWidget(
                itemId: testImageEntry.meta.id,
                showAiEntry: false,
                linkedFrom: testTask,
                link: testLink,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(AnimatedSize), findsOneWidget);
      });

      testWidgets('does NOT show collapsible AnimatedSize for non-collapsible',
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

        // Non-collapsible entries don't use AnimatedSize for collapse
        expect(find.byIcon(Icons.expand_more), findsNothing);
      });

      testWidgets('AnimatedSize shows expanded content when not collapsed',
          (tester) async {
        when(() => mockJournalDb.journalEntityById(testImageEntry.meta.id))
            .thenAnswer((_) async => testImageEntry);

        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            ProviderScope(
              child: EntryDetailsWidget(
                itemId: testImageEntry.meta.id,
                showAiEntry: false,
                linkedFrom: testTask,
                link: testLink, // collapsed is null (expanded)
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final animatedSize =
            tester.widget<AnimatedSize>(find.byType(AnimatedSize));
        expect(animatedSize.child, isA<Column>());
      });

      testWidgets('AnimatedSize shows SizedBox.shrink when collapsed',
          (tester) async {
        final collapsedLink = testLink.copyWith(collapsed: true);

        when(() => mockJournalDb.journalEntityById(testImageEntry.meta.id))
            .thenAnswer((_) async => testImageEntry);

        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            ProviderScope(
              child: EntryDetailsWidget(
                itemId: testImageEntry.meta.id,
                showAiEntry: false,
                linkedFrom: testTask,
                link: collapsedLink,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final animatedSize =
            tester.widget<AnimatedSize>(find.byType(AnimatedSize));
        expect(animatedSize.child, isA<SizedBox>());
      });
    });

    group('collapsible audio entry', () {
      final testAudioLink = EntryLink.basic(
        id: 'link-audio',
        fromId: testTask.meta.id,
        toId: testAudioEntry.meta.id,
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024),
        vectorClock: null,
      );

      testWidgets('shows collapse arrow for audio in linked context',
          (tester) async {
        when(() => mockJournalDb.journalEntityById(testAudioEntry.meta.id))
            .thenAnswer((_) async => testAudioEntry);

        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            ProviderScope(
              child: EntryDetailsWidget(
                itemId: testAudioEntry.meta.id,
                showAiEntry: false,
                linkedFrom: testTask,
                link: testAudioLink,
              ),
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.byIcon(Icons.expand_more), findsOneWidget);
      });

      testWidgets('audio entry collapses with collapsed link', (tester) async {
        final collapsedLink = testAudioLink.copyWith(collapsed: true);

        when(() => mockJournalDb.journalEntityById(testAudioEntry.meta.id))
            .thenAnswer((_) async => testAudioEntry);

        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            ProviderScope(
              child: EntryDetailsWidget(
                itemId: testAudioEntry.meta.id,
                showAiEntry: false,
                linkedFrom: testTask,
                link: collapsedLink,
              ),
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        final animatedSize =
            tester.widget<AnimatedSize>(find.byType(AnimatedSize));
        expect(animatedSize.child, isA<SizedBox>());
      });
    });

    group('text entry in linked context', () {
      final textLink = EntryLink.basic(
        id: 'link-text',
        fromId: testTask.meta.id,
        toId: testTextEntry.meta.id,
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024),
        vectorClock: null,
      );

      testWidgets('text entry in linked context is NOT collapsible',
          (tester) async {
        when(() => mockJournalDb.journalEntityById(testTextEntry.meta.id))
            .thenAnswer((_) async => testTextEntry);

        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            ProviderScope(
              child: EntryDetailsWidget(
                itemId: testTextEntry.meta.id,
                showAiEntry: false,
                linkedFrom: testTask,
                link: textLink,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Text entries should NOT be collapsible, even in linked context
        expect(find.byIcon(Icons.expand_more), findsNothing);
      });
    });

    group('expanded content structure', () {
      final testLink = EntryLink.basic(
        id: 'link-struct',
        fromId: testTask.meta.id,
        toId: testImageEntry.meta.id,
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024),
        vectorClock: null,
      );

      testWidgets('expanded image entry shows EntryImageWidget',
          (tester) async {
        when(() => mockJournalDb.journalEntityById(testImageEntry.meta.id))
            .thenAnswer((_) async => testImageEntry);

        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            ProviderScope(
              child: EntryDetailsWidget(
                itemId: testImageEntry.meta.id,
                showAiEntry: false,
                linkedFrom: testTask,
                link: testLink,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(EntryImageWidget), findsOneWidget);
      });

      testWidgets('expanded image entry shows date under image',
          (tester) async {
        when(() => mockJournalDb.journalEntityById(testImageEntry.meta.id))
            .thenAnswer((_) async => testImageEntry);

        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            ProviderScope(
              child: EntryDetailsWidget(
                itemId: testImageEntry.meta.id,
                showAiEntry: false,
                linkedFrom: testTask,
                link: testLink,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // EntryDatetimeWidget should appear in expanded content
        expect(find.byType(EntryDatetimeWidget), findsAtLeastNWidgets(1));
      });

      testWidgets('collapsed image entry hides image and shows SizedBox.shrink',
          (tester) async {
        final collapsedLink = testLink.copyWith(collapsed: true);

        when(() => mockJournalDb.journalEntityById(testImageEntry.meta.id))
            .thenAnswer((_) async => testImageEntry);

        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            ProviderScope(
              child: EntryDetailsWidget(
                itemId: testImageEntry.meta.id,
                showAiEntry: false,
                linkedFrom: testTask,
                link: collapsedLink,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // AnimatedSize child is SizedBox.shrink when collapsed
        final animatedSize =
            tester.widget<AnimatedSize>(find.byType(AnimatedSize));
        expect(animatedSize.child, isA<SizedBox>());
      });

      testWidgets('expanded image entry shows TagsListWidget', (tester) async {
        when(() => mockJournalDb.journalEntityById(testImageEntry.meta.id))
            .thenAnswer((_) async => testImageEntry);

        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            ProviderScope(
              child: EntryDetailsWidget(
                itemId: testImageEntry.meta.id,
                showAiEntry: false,
                linkedFrom: testTask,
                link: testLink,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(TagsListWidget), findsOneWidget);
      });
    });

    group('expanded audio content structure', () {
      final testAudioLink = EntryLink.basic(
        id: 'link-audio-struct',
        fromId: testTask.meta.id,
        toId: testAudioEntry.meta.id,
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024),
        vectorClock: null,
      );

      testWidgets('expanded audio entry shows AudioPlayerWidget',
          (tester) async {
        when(() => mockJournalDb.journalEntityById(testAudioEntry.meta.id))
            .thenAnswer((_) async => testAudioEntry);

        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            ProviderScope(
              child: EntryDetailsWidget(
                itemId: testAudioEntry.meta.id,
                showAiEntry: false,
                linkedFrom: testTask,
                link: testAudioLink,
              ),
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.byType(AudioPlayerWidget), findsOneWidget);
      });

      testWidgets('expanded audio entry shows date under player',
          (tester) async {
        when(() => mockJournalDb.journalEntityById(testAudioEntry.meta.id))
            .thenAnswer((_) async => testAudioEntry);

        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            ProviderScope(
              child: EntryDetailsWidget(
                itemId: testAudioEntry.meta.id,
                showAiEntry: false,
                linkedFrom: testTask,
                link: testAudioLink,
              ),
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.byType(EntryDatetimeWidget), findsAtLeastNWidgets(1));
      });

      testWidgets('collapsed audio entry hides player content', (tester) async {
        final collapsedLink = testAudioLink.copyWith(collapsed: true);

        when(() => mockJournalDb.journalEntityById(testAudioEntry.meta.id))
            .thenAnswer((_) async => testAudioEntry);

        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            ProviderScope(
              child: EntryDetailsWidget(
                itemId: testAudioEntry.meta.id,
                showAiEntry: false,
                linkedFrom: testTask,
                link: collapsedLink,
              ),
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        final animatedSize =
            tester.widget<AnimatedSize>(find.byType(AnimatedSize));
        expect(animatedSize.child, isA<SizedBox>());
      });
    });

    group('collapse state from link', () {
      testWidgets('link with collapsed=null renders as expanded',
          (tester) async {
        final nullCollapsedLink = EntryLink.basic(
          id: 'link-null',
          fromId: testTask.meta.id,
          toId: testImageEntry.meta.id,
          createdAt: DateTime(2024),
          updatedAt: DateTime(2024),
          vectorClock: null,
          // collapsed not set -> null
        );

        when(() => mockJournalDb.journalEntityById(testImageEntry.meta.id))
            .thenAnswer((_) async => testImageEntry);

        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            ProviderScope(
              child: EntryDetailsWidget(
                itemId: testImageEntry.meta.id,
                showAiEntry: false,
                linkedFrom: testTask,
                link: nullCollapsedLink,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final animatedSize =
            tester.widget<AnimatedSize>(find.byType(AnimatedSize));
        expect(animatedSize.child, isA<Column>());
      });

      testWidgets('link with collapsed=false renders as expanded',
          (tester) async {
        final falseCollapsedLink = EntryLink.basic(
          id: 'link-false',
          fromId: testTask.meta.id,
          toId: testImageEntry.meta.id,
          createdAt: DateTime(2024),
          updatedAt: DateTime(2024),
          vectorClock: null,
          collapsed: false,
        );

        when(() => mockJournalDb.journalEntityById(testImageEntry.meta.id))
            .thenAnswer((_) async => testImageEntry);

        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            ProviderScope(
              child: EntryDetailsWidget(
                itemId: testImageEntry.meta.id,
                showAiEntry: false,
                linkedFrom: testTask,
                link: falseCollapsedLink,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final animatedSize =
            tester.widget<AnimatedSize>(find.byType(AnimatedSize));
        expect(animatedSize.child, isA<Column>());
      });
    });

    group('parameter defaults', () {
      test('EntryDetailsWidget link defaults to null', () {
        const widget = EntryDetailsWidget(
          itemId: 'test-id',
          showAiEntry: false,
        );

        expect(widget.link, isNull);
        expect(widget.linkedFrom, isNull);
      });
    });

    group('onToggleCollapse callback', () {
      testWidgets('collapsible image entry passes onToggleCollapse to header',
          (tester) async {
        final testLink = EntryLink.basic(
          id: 'link-toggle',
          fromId: testTask.meta.id,
          toId: testImageEntry.meta.id,
          createdAt: DateTime(2024),
          updatedAt: DateTime(2024),
          vectorClock: null,
        );

        when(() => mockJournalDb.journalEntityById(testImageEntry.meta.id))
            .thenAnswer((_) async => testImageEntry);

        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            ProviderScope(
              child: EntryDetailsWidget(
                itemId: testImageEntry.meta.id,
                showAiEntry: false,
                linkedFrom: testTask,
                link: testLink,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // The collapse arrow should be present (isCollapsible = true)
        expect(find.byIcon(Icons.expand_more), findsOneWidget);

        // The EntryDetailHeader widget should be rendered with collapse props
        final header = tester.widget<EntryDetailHeader>(
          find.byType(EntryDetailHeader),
        );
        expect(header.isCollapsible, isTrue);
        expect(header.isCollapsed, isFalse);
        expect(header.onToggleCollapse, isNotNull);
      });

      testWidgets('non-collapsible text entry does NOT pass onToggleCollapse',
          (tester) async {
        final textLink = EntryLink.basic(
          id: 'link-text-toggle',
          fromId: testTask.meta.id,
          toId: testTextEntry.meta.id,
          createdAt: DateTime(2024),
          updatedAt: DateTime(2024),
          vectorClock: null,
        );

        when(() => mockJournalDb.journalEntityById(testTextEntry.meta.id))
            .thenAnswer((_) async => testTextEntry);

        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            ProviderScope(
              child: EntryDetailsWidget(
                itemId: testTextEntry.meta.id,
                showAiEntry: false,
                linkedFrom: testTask,
                link: textLink,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final header = tester.widget<EntryDetailHeader>(
          find.byType(EntryDetailHeader),
        );
        expect(header.isCollapsible, isFalse);
        expect(header.onToggleCollapse, isNull);
      });
    });

    group('collapsible audio layout', () {
      final testAudioLink = EntryLink.basic(
        id: 'link-audio-layout',
        fromId: testTask.meta.id,
        toId: testAudioEntry.meta.id,
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024),
        vectorClock: null,
      );

      testWidgets('expanded audio shows date under player', (tester) async {
        when(() => mockJournalDb.journalEntityById(testAudioEntry.meta.id))
            .thenAnswer((_) async => testAudioEntry);

        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            ProviderScope(
              child: EntryDetailsWidget(
                itemId: testAudioEntry.meta.id,
                showAiEntry: false,
                linkedFrom: testTask,
                link: testAudioLink,
              ),
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // In collapsible audio layout, both AudioPlayer and date are shown
        expect(find.byType(AudioPlayerWidget), findsOneWidget);
        expect(find.byType(EntryDatetimeWidget), findsAtLeastNWidgets(1));
      });
    });
  });
}
