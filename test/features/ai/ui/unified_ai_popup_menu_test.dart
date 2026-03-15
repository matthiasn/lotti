import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/state/unified_ai_controller.dart';
import 'package:lotti/features/ai/ui/unified_ai_popup_menu.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/widgets/modal/modern_modal_prompt_item.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fake_entry_controller.dart';
import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';

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
            hasAvailableSkillsProvider(
              testTaskEntity.id,
            ).overrideWith((ref) => Future.value(true)),
            availableSkillsForEntityProvider(
              testTaskEntity.id,
            ).overrideWith((ref) => Future.value(testSkills)),
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
            hasAvailableSkillsProvider(
              testTaskEntity.id,
            ).overrideWith((ref) => Future.value(false)),
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
            hasAvailableSkillsProvider(
              testTaskEntity.id,
            ).overrideWith((ref) => completer.future),
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
            hasAvailableSkillsProvider(
              testTaskEntity.id,
            ).overrideWith((ref) => Future.error('Test error')),
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
            hasAvailableSkillsProvider(
              testTaskEntity.id,
            ).overrideWith((ref) => Future.value(true)),
            availableSkillsForEntityProvider(
              testTaskEntity.id,
            ).overrideWith((ref) => Future.value(testSkills)),
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
            availableSkillsForEntityProvider(
              testAudioEntity.id,
            ).overrideWith((ref) => Future.value(skills)),
          ],
        ),
      );

      await tester.pumpAndSettle();

      // Assert
      expect(find.text('Audio Transcription Skill'), findsOneWidget);
      expect(find.text('Image Analysis Skill'), findsOneWidget);
      expect(find.text('Skill-based transcription'), findsOneWidget);
      expect(find.text('Skill-based image analysis'), findsOneWidget);
      expect(find.byType(ModernModalPromptItem), findsNWidgets(2));
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
            availableSkillsForEntityProvider(
              testAudioEntity.id,
            ).overrideWith((ref) => Future.value(testSkills)),
          ],
        ),
      );

      await tester.pumpAndSettle();

      // Assert - section header should be present
      expect(find.text('Skills'), findsOneWidget);
      expect(
        find.byType(ModernModalPromptItem),
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
            availableSkillsForEntityProvider(
              testTaskEntity.id,
            ).overrideWith((ref) => Future.value([])),
          ],
        ),
      );

      await tester.pumpAndSettle();

      // Assert
      expect(find.byType(ModernModalPromptItem), findsNothing);
      expect(find.byType(Column), findsOneWidget);
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
            availableSkillsForEntityProvider(
              testAudioEntity.id,
            ).overrideWith(
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
            availableSkillsForEntityProvider(testAudioEntity.id).overrideWith(
              (ref) => Future.value([skillWithoutDescription]),
            ),
          ],
        ),
      );

      await tester.pumpAndSettle();

      // Assert
      expect(find.text('No Description Skill'), findsOneWidget);
      expect(find.byType(ModernModalPromptItem), findsOneWidget);
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
            availableSkillsForEntityProvider(
              testAudioEntity.id,
            ).overrideWith((ref) => Future.value([longDescriptionSkill])),
          ],
        ),
      );

      await tester.pumpAndSettle();

      // Assert
      final promptItem = tester.widget<ModernModalPromptItem>(
        find.byType(ModernModalPromptItem),
      );
      expect(promptItem.description, isNotEmpty);

      // Find the description Text widget within the ModernModalPromptItem
      final descriptionTextFinder = find.descendant(
        of: find.byType(ModernModalPromptItem),
        matching: find.text(longDescriptionSkill.description!),
      );
      expect(descriptionTextFinder, findsOneWidget);

      final descriptionText = tester.widget<Text>(descriptionTextFinder);
      expect(descriptionText.maxLines, 4);
      expect(descriptionText.overflow, TextOverflow.ellipsis);
    });
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
            availableSkillsForEntityProvider(testTaskEntity.id).overrideWith(
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
            availableSkillsForEntityProvider(testTaskEntity.id).overrideWith(
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
            availableSkillsForEntityProvider(
              testTaskEntity.id,
            ).overrideWith((ref) => Future.value([testSkills.first])),
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
            hasAvailableSkillsProvider(
              testTaskEntity.id,
            ).overrideWith((ref) => Future.value(true)),
            availableSkillsForEntityProvider(
              testTaskEntity.id,
            ).overrideWith((ref) => Future.value([testSkills.last])),
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
              hasAvailableSkillsProvider(
                testAudioEntity.id,
              ).overrideWith((ref) => Future.value(true)),
              availableSkillsForEntityProvider(
                testAudioEntity.id,
              ).overrideWith(
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
              hasAvailableSkillsProvider(
                testAudioEntity.id,
              ).overrideWith((ref) => Future.value(true)),
              availableSkillsForEntityProvider(
                testAudioEntity.id,
              ).overrideWith(
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
