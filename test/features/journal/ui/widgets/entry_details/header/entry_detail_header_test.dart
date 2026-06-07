import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/geolocation.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/editor_db.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/skills/built_in_skills.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/journal/ui/widgets/entry_details/entry_datetime_widget.dart';
import 'package:lotti/features/journal/ui/widgets/entry_details/header/entry_detail_header.dart';
import 'package:lotti/features/journal/util/entry_tools.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/editor_state_service.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/link_service.dart';
import 'package:lotti/themes/theme.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path_provider/path_provider.dart';

import '../../../../../../helpers/fallbacks.dart';
import '../../../../../../helpers/path_provider.dart';
import '../../../../../../mocks/mocks.dart';
import '../../../../../../test_data/test_data.dart';
import '../../../../../../widget_test_utils.dart';

void main() {
  group('EntryDetailHeader', () {
    registerFallbackValue(fallbackJournalEntity);
    registerFallbackValue(FakeMetadata());
    final mockJournalDb = MockJournalDb();
    final mockEditorDb = MockEditorDb();
    final mockEditorStateService = MockEditorStateService();
    final mockEntitiesCacheService = MockEntitiesCacheService();

    setUpAll(() async {
      await getIt.reset();
      registerFallbackValue(FakeEntryText());
      registerFallbackValue(FakeQuillController());

      final mockUpdateNotifications = MockUpdateNotifications();
      final mockPersistenceLogic = MockPersistenceLogic();

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
        ..registerSingleton<EditorStateService>(mockEditorStateService);

      when(() => mockUpdateNotifications.updateStream).thenAnswer(
        (_) => Stream<Set<String>>.fromIterable([]),
      );

      when(
        () => mockEditorStateService.entryWasSaved(
          id: any(named: 'id'),
          lastSaved: any(named: 'lastSaved'),
          controller: any(named: 'controller'),
        ),
      ).thenAnswer(
        (_) async {},
      );

      when(
        () => mockPersistenceLogic.updateJournalEntity(any(), any()),
      ).thenAnswer(
        (_) async => true,
      );

      when(
        () => mockEntitiesCacheService.getCategoryById(any()),
      ).thenReturn(null);
      when(() => mockEntitiesCacheService.getHabitById(any())).thenReturn(null);
      when(
        () => mockEntitiesCacheService.getDataTypeById(any()),
      ).thenReturn(null);
      when(
        () => mockEntitiesCacheService.getDashboardById(any()),
      ).thenReturn(null);
      when(() => mockEntitiesCacheService.sortedCategories).thenReturn([]);

      when(
        () => mockJournalDb.journalEntityById(testTextEntry.meta.id),
      ).thenAnswer((_) async => testTextEntry);

      when(
        () => mockEditorStateService.getUnsavedStream(
          any(),
          any(),
        ),
      ).thenAnswer(
        (_) => Stream<bool>.fromIterable([false]),
      );
    });

    tearDownAll(() async {
      await getIt.reset();
    });

    testWidgets('tap star icon', (WidgetTester tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          EntryDetailHeader(entryId: testTextEntry.meta.id),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      final starIconActiveFinder = find.byIcon(Icons.star_rounded);
      expect(starIconActiveFinder, findsOneWidget);

      await tester.tap(starIconActiveFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    });

    testWidgets('tap flagged icon', (WidgetTester tester) async {
      // Create a copy of testTextEntry with flag set to EntryFlag.import
      final flaggedTextEntry = testTextEntry.copyWith(
        meta: testTextEntry.meta.copyWith(flag: EntryFlag.import),
      );

      // Mock the database to return the flagged entry
      when(
        () => mockJournalDb.journalEntityById(testTextEntry.meta.id),
      ).thenAnswer((_) async => flaggedTextEntry);

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          EntryDetailHeader(entryId: testTextEntry.meta.id),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Now the flag icon should be visible
      final flagIconFinder = find.byIcon(Icons.flag);
      expect(flagIconFinder, findsOneWidget);

      await tester.tap(flagIconFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    });

    testWidgets('tap private icon', (WidgetTester tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          EntryDetailHeader(
            entryId: testTextEntry.meta.id,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final moreHorizIconFinder = find.byIcon(Icons.more_horiz);
      await tester.tap(moreHorizIconFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final lockIconFinder = find.byIcon(Icons.lock_open_rounded);

      expect(lockIconFinder, findsOneWidget);

      await tester.tap(lockIconFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    });

    testWidgets('save button invisible when saved/clean', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          EntryDetailHeader(entryId: testTextEntry.meta.id),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final saveButtonFinder = find.text('SAVE');
      expect(saveButtonFinder, findsNothing);
    });

    testWidgets('map action not visible when no geolocation exists', (
      WidgetTester tester,
    ) async {
      // Create an entry without geolocation
      final entryWithoutGeo = testTextEntry.copyWith(geolocation: null);
      when(
        () => mockJournalDb.journalEntityById(testTextEntry.meta.id),
      ).thenAnswer((_) async => entryWithoutGeo);

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          EntryDetailHeader(entryId: testTextEntry.meta.id),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final moreHorizIconFinder = find.byIcon(Icons.more_horiz);
      await tester.tap(moreHorizIconFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Map action should not be visible when there's no geolocation
      final mapIconOutlinedFinder = find.byIcon(Icons.map_outlined);
      final mapIconFilledFinder = find.byIcon(Icons.map_rounded);
      expect(mapIconOutlinedFinder, findsNothing);
      expect(mapIconFilledFinder, findsNothing);

      // Also verify the text is not present
      expect(find.text('Show map'), findsNothing);
      expect(find.text('Hide map'), findsNothing);
    });

    testWidgets('map action visible and tappable when geolocation exists', (
      WidgetTester tester,
    ) async {
      // testTextEntry already has geolocation, so we should see the map action
      when(
        () => mockJournalDb.journalEntityById(testTextEntry.meta.id),
      ).thenAnswer((_) async => testTextEntry);

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          EntryDetailHeader(entryId: testTextEntry.meta.id),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final moreHorizIconFinder = find.byIcon(Icons.more_horiz);
      await tester.tap(moreHorizIconFinder);
      // Give overlay animation an extra frame to complete to avoid
      // transient debugNeedsLayout during hit testing on fractional translations.
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // The map action should be visible with the outlined icon initially
      final mapIconFinder = find.byIcon(Icons.map_outlined);
      expect(mapIconFinder, findsOneWidget);
      expect(find.text('Show map'), findsOneWidget);

      // Tap the map action (icon is in an overlay; ensure layout is stable first)
      await tester.ensureVisible(mapIconFinder);
      await tester.pump();
      await tester.tap(mapIconFinder, warnIfMissed: false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    });

    testWidgets('map action not visible for Task entries', (
      WidgetTester tester,
    ) async {
      // Create a Task entry with geolocation (map should still not show)
      final taskEntry = testTask.copyWith(
        geolocation: Geolocation(
          geohashString: '',
          longitude: 13.43,
          latitude: 52.51,
          createdAt: DateTime(2022, 7, 7, 13),
        ),
      );
      when(
        () => mockJournalDb.journalEntityById(taskEntry.meta.id),
      ).thenAnswer((_) async => taskEntry);

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          EntryDetailHeader(entryId: taskEntry.meta.id),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final moreHorizIconFinder = find.byIcon(Icons.more_horiz);
      await tester.tap(moreHorizIconFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Map action should not be visible for tasks even with geolocation
      final mapIconOutlinedFinder = find.byIcon(Icons.map_outlined);
      final mapIconFilledFinder = find.byIcon(Icons.map_rounded);
      expect(mapIconOutlinedFinder, findsNothing);
      expect(mapIconFilledFinder, findsNothing);
    });

    testWidgets('entry date is visible', (WidgetTester tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          EntryDetailHeader(
            entryId: testTextEntry.meta.id,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final entryDateFromFinder = find.text(
        dfShorter.format(testTextEntry.meta.dateFrom),
      );
      expect(entryDateFromFinder, findsOneWidget);
    });

    testWidgets(
      'AI assistant icon is visible for text entries when text-modality '
      'skills are available',
      (WidgetTester tester) async {
        final textSkill =
            AiConfig.skill(
                  id: 'skill-test-text-1',
                  name: 'Test Text Skill',
                  createdAt: DateTime(2024, 3, 15),
                  skillType: SkillType.promptGeneration,
                  requiredInputModalities: const [Modality.text],
                  systemInstructions: 'sys',
                  userInstructions: 'usr',
                )
                as AiConfigSkill;

        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            EntryDetailHeader(entryId: testTextEntry.meta.id),
            overrides: [
              skillRegistryProvider.overrideWithValue([textSkill]),
            ],
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.byIcon(Icons.assistant_rounded), findsOneWidget);
      },
    );

    testWidgets(
      'AI assistant icon is hidden for text entries when no skills match',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            EntryDetailHeader(entryId: testTextEntry.meta.id),
            overrides: [
              skillRegistryProvider.overrideWithValue(const []),
            ],
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.byIcon(Icons.assistant_rounded), findsNothing);
      },
    );
  });
  group('EntryDetailHeader — collapsible', () {
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
          ..registerSingleton<EditorStateService>(mockEditorStateService);

        when(
          () => mockEditorStateService.entryWasSaved(
            id: any(named: 'id'),
            lastSaved: any(named: 'lastSaved'),
            controller: any(named: 'controller'),
          ),
        ).thenAnswer((_) async {});

        when(
          () => mockPersistenceLogic.updateJournalEntity(any(), any()),
        ).thenAnswer((_) async => true);

        when(
          () => mockEntitiesCacheService.getCategoryById(any()),
        ).thenReturn(null);
        when(
          () => mockEntitiesCacheService.getHabitById(any()),
        ).thenReturn(null);
        when(
          () => mockEntitiesCacheService.getDataTypeById(any()),
        ).thenReturn(null);
        when(
          () => mockEntitiesCacheService.getDashboardById(any()),
        ).thenReturn(null);
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
        testWidgets('shows menu but no collapse arrow', (tester) async {
          when(
            () => mockJournalDb.journalEntityById(testImageEntry.meta.id),
          ).thenAnswer((_) async => testImageEntry);

          await tester.pumpWidget(
            makeTestableWidgetWithScaffold(
              EntryDetailHeader(
                entryId: testImageEntry.meta.id,
              ),
            ),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));

          expect(find.byIcon(Icons.more_horiz), findsOneWidget);
          expect(find.byIcon(Icons.expand_more), findsNothing);
        });
      });

      group('collapsible header - expanded state', () {
        testWidgets('shows collapse arrow, menu, and no preview icons', (
          tester,
        ) async {
          when(
            () => mockJournalDb.journalEntityById(testImageEntry.meta.id),
          ).thenAnswer((_) async => testImageEntry);

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
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));

          expect(find.byIcon(Icons.expand_more), findsOneWidget);
          expect(find.byIcon(Icons.more_horiz), findsOneWidget);
          // When expanded, no thumbnail or mic icon in the header
          expect(find.byIcon(Icons.mic_rounded), findsNothing);
        });
      });

      group('collapsible header - collapsed state', () {
        testWidgets(
          'shows mic icon, duration, collapse arrow, but hides menu for audio',
          (tester) async {
            when(
              () => mockJournalDb.journalEntityById(testAudioEntry.meta.id),
            ).thenAnswer((_) async => testAudioEntry);

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
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 300));

            expect(find.byIcon(Icons.mic_rounded), findsOneWidget);
            // testAudioEntry has duration of 1 hour -> h:mm:ss format
            expect(find.text('1:00:00'), findsOneWidget);
            expect(find.byIcon(Icons.expand_more), findsOneWidget);
            expect(find.byIcon(Icons.more_horiz), findsNothing);
          },
        );

        testWidgets('does NOT show mic icon when audio entry is expanded', (
          tester,
        ) async {
          when(
            () => mockJournalDb.journalEntityById(testAudioEntry.meta.id),
          ).thenAnswer((_) async => testAudioEntry);

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
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));

          expect(find.byIcon(Icons.mic_rounded), findsNothing);
        });
      });

      group('collapsible header - collapsed text entry', () {
        testWidgets(
          'shows text icon, collapse arrow, and date but hides menu',
          (
            tester,
          ) async {
            when(
              () => mockJournalDb.journalEntityById(testTextEntry.meta.id),
            ).thenAnswer((_) async => testTextEntry);

            await tester.pumpWidget(
              makeTestableWidgetWithScaffold(
                EntryDetailHeader(
                  entryId: testTextEntry.meta.id,
                  inLinkedEntries: true,
                  isCollapsible: true,
                  isCollapsed: true,
                  onToggleCollapse: () {},
                ),
              ),
            );
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 300));

            expect(find.byIcon(Icons.description_outlined), findsOneWidget);
            expect(find.byIcon(Icons.expand_more), findsOneWidget);
            expect(find.byType(EntryDatetimeWidget), findsOneWidget);
            expect(find.byIcon(Icons.more_horiz), findsNothing);
          },
        );

        testWidgets('does NOT show text icon when text entry is expanded', (
          tester,
        ) async {
          when(
            () => mockJournalDb.journalEntityById(testTextEntry.meta.id),
          ).thenAnswer((_) async => testTextEntry);

          await tester.pumpWidget(
            makeTestableWidgetWithScaffold(
              EntryDetailHeader(
                entryId: testTextEntry.meta.id,
                inLinkedEntries: true,
                isCollapsible: true,
                onToggleCollapse: () {},
              ),
            ),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));

          expect(find.byIcon(Icons.description_outlined), findsNothing);
          expect(find.byIcon(Icons.expand_more), findsOneWidget);
          expect(find.byIcon(Icons.more_horiz), findsOneWidget);
        });
      });

      group('collapse toggle callback', () {
        testWidgets('calls onToggleCollapse when collapse arrow is tapped', (
          tester,
        ) async {
          var toggled = false;

          when(
            () => mockJournalDb.journalEntityById(testImageEntry.meta.id),
          ).thenAnswer((_) async => testImageEntry);

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
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));

          final collapseArrow = find.byIcon(Icons.expand_more);
          expect(collapseArrow, findsOneWidget);

          await tester.tap(collapseArrow);
          await tester.pump();

          expect(toggled, isTrue);
        });
      });

      group('animated chevron rotation', () {
        testWidgets('chevron is not rotated when expanded', (tester) async {
          when(
            () => mockJournalDb.journalEntityById(testImageEntry.meta.id),
          ).thenAnswer((_) async => testImageEntry);

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
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));

          final animatedRotation = tester.widget<AnimatedRotation>(
            find.byType(AnimatedRotation),
          );
          expect(animatedRotation.turns, equals(0.0));
        });

        testWidgets('chevron is rotated when collapsed', (tester) async {
          // Use audio entry to avoid image thumbnail needing Directory in GetIt
          when(
            () => mockJournalDb.journalEntityById(testAudioEntry.meta.id),
          ).thenAnswer((_) async => testAudioEntry);

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
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));

          final animatedRotation = tester.widget<AnimatedRotation>(
            find.byType(AnimatedRotation),
          );
          expect(animatedRotation.turns, equals(-0.25));
        });

        testWidgets(
          'rapid collapse toggles mid-animation land on the final target turn',
          (tester) async {
            when(
              () => mockJournalDb.journalEntityById(testAudioEntry.meta.id),
            ).thenAnswer((_) async => testAudioEntry);

            var collapsed = false;
            late StateSetter setOuterState;
            await tester.pumpWidget(
              makeTestableWidgetWithScaffold(
                StatefulBuilder(
                  builder: (context, setState) {
                    setOuterState = setState;
                    return EntryDetailHeader(
                      entryId: testAudioEntry.meta.id,
                      inLinkedEntries: true,
                      isCollapsible: true,
                      isCollapsed: collapsed,
                      onToggleCollapse: () {},
                    );
                  },
                ),
              ),
            );
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 300));

            // Flip collapse, advance only HALF the rotation, flip again,
            // then flip a third time — the implicit animation must retarget
            // each time and settle on the last requested orientation.
            setOuterState(() => collapsed = true);
            await tester.pump();
            await tester.pump(AppTheme.chevronRotationDuration ~/ 2);

            setOuterState(() => collapsed = false);
            await tester.pump();
            await tester.pump(AppTheme.chevronRotationDuration ~/ 2);

            setOuterState(() => collapsed = true);
            await tester.pump();
            await tester.pump(AppTheme.chevronRotationDuration);
            await tester.pump(AppTheme.chevronRotationDuration);

            final animatedRotation = tester.widget<AnimatedRotation>(
              find.byType(AnimatedRotation),
            );
            expect(animatedRotation.turns, -0.25);
          },
        );
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

          when(
            () => mockJournalDb.journalEntityById(shortAudio.meta.id),
          ).thenAnswer((_) async => shortAudio);

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
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));

          expect(find.text('2:34'), findsOneWidget);
        });

        testWidgets('formats hour-long duration correctly', (tester) async {
          // testAudioEntry already has 1 hour duration
          when(
            () => mockJournalDb.journalEntityById(testAudioEntry.meta.id),
          ).thenAnswer((_) async => testAudioEntry);

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
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));

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

          when(
            () => mockJournalDb.journalEntityById(borderAudio.meta.id),
          ).thenAnswer((_) async => borderAudio);

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
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));

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

          when(
            () => mockJournalDb.journalEntityById(exactlyOneHour.meta.id),
          ).thenAnswer((_) async => exactlyOneHour);

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
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));

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

          when(
            () => mockJournalDb.journalEntityById(zeroAudio.meta.id),
          ).thenAnswer((_) async => zeroAudio);

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
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));

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

          when(
            () => mockJournalDb.journalEntityById(longAudio.meta.id),
          ).thenAnswer((_) async => longAudio);

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
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));

          expect(find.text('1:05:30'), findsOneWidget);
        });
      });

      group('default header AI popup condition', () {
        testWidgets(
          'shows menu for audio and image entries in default header',
          (
            tester,
          ) async {
            for (final entry in [testAudioEntry, testImageEntry]) {
              when(
                () => mockJournalDb.journalEntityById(entry.meta.id),
              ).thenAnswer((_) async => entry);

              await tester.pumpWidget(
                makeTestableWidgetWithScaffold(
                  EntryDetailHeader(
                    entryId: entry.meta.id,
                  ),
                ),
              );
              await tester.pump();
              await tester.pump(const Duration(milliseconds: 300));

              expect(find.byIcon(Icons.more_horiz), findsOneWidget);
            }
          },
        );
      });

      group('expanded state shows action buttons', () {
        testWidgets('shows menu, arrow, date, but no preview icons', (
          tester,
        ) async {
          when(
            () => mockJournalDb.journalEntityById(testAudioEntry.meta.id),
          ).thenAnswer((_) async => testAudioEntry);

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
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));

          expect(find.byIcon(Icons.more_horiz), findsOneWidget);
          expect(find.byIcon(Icons.expand_more), findsOneWidget);
          expect(find.byType(EntryDatetimeWidget), findsOneWidget);
          expect(find.byIcon(Icons.mic_rounded), findsNothing);
        });
      });

      group('collapsed state shows only preview and arrow', () {
        testWidgets('shows date but hides menu, flag, and AI actions', (
          tester,
        ) async {
          when(
            () => mockJournalDb.journalEntityById(testAudioEntry.meta.id),
          ).thenAnswer((_) async => testAudioEntry);

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
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));

          expect(find.byType(EntryDatetimeWidget), findsOneWidget);
          // AI, flag, 3-dots all hidden when collapsed
          expect(find.byIcon(Icons.more_horiz), findsNothing);
          expect(find.byIcon(Icons.flag_outlined), findsNothing);
          expect(find.byIcon(Icons.flag), findsNothing);
        });
      });

      group('collapsible expanded state actions', () {
        testWidgets('shows flag icon when entry is flagged', (tester) async {
          final flaggedImage = testImageEntry.copyWith(
            meta: testImageEntry.meta.copyWith(flag: EntryFlag.import),
          );

          when(
            () => mockJournalDb.journalEntityById(flaggedImage.meta.id),
          ).thenAnswer((_) async => flaggedImage);

          await tester.pumpWidget(
            makeTestableWidgetWithScaffold(
              EntryDetailHeader(
                entryId: flaggedImage.meta.id,
                inLinkedEntries: true,
                isCollapsible: true,
                onToggleCollapse: () {},
              ),
            ),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));

          expect(find.byIcon(Icons.flag), findsOneWidget);
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
        final mockEditorStateService = MockEditorStateService();

        when(() => mockUpdateNotifications.updateStream).thenAnswer(
          (_) => Stream<Set<String>>.fromIterable([]),
        );

        getIt
          ..registerSingleton<Directory>(
            await getApplicationDocumentsDirectory(),
          )
          ..registerSingleton<UpdateNotifications>(mockUpdateNotifications)
          ..registerSingleton<JournalDb>(mockJournalDb)
          ..registerSingleton<EntitiesCacheService>(mockEntitiesCacheService)
          ..registerSingleton<LinkService>(MockLinkService())
          ..registerSingleton<PersistenceLogic>(mockPersistenceLogic)
          ..registerSingleton<EditorDb>(MockEditorDb())
          ..registerSingleton<EditorStateService>(mockEditorStateService);

        when(
          () => mockEditorStateService.entryWasSaved(
            id: any(named: 'id'),
            lastSaved: any(named: 'lastSaved'),
            controller: any(named: 'controller'),
          ),
        ).thenAnswer((_) async {});

        when(
          () => mockPersistenceLogic.updateJournalEntity(any(), any()),
        ).thenAnswer((_) async => true);

        when(
          () => mockEntitiesCacheService.getCategoryById(any()),
        ).thenReturn(null);
        when(
          () => mockEntitiesCacheService.getHabitById(any()),
        ).thenReturn(null);
        when(
          () => mockEntitiesCacheService.getDataTypeById(any()),
        ).thenReturn(null);
        when(
          () => mockEntitiesCacheService.getDashboardById(any()),
        ).thenReturn(null);
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

      testWidgets('shows thumbnail, ClipRRect, and date for collapsed image', (
        tester,
      ) async {
        when(
          () => mockJournalDb.journalEntityById(testImageEntry.meta.id),
        ).thenAnswer((_) async => testImageEntry);

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
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Image thumbnail is wrapped in a 40x40 SizedBox inside ClipRRect
        final sizedBoxes = tester.widgetList<SizedBox>(find.byType(SizedBox));
        final thumbnail = sizedBoxes.where(
          (s) => s.width == 40 && s.height == 40,
        );
        expect(thumbnail, isNotEmpty);
        expect(find.byType(ClipRRect), findsOneWidget);
        expect(find.byType(EntryDatetimeWidget), findsOneWidget);
      });
    });
  });
}
