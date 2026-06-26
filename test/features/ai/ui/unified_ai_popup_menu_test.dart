import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/state/skill_trigger_providers.dart';
import 'package:lotti/features/ai/ui/unified_ai_popup_menu.dart';
import 'package:lotti/features/ai/ui/unified_ai_skills_modal.dart';
import 'package:lotti/widgets/app_bar/glass_action_button.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fake_entry_controller.dart';
import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';

void main() {
  late JournalEntity testTaskEntity;
  late JournalEntity testJournalEntry;
  late JournalEntity testImageEntity;
  late JournalEntity testAudioEntity;
  late List<AiConfigSkill> testSkills;
  late MockJournalDb mockJournalDb;
  late List<Override> defaultOverrides;

  setUpAll(registerAllFallbackValues);

  setUp(() async {
    // Registers DomainLogger, JournalDb and UpdateNotifications (with an
    // empty updateStream stub) in GetIt.
    final mocks = await setUpTestGetIt();
    mockJournalDb = mocks.journalDb;

    // Mock JournalDb methods - linksFromId returns a Selectable
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
      entryControllerProvider('task-1').overrideWith(
        () => FakeEntryController(testTaskEntity),
      ),
      entryControllerProvider('entry-1').overrideWith(
        () => FakeEntryController(testJournalEntry),
      ),
      entryControllerProvider('image-1').overrideWith(
        () => FakeEntryController(testImageEntity),
      ),
      entryControllerProvider('audio-1').overrideWith(
        () => FakeEntryController(testAudioEntity),
      ),
    ];
  });

  tearDown(tearDownTestGetIt);

  // Helper function to build test widget
  /// Thin wrapper over the central [makeTestableWidgetNoScroll] (DS theme,
  /// localizations, phone media query) that adds the shared default
  /// overrides and a host Scaffold.
  Widget buildTestWidget(
    Widget child, {
    List<Override> overrides = const [],
  }) {
    return makeTestableWidgetNoScroll(
      Scaffold(body: child),
      overrides: [
        ...defaultOverrides,
        ...overrides,
      ],
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

      await tester.pump();

      await tester.pump(const Duration(milliseconds: 300));

      // Assert
      expect(find.byIcon(Icons.assistant_outlined), findsOneWidget);
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

      await tester.pump();

      await tester.pump(const Duration(milliseconds: 300));

      // Assert
      expect(find.byIcon(Icons.assistant_outlined), findsNothing);
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
      expect(find.byIcon(Icons.assistant_outlined), findsNothing);
      expect(find.byType(IconButton), findsNothing);
      expect(find.byType(SizedBox), findsOneWidget);

      // Complete to avoid hanging test
      completer.complete(false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
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

      await tester.pump();

      await tester.pump(const Duration(milliseconds: 300));

      // Assert
      expect(find.byIcon(Icons.assistant_outlined), findsNothing);
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

      await tester.pump();

      await tester.pump(const Duration(milliseconds: 300));

      // Act
      await tester.tap(find.byIcon(Icons.assistant_outlined));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Assert - check for the skills list
      expect(find.byType(UnifiedAiSkillsList), findsOneWidget);
    });

    testWidgets(
      'renders a plain IconButton with the given color when iconColor is set '
      '(no glass badge on a flat surface), and tapping it opens the modal',
      (tester) async {
        // Arrange — a non-null iconColor on a normal card surface should NOT
        // select the glass badge (its blur reads as a dim badge on a flat
        // card); it stays a standard IconButton tinted with the color.
        await tester.pumpWidget(
          buildTestWidget(
            UnifiedAiPopUpMenu(
              journalEntity: testTaskEntity,
              linkedFromId: null,
              iconColor: const Color(0xFF00FF00),
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

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Assert — standard IconButton (not glass), icon adopts the color.
        expect(find.byType(IconButton), findsOneWidget);
        expect(find.byType(GlassActionButton), findsNothing);
        final icon = tester.widget<Icon>(
          find.byIcon(Icons.assistant_outlined),
        );
        expect(icon.color, const Color(0xFF00FF00));

        // Act — tapping opens the unified AI modal.
        await tester.tap(find.byType(IconButton));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.byType(UnifiedAiSkillsList), findsOneWidget);
      },
    );

    testWidgets(
      'renders GlassActionButton when useGlassButton is true (over an image)',
      (tester) async {
        await tester.pumpWidget(
          buildTestWidget(
            UnifiedAiPopUpMenu(
              journalEntity: testTaskEntity,
              linkedFromId: null,
              iconColor: const Color(0xFF00FF00),
              useGlassButton: true,
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

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.byType(GlassActionButton), findsOneWidget);
        expect(find.byType(IconButton), findsNothing);
      },
    );
  });
}
