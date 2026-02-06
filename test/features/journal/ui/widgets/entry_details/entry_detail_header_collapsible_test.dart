import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/tag_type_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/editor_db.dart';
import 'package:lotti/features/journal/ui/widgets/entry_details/entry_datetime_widget.dart';
import 'package:lotti/features/journal/ui/widgets/entry_details/header/entry_detail_header.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/editor_state_service.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/link_service.dart';
import 'package:lotti/services/tags_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path_provider/path_provider.dart';

import '../../../../../helpers/fallbacks.dart';
import '../../../../../helpers/path_provider.dart';
import '../../../../../mocks/mocks.dart';
import '../../../../../test_data/test_data.dart';
import '../../../../../widget_test_utils.dart';

void main() {
  group('EntryDetailHeader Collapsible', () {
    final mockJournalDb = MockJournalDb();
    final mockEditorDb = MockEditorDb();
    final mockEditorStateService = MockEditorStateService();
    final mockEntitiesCacheService = MockEntitiesCacheService();

    setUpAll(() async {
      await getIt.reset();
      registerFallbackValue(fallbackJournalEntity);
      registerFallbackValue(FakeMetadata());
      registerFallbackValue(FakeEntryText());
      registerFallbackValue(FakeQuillController());

      final mockUpdateNotifications = MockUpdateNotifications();
      final mockPersistenceLogic = MockPersistenceLogic();
      final mockTagsService = mockTagsServiceWithTags([]);

      when(() => mockUpdateNotifications.updateStream).thenAnswer(
        (_) => Stream<Set<String>>.fromIterable([]),
      );

      getIt
        ..registerSingleton<UpdateNotifications>(mockUpdateNotifications)
        ..registerSingleton<JournalDb>(mockJournalDb)
        ..registerSingleton<EntitiesCacheService>(mockEntitiesCacheService)
        ..registerSingleton<LinkService>(MockLinkService())
        ..registerSingleton<PersistenceLogic>(mockPersistenceLogic)
        ..registerSingleton<EditorDb>(mockEditorDb)
        ..registerSingleton<EditorStateService>(mockEditorStateService)
        ..registerSingleton<TagsService>(mockTagsService);

      when(
        () => mockEditorStateService.entryWasSaved(
          id: any(named: 'id'),
          lastSaved: any(named: 'lastSaved'),
          controller: any(named: 'controller'),
        ),
      ).thenAnswer((_) async {});

      when(() => mockPersistenceLogic.updateJournalEntity(any(), any()))
          .thenAnswer((_) async => true);

      when(mockTagsService.watchTags).thenAnswer(
        (_) => Stream<List<TagEntity>>.fromIterable([[]]),
      );

      when(() => mockEntitiesCacheService.getCategoryById(any()))
          .thenReturn(null);
      when(() => mockEntitiesCacheService.getHabitById(any())).thenReturn(null);
      when(() => mockEntitiesCacheService.getDataTypeById(any()))
          .thenReturn(null);
      when(() => mockEntitiesCacheService.getDashboardById(any()))
          .thenReturn(null);
      when(() => mockEntitiesCacheService.sortedCategories).thenReturn([]);

      when(
        () => mockEditorStateService.getUnsavedStream(any(), any()),
      ).thenAnswer(
        (_) => Stream<bool>.fromIterable([false]),
      );
    });

    tearDownAll(() async {
      await getIt.reset();
    });

    group('default header (non-collapsible)', () {
      testWidgets('renders default layout when isCollapsible is false',
          (tester) async {
        when(() => mockJournalDb.journalEntityById(testImageEntry.meta.id))
            .thenAnswer((_) async => testImageEntry);

        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            EntryDetailHeader(
              entryId: testImageEntry.meta.id,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Should show 3-dots menu but NOT collapse arrow
        expect(find.byIcon(Icons.more_horiz), findsOneWidget);
        expect(find.byIcon(Icons.expand_more), findsNothing);
      });

      testWidgets('does not show collapse arrow by default', (tester) async {
        when(() => mockJournalDb.journalEntityById(testTextEntry.meta.id))
            .thenAnswer((_) async => testTextEntry);

        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            EntryDetailHeader(
              entryId: testTextEntry.meta.id,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.expand_more), findsNothing);
      });
    });

    group('collapsible header - expanded state', () {
      testWidgets('shows collapse arrow when isCollapsible is true',
          (tester) async {
        when(() => mockJournalDb.journalEntityById(testImageEntry.meta.id))
            .thenAnswer((_) async => testImageEntry);

        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            EntryDetailHeader(
              entryId: testImageEntry.meta.id,
              inLinkedEntries: true,
              isCollapsible: true,
              onToggleCollapse: () {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.expand_more), findsOneWidget);
      });

      testWidgets('shows 3-dots menu in collapsible mode', (tester) async {
        when(() => mockJournalDb.journalEntityById(testImageEntry.meta.id))
            .thenAnswer((_) async => testImageEntry);

        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            EntryDetailHeader(
              entryId: testImageEntry.meta.id,
              inLinkedEntries: true,
              isCollapsible: true,
              onToggleCollapse: () {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.more_horiz), findsOneWidget);
      });

      testWidgets(
          'does NOT show image thumbnail when expanded (isCollapsed=false)',
          (tester) async {
        when(() => mockJournalDb.journalEntityById(testImageEntry.meta.id))
            .thenAnswer((_) async => testImageEntry);

        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            EntryDetailHeader(
              entryId: testImageEntry.meta.id,
              inLinkedEntries: true,
              isCollapsible: true,
              onToggleCollapse: () {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        // When expanded, no thumbnail or mic icon in the header
        expect(find.byIcon(Icons.mic_rounded), findsNothing);
      });
    });

    group('collapsible header - collapsed state', () {
      testWidgets('shows mic icon when audio entry is collapsed',
          (tester) async {
        when(() => mockJournalDb.journalEntityById(testAudioEntry.meta.id))
            .thenAnswer((_) async => testAudioEntry);

        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            EntryDetailHeader(
              entryId: testAudioEntry.meta.id,
              inLinkedEntries: true,
              isCollapsible: true,
              isCollapsed: true,
              onToggleCollapse: () {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.mic_rounded), findsOneWidget);
      });

      testWidgets('shows duration label when audio entry is collapsed',
          (tester) async {
        when(() => mockJournalDb.journalEntityById(testAudioEntry.meta.id))
            .thenAnswer((_) async => testAudioEntry);

        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            EntryDetailHeader(
              entryId: testAudioEntry.meta.id,
              inLinkedEntries: true,
              isCollapsible: true,
              isCollapsed: true,
              onToggleCollapse: () {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        // testAudioEntry has duration of 1 hour -> h:mm:ss format
        expect(find.text('1:00:00'), findsOneWidget);
      });

      testWidgets('does NOT show mic icon when audio entry is expanded',
          (tester) async {
        when(() => mockJournalDb.journalEntityById(testAudioEntry.meta.id))
            .thenAnswer((_) async => testAudioEntry);

        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            EntryDetailHeader(
              entryId: testAudioEntry.meta.id,
              inLinkedEntries: true,
              isCollapsible: true,
              onToggleCollapse: () {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.mic_rounded), findsNothing);
      });

      testWidgets('hides 3-dots menu when collapsed', (tester) async {
        when(() => mockJournalDb.journalEntityById(testAudioEntry.meta.id))
            .thenAnswer((_) async => testAudioEntry);

        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            EntryDetailHeader(
              entryId: testAudioEntry.meta.id,
              inLinkedEntries: true,
              isCollapsible: true,
              isCollapsed: true,
              onToggleCollapse: () {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.more_horiz), findsNothing);
      });

      testWidgets('still shows collapse arrow when collapsed', (tester) async {
        when(() => mockJournalDb.journalEntityById(testAudioEntry.meta.id))
            .thenAnswer((_) async => testAudioEntry);

        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            EntryDetailHeader(
              entryId: testAudioEntry.meta.id,
              inLinkedEntries: true,
              isCollapsible: true,
              isCollapsed: true,
              onToggleCollapse: () {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.expand_more), findsOneWidget);
      });
    });

    group('collapse toggle callback', () {
      testWidgets('calls onToggleCollapse when collapse arrow is tapped',
          (tester) async {
        var toggled = false;

        when(() => mockJournalDb.journalEntityById(testImageEntry.meta.id))
            .thenAnswer((_) async => testImageEntry);

        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            EntryDetailHeader(
              entryId: testImageEntry.meta.id,
              inLinkedEntries: true,
              isCollapsible: true,
              onToggleCollapse: () => toggled = true,
            ),
          ),
        );
        await tester.pumpAndSettle();

        final collapseArrow = find.byIcon(Icons.expand_more);
        expect(collapseArrow, findsOneWidget);

        await tester.tap(collapseArrow);
        await tester.pumpAndSettle();

        expect(toggled, isTrue);
      });
    });

    group('animated chevron rotation', () {
      testWidgets('chevron is not rotated when expanded', (tester) async {
        when(() => mockJournalDb.journalEntityById(testImageEntry.meta.id))
            .thenAnswer((_) async => testImageEntry);

        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            EntryDetailHeader(
              entryId: testImageEntry.meta.id,
              inLinkedEntries: true,
              isCollapsible: true,
              onToggleCollapse: () {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        final animatedRotation =
            tester.widget<AnimatedRotation>(find.byType(AnimatedRotation));
        expect(animatedRotation.turns, equals(0.0));
      });

      testWidgets('chevron is rotated when collapsed', (tester) async {
        // Use audio entry to avoid image thumbnail needing Directory in GetIt
        when(() => mockJournalDb.journalEntityById(testAudioEntry.meta.id))
            .thenAnswer((_) async => testAudioEntry);

        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            EntryDetailHeader(
              entryId: testAudioEntry.meta.id,
              inLinkedEntries: true,
              isCollapsible: true,
              isCollapsed: true,
              onToggleCollapse: () {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        final animatedRotation =
            tester.widget<AnimatedRotation>(find.byType(AnimatedRotation));
        expect(animatedRotation.turns, equals(-0.25));
      });
    });

    group('duration formatting', () {
      testWidgets('formats short duration correctly', (tester) async {
        // Create audio entry with 2 minutes 34 seconds
        final shortAudio = testAudioEntry.copyWith(
          data: AudioData(
            dateFrom: DateTime(2022, 7, 7, 13),
            dateTo: DateTime(2022, 7, 7, 14),
            duration: const Duration(minutes: 2, seconds: 34),
            audioFile: '',
            audioDirectory: '',
          ),
        );

        when(() => mockJournalDb.journalEntityById(shortAudio.meta.id))
            .thenAnswer((_) async => shortAudio);

        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            EntryDetailHeader(
              entryId: shortAudio.meta.id,
              inLinkedEntries: true,
              isCollapsible: true,
              isCollapsed: true,
              onToggleCollapse: () {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('2:34'), findsOneWidget);
      });

      testWidgets('formats hour-long duration correctly', (tester) async {
        // testAudioEntry already has 1 hour duration
        when(() => mockJournalDb.journalEntityById(testAudioEntry.meta.id))
            .thenAnswer((_) async => testAudioEntry);

        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            EntryDetailHeader(
              entryId: testAudioEntry.meta.id,
              inLinkedEntries: true,
              isCollapsible: true,
              isCollapsed: true,
              onToggleCollapse: () {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 1 hour = 3600 seconds, triggers h:mm:ss format
        expect(find.text('1:00:00'), findsOneWidget);
      });

      testWidgets('formats 59 minutes as m:ss (boundary)', (tester) async {
        final borderAudio = testAudioEntry.copyWith(
          data: AudioData(
            dateFrom: DateTime(2022, 7, 7, 13),
            dateTo: DateTime(2022, 7, 7, 14),
            duration: const Duration(minutes: 59, seconds: 59),
            audioFile: '',
            audioDirectory: '',
          ),
        );

        when(() => mockJournalDb.journalEntityById(borderAudio.meta.id))
            .thenAnswer((_) async => borderAudio);

        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            EntryDetailHeader(
              entryId: borderAudio.meta.id,
              inLinkedEntries: true,
              isCollapsible: true,
              isCollapsed: true,
              onToggleCollapse: () {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 59 min 59 sec stays in m:ss format
        expect(find.text('59:59'), findsOneWidget);
      });

      testWidgets('formats exactly 60 minutes as h:mm:ss', (tester) async {
        final exactlyOneHour = testAudioEntry.copyWith(
          data: AudioData(
            dateFrom: DateTime(2022, 7, 7, 13),
            dateTo: DateTime(2022, 7, 7, 14),
            duration: const Duration(minutes: 60),
            audioFile: '',
            audioDirectory: '',
          ),
        );

        when(() => mockJournalDb.journalEntityById(exactlyOneHour.meta.id))
            .thenAnswer((_) async => exactlyOneHour);

        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            EntryDetailHeader(
              entryId: exactlyOneHour.meta.id,
              inLinkedEntries: true,
              isCollapsible: true,
              isCollapsed: true,
              onToggleCollapse: () {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('1:00:00'), findsOneWidget);
      });

      testWidgets('formats zero-second duration correctly', (tester) async {
        final zeroAudio = testAudioEntry.copyWith(
          data: AudioData(
            dateFrom: DateTime(2022, 7, 7, 13),
            dateTo: DateTime(2022, 7, 7, 14),
            duration: Duration.zero,
            audioFile: '',
            audioDirectory: '',
          ),
        );

        when(() => mockJournalDb.journalEntityById(zeroAudio.meta.id))
            .thenAnswer((_) async => zeroAudio);

        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            EntryDetailHeader(
              entryId: zeroAudio.meta.id,
              inLinkedEntries: true,
              isCollapsible: true,
              isCollapsed: true,
              onToggleCollapse: () {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('0:00'), findsOneWidget);
      });

      testWidgets('formats >1 hour duration with h:mm:ss', (tester) async {
        final longAudio = testAudioEntry.copyWith(
          data: AudioData(
            dateFrom: DateTime(2022, 7, 7, 13),
            dateTo: DateTime(2022, 7, 7, 14),
            duration: const Duration(hours: 1, minutes: 5, seconds: 30),
            audioFile: '',
            audioDirectory: '',
          ),
        );

        when(() => mockJournalDb.journalEntityById(longAudio.meta.id))
            .thenAnswer((_) async => longAudio);

        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            EntryDetailHeader(
              entryId: longAudio.meta.id,
              inLinkedEntries: true,
              isCollapsible: true,
              isCollapsed: true,
              onToggleCollapse: () {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('1:05:30'), findsOneWidget);
      });
    });

    group('expanded state shows action buttons', () {
      testWidgets('shows 3-dots and collapse arrow when expanded',
          (tester) async {
        when(() => mockJournalDb.journalEntityById(testAudioEntry.meta.id))
            .thenAnswer((_) async => testAudioEntry);

        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            EntryDetailHeader(
              entryId: testAudioEntry.meta.id,
              inLinkedEntries: true,
              isCollapsible: true,
              onToggleCollapse: () {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.more_horiz), findsOneWidget);
        expect(find.byIcon(Icons.expand_more), findsOneWidget);
      });

      testWidgets('does NOT show date or preview when expanded',
          (tester) async {
        when(() => mockJournalDb.journalEntityById(testAudioEntry.meta.id))
            .thenAnswer((_) async => testAudioEntry);

        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            EntryDetailHeader(
              entryId: testAudioEntry.meta.id,
              inLinkedEntries: true,
              isCollapsible: true,
              onToggleCollapse: () {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        // No mic icon or duration in expanded state
        expect(find.byIcon(Icons.mic_rounded), findsNothing);
      });
    });

    group('collapsed state shows only preview and arrow', () {
      testWidgets('shows date widget when collapsed', (tester) async {
        when(() => mockJournalDb.journalEntityById(testAudioEntry.meta.id))
            .thenAnswer((_) async => testAudioEntry);

        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            EntryDetailHeader(
              entryId: testAudioEntry.meta.id,
              inLinkedEntries: true,
              isCollapsible: true,
              isCollapsed: true,
              onToggleCollapse: () {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Date widget is present in collapsed header
        expect(
          find.byType(EntryDatetimeWidget),
          findsOneWidget,
        );
      });

      testWidgets('does NOT show AI popup when collapsed', (tester) async {
        when(() => mockJournalDb.journalEntityById(testAudioEntry.meta.id))
            .thenAnswer((_) async => testAudioEntry);

        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            EntryDetailHeader(
              entryId: testAudioEntry.meta.id,
              inLinkedEntries: true,
              isCollapsible: true,
              isCollapsed: true,
              onToggleCollapse: () {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        // AI, flag, 3-dots all hidden when collapsed
        expect(find.byIcon(Icons.more_horiz), findsNothing);
        expect(find.byIcon(Icons.flag_outlined), findsNothing);
        expect(find.byIcon(Icons.flag), findsNothing);
      });
    });
  });

  group('EntryDetailHeader Image Thumbnail', () {
    late MockJournalDb mockJournalDb;
    late MockEntitiesCacheService mockEntitiesCacheService;

    setUpAll(() {
      setFakeDocumentsPath();
      registerFallbackValue(fallbackJournalEntity);
      registerFallbackValue(FakeMetadata());
      registerFallbackValue(FakeEntryText());
      registerFallbackValue(FakeQuillController());
    });

    setUp(() async {
      await getIt.reset();
      mockJournalDb = MockJournalDb();
      mockEntitiesCacheService = MockEntitiesCacheService();

      final mockUpdateNotifications = MockUpdateNotifications();
      final mockPersistenceLogic = MockPersistenceLogic();
      final mockTagsService = mockTagsServiceWithTags([]);
      final mockEditorStateService = MockEditorStateService();

      when(() => mockUpdateNotifications.updateStream).thenAnswer(
        (_) => Stream<Set<String>>.fromIterable([]),
      );

      getIt
        ..registerSingleton<Directory>(await getApplicationDocumentsDirectory())
        ..registerSingleton<UpdateNotifications>(mockUpdateNotifications)
        ..registerSingleton<JournalDb>(mockJournalDb)
        ..registerSingleton<EntitiesCacheService>(mockEntitiesCacheService)
        ..registerSingleton<LinkService>(MockLinkService())
        ..registerSingleton<PersistenceLogic>(mockPersistenceLogic)
        ..registerSingleton<EditorDb>(MockEditorDb())
        ..registerSingleton<EditorStateService>(mockEditorStateService)
        ..registerSingleton<TagsService>(mockTagsService);

      when(
        () => mockEditorStateService.entryWasSaved(
          id: any(named: 'id'),
          lastSaved: any(named: 'lastSaved'),
          controller: any(named: 'controller'),
        ),
      ).thenAnswer((_) async {});

      when(() => mockPersistenceLogic.updateJournalEntity(any(), any()))
          .thenAnswer((_) async => true);

      when(mockTagsService.watchTags).thenAnswer(
        (_) => Stream<List<TagEntity>>.fromIterable([[]]),
      );

      when(() => mockEntitiesCacheService.getCategoryById(any()))
          .thenReturn(null);
      when(() => mockEntitiesCacheService.getHabitById(any())).thenReturn(null);
      when(() => mockEntitiesCacheService.getDataTypeById(any()))
          .thenReturn(null);
      when(() => mockEntitiesCacheService.getDashboardById(any()))
          .thenReturn(null);
      when(() => mockEntitiesCacheService.sortedCategories).thenReturn([]);

      when(
        () => mockEditorStateService.getUnsavedStream(any(), any()),
      ).thenAnswer(
        (_) => Stream<bool>.fromIterable([false]),
      );
    });

    tearDown(() async {
      await getIt.reset();
    });

    testWidgets('shows image thumbnail area when collapsed', (tester) async {
      when(() => mockJournalDb.journalEntityById(testImageEntry.meta.id))
          .thenAnswer((_) async => testImageEntry);

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          EntryDetailHeader(
            entryId: testImageEntry.meta.id,
            inLinkedEntries: true,
            isCollapsible: true,
            isCollapsed: true,
            onToggleCollapse: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Image thumbnail is wrapped in a 40x40 SizedBox inside ClipRRect
      final sizedBoxes = tester.widgetList<SizedBox>(find.byType(SizedBox));
      final thumbnail = sizedBoxes.where(
        (s) => s.width == 40 && s.height == 40,
      );
      expect(thumbnail, isNotEmpty);
    });

    testWidgets('shows ClipRRect for image thumbnail when collapsed',
        (tester) async {
      when(() => mockJournalDb.journalEntityById(testImageEntry.meta.id))
          .thenAnswer((_) async => testImageEntry);

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          EntryDetailHeader(
            entryId: testImageEntry.meta.id,
            inLinkedEntries: true,
            isCollapsible: true,
            isCollapsed: true,
            onToggleCollapse: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ClipRRect), findsOneWidget);
    });

    testWidgets('shows date widget for collapsed image entry', (tester) async {
      when(() => mockJournalDb.journalEntityById(testImageEntry.meta.id))
          .thenAnswer((_) async => testImageEntry);

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          EntryDetailHeader(
            entryId: testImageEntry.meta.id,
            inLinkedEntries: true,
            isCollapsible: true,
            isCollapsed: true,
            onToggleCollapse: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(EntryDatetimeWidget), findsOneWidget);
    });
  });
}
