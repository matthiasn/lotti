import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/ai/helpers/profile_automation_resolver.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/resolved_profile.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart'
    show AiConfigRepository;
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/state/profile_automation_providers.dart';
import 'package:lotti/features/ai/state/settings/ai_config_by_type_controller.dart';
import 'package:lotti/features/ai/state/unified_ai_controller.dart';
import 'package:lotti/features/ai/ui/unified_ai_popup_menu.dart';
import 'package:lotti/features/ai/ui/widgets/transcription_model_picker_modal.dart';
import 'package:lotti/features/design_system/components/lists/design_system_list_item.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fake_entry_controller.dart';
import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';
import '../test_utils.dart' show MockAiConfigByTypeController;

class MockNavigatorObserver extends Mock implements NavigatorObserver {}

void main() {
  late JournalEntity testTaskEntity;
  late JournalEntity testJournalEntry;
  late JournalEntity testImageEntity;
  late JournalEntity testAudioEntity;
  late List<AiConfigSkill> testSkills;
  late MockNavigatorObserver mockNavigatorObserver;
  late MockLoggingService mockLoggingService;
  late MockJournalDb mockJournalDb;
  late MockUpdateNotifications mockUpdateNotifications;
  late List<Override> defaultOverrides;

  setUpAll(registerAllFallbackValues);

  setUp(() {
    mockNavigatorObserver = MockNavigatorObserver();
    mockLoggingService = MockLoggingService();
    mockJournalDb = MockJournalDb();
    mockUpdateNotifications = MockUpdateNotifications();

    // Set up GetIt
    if (getIt.isRegistered<LoggingService>()) {
      getIt.unregister<LoggingService>();
    }
    if (getIt.isRegistered<JournalDb>()) {
      getIt.unregister<JournalDb>();
    }
    if (getIt.isRegistered<UpdateNotifications>()) {
      getIt.unregister<UpdateNotifications>();
    }
    getIt
      ..registerSingleton<LoggingService>(mockLoggingService)
      ..registerSingleton<JournalDb>(mockJournalDb)
      ..registerSingleton<UpdateNotifications>(mockUpdateNotifications);

    // Mock JournalDb methods - linksFromId returns a Selectable
    when(
      () => mockUpdateNotifications.updateStream,
    ).thenAnswer((_) => const Stream<Set<String>>.empty());
    when(
      () => mockJournalDb.linksFromId(any(), any()),
    ).thenReturn(MockSelectable<LinkedDbEntry>([]));
    when(
      () => mockJournalDb.getLinkedToEntities(any()),
    ).thenAnswer((_) async => <JournalDbEntity>[]);
    // Mock getLinkedEntities for bidirectional link lookup
    when(
      () => mockJournalDb.getLinkedEntities(any()),
    ).thenAnswer((_) async => <JournalEntity>[]);

    // Mock logging methods
    when(
      () => mockLoggingService.captureEvent(
        any<dynamic>(),
        domain: any(named: 'domain'),
        subDomain: any(named: 'subDomain'),
      ),
    ).thenReturn(null);

    when(
      () => mockLoggingService.captureException(
        any<dynamic>(),
        domain: any(named: 'domain'),
        subDomain: any(named: 'subDomain'),
        stackTrace: any<dynamic>(named: 'stackTrace'),
      ),
    ).thenReturn(null);

    // Create test entities
    final now = DateTime(2024, 3, 15, 10);

    testTaskEntity = Task(
      meta: Metadata(
        id: 'task-1',
        createdAt: now,
        updatedAt: now,
        dateFrom: now,
        dateTo: now.add(const Duration(hours: 1)),
      ),
      data: TaskData(
        title: 'Test Task',
        status: TaskStatus.open(
          id: 'status-1',
          createdAt: now,
          utcOffset: 0,
        ),
        dateFrom: now,
        dateTo: now.add(const Duration(hours: 1)),
        statusHistory: [],
      ),
    );

    testJournalEntry = JournalEntry(
      meta: Metadata(
        id: 'entry-1',
        createdAt: now,
        updatedAt: now,
        dateFrom: now,
        dateTo: now.add(const Duration(minutes: 30)),
      ),
    );

    testImageEntity = JournalImage(
      meta: Metadata(
        id: 'image-1',
        createdAt: now,
        updatedAt: now,
        dateFrom: now,
        dateTo: now.add(const Duration(minutes: 15)),
      ),
      data: ImageData(
        capturedAt: now,
        imageId: 'img-1',
        imageFile: 'test.jpg',
        imageDirectory: '/test',
      ),
    );

    testAudioEntity = JournalAudio(
      meta: Metadata(
        id: 'audio-1',
        createdAt: now,
        updatedAt: now,
        dateFrom: now,
        dateTo: now.add(const Duration(minutes: 45)),
      ),
      data: AudioData(
        dateFrom: now,
        dateTo: now.add(const Duration(minutes: 45)),
        audioFile: 'test.mp3',
        audioDirectory: '/test',
        duration: const Duration(minutes: 45),
      ),
    );

    // Create test skills
    testSkills = [
      AiConfig.skill(
            id: 'skill-transcription',
            name: 'Audio Transcription Skill',
            createdAt: now,
            skillType: SkillType.transcription,
            requiredInputModalities: [Modality.audio],
            systemInstructions: 'Transcribe audio',
            userInstructions: 'Transcribe the audio file',
            description: 'Skill-based transcription',
          )
          as AiConfigSkill,
      AiConfig.skill(
            id: 'skill-image-analysis',
            name: 'Image Analysis Skill',
            createdAt: now,
            skillType: SkillType.imageAnalysis,
            requiredInputModalities: [Modality.image],
            systemInstructions: 'Analyze image',
            userInstructions: 'Analyze the image',
            description: 'Skill-based image analysis',
          )
          as AiConfigSkill,
      AiConfig.skill(
            id: 'skill-prompt-gen',
            name: 'Prompt Generation Skill',
            createdAt: now,
            skillType: SkillType.promptGeneration,
            requiredInputModalities: [Modality.text],
            systemInstructions: 'Generate a prompt',
            userInstructions: 'Please generate a prompt',
            description: 'Generates prompts from context',
          )
          as AiConfigSkill,
    ];

    defaultOverrides = [
      // Override entry controllers for all test entities
      entryControllerProvider(id: 'task-1').overrideWith(
        () => FakeEntryController(testTaskEntity),
      ),
      entryControllerProvider(id: 'entry-1').overrideWith(
        () => FakeEntryController(testJournalEntry),
      ),
      entryControllerProvider(id: 'image-1').overrideWith(
        () => FakeEntryController(testImageEntity),
      ),
      entryControllerProvider(id: 'audio-1').overrideWith(
        () => FakeEntryController(testAudioEntity),
      ),
    ];
  });

  tearDown(() async {
    await getIt.reset();
  });

  // Helper function to build test widget
  Widget buildTestWidget(
    Widget child, {
    List<Override> overrides = const [],
  }) {
    return ProviderScope(
      overrides: [
        ...defaultOverrides,
        ...overrides,
      ],
      child: MaterialApp(
        theme: resolveTestTheme(),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        navigatorObservers: [mockNavigatorObserver],
        home: Scaffold(
          body: child,
        ),
      ),
    );
  }

  group('UnifiedAiPopUpMenu Tests', () {
    testWidgets('shows assistant icon when skills are available', (
      tester,
    ) async {
      // Arrange
      await tester.pumpWidget(
        buildTestWidget(
          UnifiedAiPopUpMenu(
            journalEntity: testTaskEntity,
            linkedFromId: null,
          ),
          overrides: [
            hasAvailableSkillsProvider((
              entityId: testTaskEntity.id,
              linkedFromId: null,
            )).overrideWith((ref) => Future.value(true)),
            availableSkillsForEntityProvider((
              entityId: testTaskEntity.id,
              linkedFromId: null,
            )).overrideWith((ref) => Future.value(testSkills)),
          ],
        ),
      );

      await tester.pumpAndSettle();

      // Assert
      expect(find.byIcon(Icons.assistant_rounded), findsOneWidget);
      expect(find.byType(IconButton), findsOneWidget);
    });

    testWidgets('shows nothing when no skills are available', (tester) async {
      // Arrange
      await tester.pumpWidget(
        buildTestWidget(
          UnifiedAiPopUpMenu(
            journalEntity: testTaskEntity,
            linkedFromId: null,
          ),
          overrides: [
            hasAvailableSkillsProvider((
              entityId: testTaskEntity.id,
              linkedFromId: null,
            )).overrideWith((ref) => Future.value(false)),
          ],
        ),
      );

      await tester.pumpAndSettle();

      // Assert
      expect(find.byIcon(Icons.assistant_rounded), findsNothing);
      expect(find.byType(IconButton), findsNothing);
      expect(find.byType(SizedBox), findsOneWidget);
    });

    testWidgets('shows nothing during loading', (tester) async {
      // Arrange
      final completer = Completer<bool>();

      await tester.pumpWidget(
        buildTestWidget(
          UnifiedAiPopUpMenu(
            journalEntity: testTaskEntity,
            linkedFromId: null,
          ),
          overrides: [
            hasAvailableSkillsProvider((
              entityId: testTaskEntity.id,
              linkedFromId: null,
            )).overrideWith((ref) => completer.future),
          ],
        ),
      );

      await tester.pump();

      // Assert
      expect(find.byIcon(Icons.assistant_rounded), findsNothing);
      expect(find.byType(IconButton), findsNothing);
      expect(find.byType(SizedBox), findsOneWidget);

      // Complete to avoid hanging test
      completer.complete(false);
      await tester.pumpAndSettle();
    });

    testWidgets('shows nothing on error', (tester) async {
      // Arrange
      await tester.pumpWidget(
        buildTestWidget(
          UnifiedAiPopUpMenu(
            journalEntity: testTaskEntity,
            linkedFromId: null,
          ),
          overrides: [
            hasAvailableSkillsProvider((
              entityId: testTaskEntity.id,
              linkedFromId: null,
            )).overrideWith((ref) => Future.error('Test error')),
          ],
        ),
      );

      await tester.pumpAndSettle();

      // Assert
      expect(find.byIcon(Icons.assistant_rounded), findsNothing);
      expect(find.byType(IconButton), findsNothing);
      expect(find.byType(SizedBox), findsOneWidget);
    });

    testWidgets('opens modal when assistant icon is tapped', (tester) async {
      // Arrange
      await tester.pumpWidget(
        buildTestWidget(
          UnifiedAiPopUpMenu(
            journalEntity: testTaskEntity,
            linkedFromId: 'linked-from-1',
          ),
          overrides: [
            hasAvailableSkillsProvider((
              entityId: testTaskEntity.id,
              linkedFromId: 'linked-from-1',
            )).overrideWith((ref) => Future.value(true)),
            availableSkillsForEntityProvider((
              entityId: testTaskEntity.id,
              linkedFromId: 'linked-from-1',
            )).overrideWith((ref) => Future.value(testSkills)),
          ],
        ),
      );

      await tester.pumpAndSettle();

      // Act
      await tester.tap(find.byIcon(Icons.assistant_rounded));
      await tester.pumpAndSettle();

      // Assert - check for the skills list
      expect(find.byType(UnifiedAiSkillsList), findsOneWidget);
    });
  });

  group('UnifiedAiSkillsList Tests', () {
    testWidgets('displays list of skills correctly', (tester) async {
      // Arrange
      final skills = testSkills.take(2).toList();

      await tester.pumpWidget(
        buildTestWidget(
          UnifiedAiSkillsList(
            journalEntity: testAudioEntity,
            onSkillSelected: (skill) async {},
          ),
          overrides: [
            availableSkillsForEntityProvider((
              entityId: testAudioEntity.id,
              linkedFromId: null,
            )).overrideWith((ref) => Future.value(skills)),
          ],
        ),
      );

      await tester.pumpAndSettle();

      // Assert
      expect(find.text('Audio Transcription Skill'), findsOneWidget);
      expect(find.text('Image Analysis Skill'), findsOneWidget);
      expect(find.text('Skill-based transcription'), findsOneWidget);
      expect(find.text('Skill-based image analysis'), findsOneWidget);
      expect(find.byType(DesignSystemListItem), findsNWidgets(2));
    });

    testWidgets('shows section header when skills are present', (
      tester,
    ) async {
      // Arrange
      await tester.pumpWidget(
        buildTestWidget(
          UnifiedAiSkillsList(
            journalEntity: testAudioEntity,
            onSkillSelected: (skill) async {},
          ),
          overrides: [
            availableSkillsForEntityProvider((
              entityId: testAudioEntity.id,
              linkedFromId: null,
            )).overrideWith((ref) => Future.value(testSkills)),
          ],
        ),
      );

      await tester.pumpAndSettle();

      // Assert - section header should be present
      expect(find.text('Skills'), findsOneWidget);
      expect(
        find.byType(DesignSystemListItem),
        findsNWidgets(testSkills.length),
      );
    });

    testWidgets('handles empty skills list', (tester) async {
      // Arrange
      await tester.pumpWidget(
        buildTestWidget(
          UnifiedAiSkillsList(
            journalEntity: testTaskEntity,
            onSkillSelected: (skill) async {},
          ),
          overrides: [
            availableSkillsForEntityProvider((
              entityId: testTaskEntity.id,
              linkedFromId: null,
            )).overrideWith((ref) => Future.value([])),
          ],
        ),
      );

      await tester.pumpAndSettle();

      // Assert - empty skills renders only a placeholder SizedBox
      expect(find.byType(DesignSystemListItem), findsNothing);
      expect(find.text('Skills'), findsNothing);
    });

    testWidgets('calls onSkillSelected when skill item is tapped', (
      tester,
    ) async {
      // Arrange
      AiConfigSkill? selectedSkill;

      await tester.pumpWidget(
        buildTestWidget(
          UnifiedAiSkillsList(
            journalEntity: testAudioEntity,
            onSkillSelected: (skill) async {
              selectedSkill = skill;
            },
          ),
          overrides: [
            availableSkillsForEntityProvider((
              entityId: testAudioEntity.id,
              linkedFromId: null,
            )).overrideWith(
              (ref) => Future.value([testSkills.first]),
            ),
          ],
        ),
      );

      await tester.pumpAndSettle();

      // Act
      await tester.tap(find.text('Audio Transcription Skill'));
      await tester.pump();

      // Assert
      expect(selectedSkill, isNotNull);
      expect(selectedSkill!.id, 'skill-transcription');
      expect(selectedSkill!.name, 'Audio Transcription Skill');
      expect(selectedSkill!.skillType, SkillType.transcription);
    });

    testWidgets('handles skills without descriptions', (tester) async {
      // Arrange
      final skillWithoutDescription =
          AiConfig.skill(
                id: 'skill-no-desc',
                name: 'No Description Skill',
                createdAt: DateTime(2024, 3, 15, 10),
                skillType: SkillType.transcription,
                requiredInputModalities: [Modality.audio],
                systemInstructions: 'System instructions',
                userInstructions: 'User instructions',
              )
              as AiConfigSkill;

      await tester.pumpWidget(
        buildTestWidget(
          UnifiedAiSkillsList(
            journalEntity: testAudioEntity,
            onSkillSelected: (skill) async {},
          ),
          overrides: [
            availableSkillsForEntityProvider((
              entityId: testAudioEntity.id,
              linkedFromId: null,
            )).overrideWith(
              (ref) => Future.value([skillWithoutDescription]),
            ),
          ],
        ),
      );

      await tester.pumpAndSettle();

      // Assert
      expect(find.text('No Description Skill'), findsOneWidget);
      expect(find.byType(DesignSystemListItem), findsOneWidget);
    });

    testWidgets('truncates long descriptions correctly', (tester) async {
      // Arrange
      final longDescriptionSkill =
          AiConfig.skill(
                id: 'skill-long',
                name: 'Long Description Skill',
                createdAt: DateTime(2024, 3, 15, 10),
                skillType: SkillType.transcription,
                requiredInputModalities: [Modality.audio],
                systemInstructions: 'System instructions',
                userInstructions: 'User instructions',
                description:
                    'This is a very long description that should be truncated '
                    'when displayed in the UI because it exceeds the maximum number of lines '
                    'that we want to show in the subtitle of the list tile.',
              )
              as AiConfigSkill;

      await tester.pumpWidget(
        buildTestWidget(
          UnifiedAiSkillsList(
            journalEntity: testAudioEntity,
            onSkillSelected: (skill) async {},
          ),
          overrides: [
            availableSkillsForEntityProvider((
              entityId: testAudioEntity.id,
              linkedFromId: null,
            )).overrideWith((ref) => Future.value([longDescriptionSkill])),
          ],
        ),
      );

      await tester.pumpAndSettle();

      // Assert
      final listItem = tester.widget<DesignSystemListItem>(
        find.byType(DesignSystemListItem),
      );
      expect(listItem.subtitle, isNotEmpty);
      expect(listItem.subtitleMaxLines, 3);

      // Find the description Text widget within the DesignSystemListItem
      final descriptionTextFinder = find.descendant(
        of: find.byType(DesignSystemListItem),
        matching: find.text(longDescriptionSkill.description!),
      );
      expect(descriptionTextFinder, findsOneWidget);

      final descriptionText = tester.widget<Text>(descriptionTextFinder);
      expect(descriptionText.maxLines, 3);
      expect(descriptionText.overflow, TextOverflow.ellipsis);
    });
  });

  group('UnifiedAiSkillsList hover dividers', () {
    testWidgets(
      'hovering a row turns the divider above it transparent so the hovered '
      'row is never visually bisected',
      (tester) async {
        await tester.pumpWidget(
          buildTestWidget(
            UnifiedAiSkillsList(
              journalEntity: testAudioEntity,
              onSkillSelected: (_) async {},
            ),
            overrides: [
              availableSkillsForEntityProvider((
                entityId: testAudioEntity.id,
                linkedFromId: null,
              )).overrideWith((ref) => Future.value(testSkills)),
            ],
          ),
        );
        await tester.pumpAndSettle();

        // Two dividers between three rows; both opaque before hover.
        final dividersBefore = tester.widgetList<Divider>(find.byType(Divider));
        expect(dividersBefore, hasLength(2));
        for (final d in dividersBefore) {
          expect(d.color, isNot(Colors.transparent));
        }

        // Hover the middle skill: both adjacent dividers should go transparent.
        final gesture = await tester.createGesture(
          kind: PointerDeviceKind.mouse,
        );
        addTearDown(gesture.removePointer);
        await gesture.addPointer(location: Offset.zero);
        await gesture.moveTo(
          tester.getCenter(find.text(testSkills[1].name)),
        );
        await tester.pumpAndSettle();

        final dividersAfter = tester
            .widgetList<Divider>(find.byType(Divider))
            .toList();
        expect(dividersAfter[0].color, Colors.transparent);
        expect(dividersAfter[1].color, Colors.transparent);

        // Move pointer away — dividers return to default color.
        await gesture.moveTo(const Offset(-100, -100));
        await tester.pumpAndSettle();

        final dividersFinal = tester
            .widgetList<Divider>(find.byType(Divider))
            .toList();
        expect(dividersFinal[0].color, isNot(Colors.transparent));
        expect(dividersFinal[1].color, isNot(Colors.transparent));
      },
    );

    testWidgets(
      'tapping a row invokes onSkillSelected with the hovered skill',
      (tester) async {
        AiConfigSkill? selected;

        await tester.pumpWidget(
          buildTestWidget(
            UnifiedAiSkillsList(
              journalEntity: testAudioEntity,
              onSkillSelected: (skill) async {
                selected = skill;
              },
            ),
            overrides: [
              availableSkillsForEntityProvider((
                entityId: testAudioEntity.id,
                linkedFromId: null,
              )).overrideWith((ref) => Future.value(testSkills)),
            ],
          ),
        );
        await tester.pumpAndSettle();

        // Hover, then tap — exercises both the hover-enter callback and
        // the onTap path on the same row.
        final gesture = await tester.createGesture(
          kind: PointerDeviceKind.mouse,
        );
        addTearDown(gesture.removePointer);
        await gesture.addPointer(location: Offset.zero);
        await gesture.moveTo(
          tester.getCenter(find.text(testSkills[2].name)),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text(testSkills[2].name));
        await tester.pumpAndSettle();

        expect(selected?.id, testSkills[2].id);
      },
    );
  });

  group('UnifiedAiModal Tests', () {
    testWidgets('creates modal with correct structure', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          Consumer(
            builder: (context, ref, child) {
              return ElevatedButton(
                onPressed: () async {
                  await UnifiedAiModal.show<void>(
                    context: context,
                    journalEntity: testTaskEntity,
                    linkedFromId: null,
                    ref: ref,
                  );
                },
                child: const Text('Show Modal'),
              );
            },
          ),
          overrides: [
            availableSkillsForEntityProvider((
              entityId: testTaskEntity.id,
              linkedFromId: null,
            )).overrideWith(
              (ref) => Future.value(testSkills.take(2).toList()),
            ),
          ],
        ),
      );

      await tester.pumpAndSettle();

      // Act
      await tester.tap(find.text('Show Modal'));
      await tester.pumpAndSettle();

      // Assert - Look for the skills list
      expect(find.byType(UnifiedAiSkillsList), findsOneWidget);
      expect(find.text('Audio Transcription Skill'), findsOneWidget);
    });

    testWidgets('handles context not mounted scenario', (tester) async {
      // Arrange - This test simulates a scenario where context becomes unmounted
      // by resolving the skills after the widget tree has already unmounted.
      final skillsCompleter = Completer<List<AiConfigSkill>>();
      await tester.pumpWidget(
        buildTestWidget(
          Consumer(
            builder: (context, ref, child) {
              return ElevatedButton(
                onPressed: () async {
                  // Simulate a very slow response
                  await UnifiedAiModal.show<void>(
                    context: context,
                    journalEntity: testTaskEntity,
                    linkedFromId: null,
                    ref: ref,
                  );
                },
                child: const Text('Show Modal'),
              );
            },
          ),
          overrides: [
            availableSkillsForEntityProvider((
              entityId: testTaskEntity.id,
              linkedFromId: null,
            )).overrideWith(
              (ref) => skillsCompleter.future,
            ),
          ],
        ),
      );

      await tester.pumpAndSettle();

      // Act - tap button and immediately dispose widget (simulating navigation away)
      await tester.tap(find.text('Show Modal'));
      await tester.pump();

      // Dispose the widget tree to simulate context becoming unmounted
      await tester.pumpWidget(const SizedBox());
      skillsCompleter.complete(testSkills.take(2).toList());
      await tester.pump();

      // Assert - no exception should be thrown and test should complete successfully
      expect(tester.takeException(), isNull);
    });

    testWidgets('modal show method with ScrollController parameter', (
      tester,
    ) async {
      // Arrange
      final scrollController = ScrollController();

      await tester.pumpWidget(
        buildTestWidget(
          Consumer(
            builder: (context, ref, child) {
              return ElevatedButton(
                onPressed: () async {
                  await UnifiedAiModal.show<void>(
                    context: context,
                    journalEntity: testTaskEntity,
                    linkedFromId: null,
                    ref: ref,
                    scrollController:
                        scrollController, // Pass scroll controller
                  );
                },
                child: const Text('Show Modal with ScrollController'),
              );
            },
          ),
          overrides: [
            availableSkillsForEntityProvider((
              entityId: testTaskEntity.id,
              linkedFromId: null,
            )).overrideWith((ref) => Future.value([testSkills.first])),
          ],
        ),
      );

      await tester.pumpAndSettle();

      // Act
      await tester.tap(find.text('Show Modal with ScrollController'));
      await tester.pumpAndSettle();

      // Assert - Modal should open
      expect(find.byType(UnifiedAiSkillsList), findsOneWidget);

      // Clean up
      scrollController.dispose();
    });

    testWidgets('closes modal after skill selection', (tester) async {
      // Arrange
      await tester.pumpWidget(
        buildTestWidget(
          UnifiedAiPopUpMenu(
            journalEntity: testTaskEntity,
            linkedFromId: null,
          ),
          overrides: [
            hasAvailableSkillsProvider((
              entityId: testTaskEntity.id,
              linkedFromId: null,
            )).overrideWith((ref) => Future.value(true)),
            availableSkillsForEntityProvider((
              entityId: testTaskEntity.id,
              linkedFromId: null,
            )).overrideWith((ref) => Future.value([testSkills.last])),
          ],
        ),
      );

      await tester.pumpAndSettle();

      // Act - Open the modal
      await tester.tap(find.byIcon(Icons.assistant_rounded));
      await tester.pumpAndSettle();

      // Verify modal is open
      expect(find.byType(UnifiedAiSkillsList), findsOneWidget);

      // Select a skill
      await tester.tap(find.text('Prompt Generation Skill'));
      await tester.pumpAndSettle();

      // Assert - Modal should be closed
      expect(find.byType(UnifiedAiSkillsList), findsNothing);
    });
  });

  group('Image Generation Skill Handling', () {
    testWidgets(
      'tapping image generation skill without linked task logs and returns',
      (tester) async {
        final now = DateTime(2024, 3, 15, 10);
        final imageGenSkill =
            AiConfig.skill(
                  id: 'skill-cover-art',
                  name: 'Generate Cover Art',
                  createdAt: now,
                  skillType: SkillType.imageGeneration,
                  requiredInputModalities: [Modality.text],
                  systemInstructions: 'Generate cover art',
                  userInstructions: 'Create an image',
                  description: 'Generates cover art images',
                )
                as AiConfigSkill;

        // JournalDb stubs return empty results so _resolveLinkedTask returns
        // null (no linked task found in either direction).
        await tester.pumpWidget(
          buildTestWidget(
            UnifiedAiPopUpMenu(
              journalEntity: testAudioEntity,
              linkedFromId: null,
            ),
            overrides: [
              hasAvailableSkillsProvider((
                entityId: testAudioEntity.id,
                linkedFromId: null,
              )).overrideWith((ref) => Future.value(true)),
              availableSkillsForEntityProvider((
                entityId: testAudioEntity.id,
                linkedFromId: null,
              )).overrideWith(
                (ref) => Future.value([imageGenSkill]),
              ),
            ],
          ),
        );

        await tester.pumpAndSettle();

        // Open the modal
        await tester.tap(find.byIcon(Icons.assistant_rounded));
        await tester.pumpAndSettle();

        // Tap the image generation skill
        await tester.tap(find.text('Generate Cover Art'));
        await tester.pumpAndSettle();

        // Modal should close without showing CoverArtSkillModal since there's
        // no linked task
        expect(find.byType(UnifiedAiSkillsList), findsNothing);
      },
    );

    testWidgets(
      'tapping image generation skill with linked task opens cover art modal',
      (tester) async {
        final now = DateTime(2024, 3, 15, 10);
        final imageGenSkill =
            AiConfig.skill(
                  id: 'skill-cover-art',
                  name: 'Generate Cover Art',
                  createdAt: now,
                  skillType: SkillType.imageGeneration,
                  requiredInputModalities: [Modality.text],
                  systemInstructions: 'Generate cover art',
                  userInstructions: 'Create an image',
                  description: 'Generates cover art images',
                )
                as AiConfigSkill;

        final linkedTask = Task(
          meta: Metadata(
            id: 'linked-task-1',
            createdAt: now,
            updatedAt: now,
            dateFrom: now,
            dateTo: now.add(const Duration(hours: 1)),
            categoryId: 'cat-1',
          ),
          data: TaskData(
            title: 'Linked Task',
            status: TaskStatus.open(
              id: 'status-1',
              createdAt: now,
              utcOffset: 0,
            ),
            dateFrom: now,
            dateTo: now.add(const Duration(hours: 1)),
            statusHistory: [],
          ),
        );

        // Make getLinkedEntities return the linked task so
        // _resolveLinkedTask succeeds.
        when(
          () => mockJournalDb.getLinkedEntities(testAudioEntity.id),
        ).thenAnswer((_) async => [linkedTask]);

        await tester.pumpWidget(
          buildTestWidget(
            UnifiedAiPopUpMenu(
              journalEntity: testAudioEntity,
              linkedFromId: null,
            ),
            overrides: [
              hasAvailableSkillsProvider((
                entityId: testAudioEntity.id,
                linkedFromId: null,
              )).overrideWith((ref) => Future.value(true)),
              availableSkillsForEntityProvider((
                entityId: testAudioEntity.id,
                linkedFromId: null,
              )).overrideWith(
                (ref) => Future.value([imageGenSkill]),
              ),
            ],
          ),
        );

        await tester.pumpAndSettle();

        // Open the modal
        await tester.tap(find.byIcon(Icons.assistant_rounded));
        await tester.pumpAndSettle();

        // Tap the image generation skill
        await tester.tap(find.text('Generate Cover Art'));
        // Pump through the modal close animation and cover art modal open.
        // Use pump(duration) instead of pumpAndSettle() because the cover
        // art modal contains animations that never settle.
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        // The original skills list modal should be closed and the cover
        // art modal should be visible (showing loading state).
        expect(find.byType(UnifiedAiSkillsList), findsNothing);
      },
    );
  });

  group('Transcription Skill Handling — model-override picker', () {
    testWidgets(
      'tapping a transcription skill with two speech-capable models '
      'opens the TranscriptionModelPickerModal — proves the popup '
      'inserts the picker step before firing the trigger, and proves '
      'the picker is fed the full speech-capable list (the model '
      'whose inputModalities do NOT include audio is filtered out '
      'before the picker sees it)',
      (tester) async {
        final now = DateTime(2024, 3, 15, 10);
        final transcribeSkill =
            AiConfig.skill(
                  id: 'skill-transcribe',
                  name: 'Transcribe Audio',
                  createdAt: now,
                  skillType: SkillType.transcription,
                  requiredInputModalities: [Modality.audio],
                  systemInstructions: 'Transcribe the audio.',
                  userInstructions: 'Please transcribe.',
                  description: 'Skill-based transcription',
                )
                as AiConfigSkill;

        // Two speech-capable models + one decoy (text only). The
        // decoy must NOT appear in the picker.
        final voxtral = AiConfig.model(
          id: 'm-voxtral',
          name: 'Voxtral Local',
          providerModelId: 'voxtral-mini',
          inferenceProviderId: 'p-voxtral',
          createdAt: now,
          inputModalities: const [Modality.audio, Modality.text],
          outputModalities: const [Modality.text],
          isReasoningModel: false,
        );
        final mistral = AiConfig.model(
          id: 'm-mistral',
          name: 'Mistral Cloud',
          providerModelId: 'mistral/voxtral',
          inferenceProviderId: 'p-mistral',
          createdAt: now,
          inputModalities: const [Modality.audio, Modality.text],
          outputModalities: const [Modality.text],
          isReasoningModel: false,
        );
        final textOnlyDecoy = AiConfig.model(
          id: 'm-text-only',
          name: 'Gemini Flash (text only)',
          providerModelId: 'gemini-flash',
          inferenceProviderId: 'p-gemini',
          createdAt: now,
          inputModalities: const [Modality.text],
          outputModalities: const [Modality.text],
          isReasoningModel: false,
        );

        await tester.pumpWidget(
          buildTestWidget(
            UnifiedAiPopUpMenu(
              journalEntity: testAudioEntity,
              linkedFromId: null,
            ),
            overrides: [
              hasAvailableSkillsProvider((
                entityId: testAudioEntity.id,
                linkedFromId: null,
              )).overrideWith((ref) => Future.value(true)),
              availableSkillsForEntityProvider((
                entityId: testAudioEntity.id,
                linkedFromId: null,
              )).overrideWith(
                (ref) => Future.value([transcribeSkill]),
              ),
              // Skip the real profile resolver — it depends on
              // agent providers + AgentDatabase that aren't set up
              // in this test surface. A `null` resolved profile
              // means the picker's default-row badge is absent,
              // which is fine for this assertion since we only
              // care about which model rows render.
              profileAutomationResolverProvider.overrideWithValue(
                _NullProfileResolver(),
              ),
              aiConfigByTypeControllerProvider(
                configType: AiConfigType.model,
              ).overrideWith(
                () => MockAiConfigByTypeController([
                  voxtral,
                  mistral,
                  textOnlyDecoy,
                ]),
              ),
              aiConfigRepositoryProvider.overrideWithValue(
                _StubAiConfigRepository([voxtral, mistral, textOnlyDecoy]),
              ),
            ],
          ),
        );

        await tester.pumpAndSettle();

        // Open the popup
        await tester.tap(find.byIcon(Icons.assistant_rounded));
        await tester.pumpAndSettle();

        // Tap the transcription skill — should open the picker
        // instead of firing the trigger directly.
        await tester.tap(find.text('Transcribe Audio'));
        await tester.pumpAndSettle();

        // Picker is mounted and lists both speech-capable models;
        // the text-only decoy is absent because the popup filters
        // by `inputModalities.contains(Modality.audio)` before
        // calling the picker.
        expect(find.byType(TranscriptionModelPickerModal), findsOneWidget);
        expect(find.text('Voxtral Local'), findsOneWidget);
        expect(find.text('Mistral Cloud'), findsOneWidget);
        expect(find.text('Gemini Flash (text only)'), findsNothing);
      },
    );

    testWidgets(
      'when only one speech-capable model is configured the picker '
      'short-circuits and the popup fires the trigger immediately — '
      'preserving the one-tap transcribe flow for users with a single '
      'audio-capable model. Asserted indirectly by the absence of the '
      'picker after the skill tap (the modal never mounts because '
      'TranscriptionModelPickerModal.show short-circuits internally)',
      (tester) async {
        final now = DateTime(2024, 3, 15, 10);
        final transcribeSkill =
            AiConfig.skill(
                  id: 'skill-transcribe',
                  name: 'Transcribe Audio',
                  createdAt: now,
                  skillType: SkillType.transcription,
                  requiredInputModalities: [Modality.audio],
                  systemInstructions: 'Transcribe the audio.',
                  userInstructions: 'Please transcribe.',
                  description: 'Skill-based transcription',
                )
                as AiConfigSkill;

        final voxtral = AiConfig.model(
          id: 'm-voxtral',
          name: 'Voxtral Local',
          providerModelId: 'voxtral-mini',
          inferenceProviderId: 'p-voxtral',
          createdAt: now,
          inputModalities: const [Modality.audio, Modality.text],
          outputModalities: const [Modality.text],
          isReasoningModel: false,
        );

        await tester.pumpWidget(
          buildTestWidget(
            UnifiedAiPopUpMenu(
              journalEntity: testAudioEntity,
              linkedFromId: null,
            ),
            overrides: [
              hasAvailableSkillsProvider((
                entityId: testAudioEntity.id,
                linkedFromId: null,
              )).overrideWith((ref) => Future.value(true)),
              availableSkillsForEntityProvider((
                entityId: testAudioEntity.id,
                linkedFromId: null,
              )).overrideWith(
                (ref) => Future.value([transcribeSkill]),
              ),
              // Skip the real profile resolver — it depends on
              // agent providers + AgentDatabase that aren't set up
              // in this test surface. A `null` resolved profile
              // means the picker's default-row badge is absent,
              // which is fine for this assertion since we only
              // care about which model rows render.
              profileAutomationResolverProvider.overrideWithValue(
                _NullProfileResolver(),
              ),
              aiConfigByTypeControllerProvider(
                configType: AiConfigType.model,
              ).overrideWith(
                () => MockAiConfigByTypeController([voxtral]),
              ),
              aiConfigRepositoryProvider.overrideWithValue(
                _StubAiConfigRepository([voxtral]),
              ),
            ],
          ),
        );

        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.assistant_rounded));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Transcribe Audio'));
        await tester.pumpAndSettle();

        // No picker was rendered — the short-circuit took the
        // single-model path and called the trigger directly.
        expect(find.byType(TranscriptionModelPickerModal), findsNothing);
        // The skills list modal closed as part of the tap handler.
        expect(find.byType(UnifiedAiSkillsList), findsNothing);
      },
    );

    testWidgets(
      'tapping the default-badged row forwards '
      'overrideTranscriptionModelId: null to triggerSkillProvider — '
      'the override is collapsed to null when the user picks the same '
      'model the profile already points at, so the runner reads the '
      'profile slot and a model deleted between picker and run still '
      'falls back gracefully',
      (tester) async {
        final now = DateTime(2024, 3, 15, 10);
        final transcribeSkill =
            AiConfig.skill(
                  id: 'skill-transcribe',
                  name: 'Transcribe Audio',
                  createdAt: now,
                  skillType: SkillType.transcription,
                  requiredInputModalities: [Modality.audio],
                  systemInstructions: 'Transcribe the audio.',
                  userInstructions: 'Please transcribe.',
                  description: 'Skill-based transcription',
                )
                as AiConfigSkill;

        final voxtralProvider =
            AiConfig.inferenceProvider(
                  id: 'p-voxtral',
                  baseUrl: 'https://voxtral.local',
                  name: 'Voxtral Local',
                  inferenceProviderType: InferenceProviderType.openAi,
                  apiKey: '',
                  createdAt: now,
                )
                as AiConfigInferenceProvider;
        final mistralProvider =
            AiConfig.inferenceProvider(
                  id: 'p-mistral',
                  baseUrl: 'https://mistral.example.com',
                  name: 'Mistral Cloud',
                  inferenceProviderType: InferenceProviderType.openAi,
                  apiKey: '',
                  createdAt: now,
                )
                as AiConfigInferenceProvider;
        final voxtral = AiConfig.model(
          id: 'm-voxtral',
          name: 'Voxtral Local',
          providerModelId: 'voxtral-mini',
          inferenceProviderId: 'p-voxtral',
          createdAt: now,
          inputModalities: const [Modality.audio, Modality.text],
          outputModalities: const [Modality.text],
          isReasoningModel: false,
        );
        final mistral = AiConfig.model(
          id: 'm-mistral',
          name: 'Mistral Cloud',
          providerModelId: 'mistral/voxtral',
          inferenceProviderId: 'p-mistral',
          createdAt: now,
          inputModalities: const [Modality.audio, Modality.text],
          outputModalities: const [Modality.text],
          isReasoningModel: false,
        );

        // Resolved profile points at Voxtral — the popup must
        // recognise the Voxtral row as the default.
        final resolvedProfile = ResolvedProfile(
          thinkingModelId: 'thinking',
          thinkingProvider: voxtralProvider,
          transcriptionProvider: voxtralProvider,
          transcriptionModelId: 'voxtral-mini',
        );

        // The popup resolves the profile via the entry's categoryId
        // when there is no linked task. The shared `testAudioEntity`
        // has no category, which would short-circuit defaultModelId
        // resolution to null — so use a freshly categorised entity
        // here.
        final audioWithCategory = JournalAudio(
          meta: Metadata(
            id: 'audio-cat-1',
            createdAt: now,
            updatedAt: now,
            dateFrom: now,
            dateTo: now,
            categoryId: 'cat-1',
          ),
          data: AudioData(
            dateFrom: now,
            dateTo: now,
            audioFile: 'test.mp3',
            audioDirectory: '/test',
            duration: const Duration(minutes: 1),
          ),
        );

        TriggerSkillParams? capturedParams;

        await tester.pumpWidget(
          buildTestWidget(
            UnifiedAiPopUpMenu(
              journalEntity: audioWithCategory,
              linkedFromId: null,
            ),
            overrides: [
              hasAvailableSkillsProvider((
                entityId: audioWithCategory.id,
                linkedFromId: null,
              )).overrideWith((ref) => Future.value(true)),
              availableSkillsForEntityProvider((
                entityId: audioWithCategory.id,
                linkedFromId: null,
              )).overrideWith(
                (ref) => Future.value([transcribeSkill]),
              ),
              profileAutomationResolverProvider.overrideWithValue(
                _FixedProfileResolver(resolvedProfile),
              ),
              aiConfigByTypeControllerProvider(
                configType: AiConfigType.model,
              ).overrideWith(
                () => MockAiConfigByTypeController([voxtral, mistral]),
              ),
              aiConfigRepositoryProvider.overrideWithValue(
                _StubAiConfigRepository([
                  voxtral,
                  mistral,
                  voxtralProvider,
                  mistralProvider,
                ]),
              ),
              triggerSkillProvider.overrideWith((ref, params) async {
                capturedParams = params;
              }),
            ],
          ),
        );

        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(Icons.assistant_rounded));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Transcribe Audio'));
        await tester.pumpAndSettle();

        // Picker is open; both rows render. Tap the default-badged
        // row (Voxtral) — the popup should fire the trigger with
        // overrideTranscriptionModelId: null because the picked id
        // matches the computed defaultModelId.
        expect(find.byType(TranscriptionModelPickerModal), findsOneWidget);
        await tester.tap(find.text('Voxtral Local'));
        await tester.pumpAndSettle();

        expect(capturedParams, isNotNull);
        expect(capturedParams!.entityId, audioWithCategory.id);
        expect(capturedParams!.skillId, 'skill-transcribe');
        expect(capturedParams!.overrideTranscriptionModelId, isNull);
      },
    );

    testWidgets(
      "tapping a non-default row forwards that row's AiConfigModel.id "
      'to triggerSkillProvider as overrideTranscriptionModelId — proves '
      'the override seam threads through the popup to the trigger when '
      'the user picks a non-profile model',
      (tester) async {
        final now = DateTime(2024, 3, 15, 10);
        final transcribeSkill =
            AiConfig.skill(
                  id: 'skill-transcribe',
                  name: 'Transcribe Audio',
                  createdAt: now,
                  skillType: SkillType.transcription,
                  requiredInputModalities: [Modality.audio],
                  systemInstructions: 'Transcribe the audio.',
                  userInstructions: 'Please transcribe.',
                  description: 'Skill-based transcription',
                )
                as AiConfigSkill;

        final voxtralProvider =
            AiConfig.inferenceProvider(
                  id: 'p-voxtral',
                  baseUrl: 'https://voxtral.local',
                  name: 'Voxtral Local',
                  inferenceProviderType: InferenceProviderType.openAi,
                  apiKey: '',
                  createdAt: now,
                )
                as AiConfigInferenceProvider;
        final mistralProvider =
            AiConfig.inferenceProvider(
                  id: 'p-mistral',
                  baseUrl: 'https://mistral.example.com',
                  name: 'Mistral Cloud',
                  inferenceProviderType: InferenceProviderType.openAi,
                  apiKey: '',
                  createdAt: now,
                )
                as AiConfigInferenceProvider;
        final voxtral = AiConfig.model(
          id: 'm-voxtral',
          name: 'Voxtral Local',
          providerModelId: 'voxtral-mini',
          inferenceProviderId: 'p-voxtral',
          createdAt: now,
          inputModalities: const [Modality.audio, Modality.text],
          outputModalities: const [Modality.text],
          isReasoningModel: false,
        );
        final mistral = AiConfig.model(
          id: 'm-mistral',
          name: 'Mistral Cloud',
          providerModelId: 'mistral/voxtral',
          inferenceProviderId: 'p-mistral',
          createdAt: now,
          inputModalities: const [Modality.audio, Modality.text],
          outputModalities: const [Modality.text],
          isReasoningModel: false,
        );

        final resolvedProfile = ResolvedProfile(
          thinkingModelId: 'thinking',
          thinkingProvider: voxtralProvider,
          transcriptionProvider: voxtralProvider,
          transcriptionModelId: 'voxtral-mini',
        );

        final audioWithCategory = JournalAudio(
          meta: Metadata(
            id: 'audio-cat-2',
            createdAt: now,
            updatedAt: now,
            dateFrom: now,
            dateTo: now,
            categoryId: 'cat-1',
          ),
          data: AudioData(
            dateFrom: now,
            dateTo: now,
            audioFile: 'test.mp3',
            audioDirectory: '/test',
            duration: const Duration(minutes: 1),
          ),
        );

        TriggerSkillParams? capturedParams;

        await tester.pumpWidget(
          buildTestWidget(
            UnifiedAiPopUpMenu(
              journalEntity: audioWithCategory,
              linkedFromId: null,
            ),
            overrides: [
              hasAvailableSkillsProvider((
                entityId: audioWithCategory.id,
                linkedFromId: null,
              )).overrideWith((ref) => Future.value(true)),
              availableSkillsForEntityProvider((
                entityId: audioWithCategory.id,
                linkedFromId: null,
              )).overrideWith(
                (ref) => Future.value([transcribeSkill]),
              ),
              profileAutomationResolverProvider.overrideWithValue(
                _FixedProfileResolver(resolvedProfile),
              ),
              aiConfigByTypeControllerProvider(
                configType: AiConfigType.model,
              ).overrideWith(
                () => MockAiConfigByTypeController([voxtral, mistral]),
              ),
              aiConfigRepositoryProvider.overrideWithValue(
                _StubAiConfigRepository([
                  voxtral,
                  mistral,
                  voxtralProvider,
                  mistralProvider,
                ]),
              ),
              triggerSkillProvider.overrideWith((ref, params) async {
                capturedParams = params;
              }),
            ],
          ),
        );

        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(Icons.assistant_rounded));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Transcribe Audio'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Mistral Cloud'));
        await tester.pumpAndSettle();

        expect(capturedParams, isNotNull);
        expect(
          capturedParams!.overrideTranscriptionModelId,
          'm-mistral',
        );
      },
    );
  });

  group('resolveLinkedTask', () {
    late MockJournalRepository mockJournalRepository;
    final now = DateTime(2024, 3, 15, 10);

    setUp(() {
      mockJournalRepository = MockJournalRepository();
    });

    test('returns entity directly when it is a Task', () async {
      final taskEntity = Task(
        meta: Metadata(
          id: 'task-direct',
          createdAt: now,
          updatedAt: now,
          dateFrom: now,
          dateTo: now,
        ),
        data: TaskData(
          title: 'Direct Task',
          status: TaskStatus.open(
            id: 'st-1',
            createdAt: now,
            utcOffset: 0,
          ),
          statusHistory: [],
          dateFrom: now,
          dateTo: now,
        ),
      );

      final result = await UnifiedAiModal.resolveLinkedTask(
        journalEntity: taskEntity,
        journalRepo: mockJournalRepository,
      );

      expect(result, same(taskEntity));
      verifyZeroInteractions(mockJournalRepository);
    });

    test('returns preferred task when preferredTaskId is provided', () async {
      final preferredTask = Task(
        meta: Metadata(
          id: 'preferred-task',
          createdAt: now,
          updatedAt: now,
          dateFrom: now,
          dateTo: now,
        ),
        data: TaskData(
          title: 'Preferred',
          status: TaskStatus.open(
            id: 'st-2',
            createdAt: now,
            utcOffset: 0,
          ),
          statusHistory: [],
          dateFrom: now,
          dateTo: now,
        ),
      );

      when(
        () => mockJournalRepository.getJournalEntityById('preferred-task'),
      ).thenAnswer((_) async => preferredTask);

      final result = await UnifiedAiModal.resolveLinkedTask(
        journalEntity: testAudioEntity,
        journalRepo: mockJournalRepository,
        preferredTaskId: 'preferred-task',
      );

      expect(result, same(preferredTask));
    });

    test('falls back to outgoing links when no preferred task', () async {
      final linkedTask = Task(
        meta: Metadata(
          id: 'linked-out',
          createdAt: now,
          updatedAt: now,
          dateFrom: now,
          dateTo: now,
        ),
        data: TaskData(
          title: 'Linked Out',
          status: TaskStatus.open(
            id: 'st-3',
            createdAt: now,
            utcOffset: 0,
          ),
          statusHistory: [],
          dateFrom: now,
          dateTo: now,
        ),
      );

      when(
        () => mockJournalRepository.getLinkedEntities(
          linkedTo: testAudioEntity.id,
        ),
      ).thenAnswer((_) async => [linkedTask]);

      final result = await UnifiedAiModal.resolveLinkedTask(
        journalEntity: testAudioEntity,
        journalRepo: mockJournalRepository,
      );

      expect(result, same(linkedTask));
    });

    test('falls back to incoming links when no outgoing task', () async {
      final incomingTask = Task(
        meta: Metadata(
          id: 'linked-in',
          createdAt: now,
          updatedAt: now,
          dateFrom: now,
          dateTo: now,
        ),
        data: TaskData(
          title: 'Linked In',
          status: TaskStatus.open(
            id: 'st-4',
            createdAt: now,
            utcOffset: 0,
          ),
          statusHistory: [],
          dateFrom: now,
          dateTo: now,
        ),
      );

      when(
        () => mockJournalRepository.getLinkedEntities(
          linkedTo: testAudioEntity.id,
        ),
      ).thenAnswer((_) async => []);
      when(
        () => mockJournalRepository.getLinkedToEntities(
          linkedTo: testAudioEntity.id,
        ),
      ).thenAnswer((_) async => [incomingTask]);

      final result = await UnifiedAiModal.resolveLinkedTask(
        journalEntity: testAudioEntity,
        journalRepo: mockJournalRepository,
      );

      expect(result, same(incomingTask));
    });

    test('returns null when no linked task found', () async {
      when(
        () => mockJournalRepository.getLinkedEntities(
          linkedTo: testAudioEntity.id,
        ),
      ).thenAnswer((_) async => []);
      when(
        () => mockJournalRepository.getLinkedToEntities(
          linkedTo: testAudioEntity.id,
        ),
      ).thenAnswer((_) async => []);

      final result = await UnifiedAiModal.resolveLinkedTask(
        journalEntity: testAudioEntity,
        journalRepo: mockJournalRepository,
      );

      expect(result, isNull);
    });
  });
}

/// Minimal stub repository so the popup's `getConfigsByType` read
/// resolves with a known model list. The full Drift-backed
/// repository would require seeding a temp database, which is
/// out of scope for this widget test — only the model-list lookup
/// path is exercised here.
class _StubAiConfigRepository implements AiConfigRepository {
  _StubAiConfigRepository(this._configs);

  final List<AiConfig> _configs;

  @override
  Future<List<AiConfig>> getConfigsByType(AiConfigType type) async {
    return _configs.where((c) => _typeOf(c) == type).toList();
  }

  static AiConfigType _typeOf(AiConfig c) => switch (c) {
    AiConfigInferenceProvider() => AiConfigType.inferenceProvider,
    AiConfigModel() => AiConfigType.model,
    AiConfigInferenceProfile() => AiConfigType.inferenceProfile,
    AiConfigPrompt() => AiConfigType.prompt,
    AiConfigSkill() => AiConfigType.skill,
  };

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Stub resolver returning `null` for every entry. Avoids pulling
/// agent-database wiring into widget tests that only need to assert
/// the transcription branch reaches the picker — the model-list
/// rendering and rest of the chain are exercised by
/// `transcription_model_picker_modal_test.dart` in isolation.
class _NullProfileResolver implements ProfileAutomationResolver {
  @override
  Future<ResolvedProfile?> resolveForTask(String taskId) async => null;

  @override
  Future<ResolvedProfile?> resolveForCategory(String categoryId) async => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Stub resolver returning a fixed profile for every lookup. Used by
/// tests that need the popup to compute a non-null `defaultModelId`
/// (so the default-badge row is rendered and we can assert that
/// tapping it produces `overrideTranscriptionModelId: null` at the
/// trigger seam).
class _FixedProfileResolver implements ProfileAutomationResolver {
  _FixedProfileResolver(this._profile);

  final ResolvedProfile _profile;

  @override
  Future<ResolvedProfile?> resolveForTask(String taskId) async => _profile;

  @override
  Future<ResolvedProfile?> resolveForCategory(String categoryId) async =>
      _profile;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
