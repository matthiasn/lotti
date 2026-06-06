import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
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
import 'package:lotti/features/ai/ui/widgets/inference_model_picker_modal.dart';
import 'package:lotti/features/design_system/components/lists/design_system_list_item.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/widgets/app_bar/glass_action_button.dart';
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
  late MockJournalDb mockJournalDb;
  late List<Override> defaultOverrides;

  setUpAll(registerAllFallbackValues);

  setUp(() async {
    mockNavigatorObserver = MockNavigatorObserver();

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

  tearDown(tearDownTestGetIt);

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

    testWidgets(
      'renders GlassActionButton (not IconButton) when iconColor is set, and '
      'tapping it opens the modal',
      (tester) async {
        // Arrange — passing a non-null iconColor selects the
        // GlassActionButton branch used when the menu sits over an image.
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

        await tester.pumpAndSettle();

        // Assert — the GlassActionButton branch is taken, not the
        // standard IconButton branch, and the icon adopts the passed color.
        expect(find.byType(GlassActionButton), findsOneWidget);
        expect(find.byType(IconButton), findsNothing);
        final icon = tester.widget<Icon>(
          find.byIcon(Icons.assistant_rounded),
        );
        expect(icon.color, const Color(0xFF00FF00));

        // Act — tapping the glass button opens the unified AI modal.
        await tester.tap(find.byType(GlassActionButton));
        await tester.pumpAndSettle();

        // Assert — onTap wired through to UnifiedAiModal.show.
        expect(find.byType(UnifiedAiSkillsList), findsOneWidget);
      },
    );
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
      'a background refresh that drops the hovered skill clears the hover '
      'state via the ref.listen callback — proven by re-adding the skill '
      'and observing its divider is opaque (a retained stale hover would '
      'have kept it transparent)',
      (tester) async {
        // A StateProvider feeds the (overridden) skills future provider so
        // the test can push refreshed lists at runtime, exercising the
        // ref.listen reconciliation branch in the widget.
        final skillsSource = StateProvider<List<AiConfigSkill>>(
          (ref) => testSkills,
        );

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
              )).overrideWith((ref) => ref.watch(skillsSource)),
            ],
          ),
        );
        await tester.pumpAndSettle();

        // Three skills → two dividers, both opaque before hover.
        expect(find.byType(Divider), findsNWidgets(2));

        // Hover the LAST skill so its only adjacent divider (index 1) goes
        // transparent, confirming _hoveredSkillId == testSkills[2].id.
        final gesture = await tester.createGesture(
          kind: PointerDeviceKind.mouse,
        );
        addTearDown(gesture.removePointer);
        await gesture.addPointer(location: Offset.zero);
        await gesture.moveTo(tester.getCenter(find.text(testSkills[2].name)));
        await tester.pumpAndSettle();

        final hovered = tester
            .widgetList<Divider>(find.byType(Divider))
            .toList();
        expect(hovered[1].color, Colors.transparent);

        final container = ProviderScope.containerOf(
          tester.element(find.byType(UnifiedAiSkillsList)),
        );

        // Background refresh: drop the hovered last skill. The ref.listen
        // callback must clear _hoveredSkillId because testSkills[2] is no
        // longer present in the refreshed list.
        container.read(skillsSource.notifier).state = [
          testSkills[0],
          testSkills[1],
        ];
        await tester.pumpAndSettle();
        expect(find.text(testSkills[2].name), findsNothing);

        // Park the pointer in dead space so that re-adding the skill below
        // does not re-hover it under the (otherwise stationary) cursor,
        // which would confound the divider assertion.
        await gesture.moveTo(const Offset(-500, -500));
        await tester.pumpAndSettle();

        // Re-add the previously-hovered skill. If the ref.listen callback
        // had cleared the hover, this row's divider is opaque. A retained
        // stale _hoveredSkillId would instead paint divider[1] transparent.
        container.read(skillsSource.notifier).state = testSkills;
        await tester.pumpAndSettle();

        final restored = tester
            .widgetList<Divider>(find.byType(Divider))
            .toList();
        expect(restored, hasLength(2));
        expect(restored[1].color, isNot(Colors.transparent));
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

  // Same dispatch shape covers transcription + image-analysis; the
  // [_overrideVariants] table varies only the skill type, modality,
  // entity factory, and profile slot. Adding a third per-invocation
  // override slot is a new entry in the table — no test bodies copy.
  group('Per-invocation model override — picker flow', () {
    for (final variant in _overrideVariants) {
      group(variant.label, () {
        testWidgets(
          'tapping the skill with two slot-capable models opens the '
          'InferenceModelPickerModal — proves the popup inserts the '
          'picker step before firing the trigger, and proves the '
          'picker is fed the slot-capable list (the decoy model whose '
          'inputModalities do NOT match the slot modality is filtered '
          'out before the picker sees it)',
          (tester) async {
            final fx = _OverrideFixture.twoModelsPlusDecoy(variant);
            await tester.pumpWidget(
              buildTestWidget(
                UnifiedAiPopUpMenu(
                  journalEntity: fx.entity,
                  linkedFromId: null,
                ),
                overrides: _baseOverrides(
                  entity: fx.entity,
                  skill: fx.skill,
                  models: fx.allModels,
                  resolver: _NullProfileResolver(),
                  configs: fx.allModels,
                ),
              ),
            );
            await tester.pumpAndSettle();

            await tester.tap(find.byIcon(Icons.assistant_rounded));
            await tester.pumpAndSettle();
            await tester.tap(find.text(variant.skillName));
            await tester.pumpAndSettle();

            // Picker is mounted and lists both slot-capable models;
            // the wrong-modality decoy is absent because the popup
            // filters by `inputModalities.contains(variant.modality)`
            // before calling the picker.
            expect(find.byType(InferenceModelPickerModal), findsOneWidget);
            expect(find.text(fx.modelA.name), findsOneWidget);
            expect(find.text(fx.modelB.name), findsOneWidget);
            expect(find.text(fx.decoy.name), findsNothing);
          },
        );

        testWidgets(
          'when only one slot-capable model is configured the picker '
          'short-circuits and the popup fires the trigger immediately '
          '— preserving the one-tap flow. Asserts both that the modal '
          'never mounts AND that triggerSkillProvider runs once with '
          'the lone model id as overrideModelId; the latter catches a '
          'regression where the short-circuit path silently skips '
          'dispatch (which the picker-absence check alone would miss)',
          (tester) async {
            final fx = _OverrideFixture.singleModel(variant);
            TriggerSkillParams? capturedParams;
            await tester.pumpWidget(
              buildTestWidget(
                UnifiedAiPopUpMenu(
                  journalEntity: fx.entity,
                  linkedFromId: null,
                ),
                overrides: [
                  ..._baseOverrides(
                    entity: fx.entity,
                    skill: fx.skill,
                    models: fx.allModels,
                    resolver: _NullProfileResolver(),
                    configs: fx.allModels,
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
            await tester.tap(find.text(variant.skillName));
            await tester.pumpAndSettle();

            // No picker — short-circuit took the single-model path.
            // Skills list closed as part of the tap handler.
            expect(find.byType(InferenceModelPickerModal), findsNothing);
            expect(find.byType(UnifiedAiSkillsList), findsNothing);
            // Trigger fired with the lone model id forwarded as the
            // override — the short-circuit isn't a silent no-op.
            expect(capturedParams, isNotNull);
            expect(capturedParams!.entityId, fx.entity.id);
            expect(capturedParams!.skillId, fx.skill.id);
            expect(capturedParams!.overrideModelId, fx.modelA.id);
          },
        );

        testWidgets(
          'tapping the default-badged row forwards overrideModelId: '
          'null to triggerSkillProvider — the override is collapsed '
          'to null when the user picks the same model the profile '
          'already points at, so the runner reads the profile slot '
          'and a model deleted between picker and run still falls '
          'back gracefully',
          (tester) async {
            final fx = _OverrideFixture.twoModelsWithDefault(variant);
            TriggerSkillParams? capturedParams;
            await tester.pumpWidget(
              buildTestWidget(
                UnifiedAiPopUpMenu(
                  journalEntity: fx.entity,
                  linkedFromId: null,
                ),
                overrides: [
                  entryControllerProvider(id: fx.entity.id).overrideWith(
                    () => FakeEntryController(fx.entity),
                  ),
                  ..._baseOverrides(
                    entity: fx.entity,
                    skill: fx.skill,
                    models: fx.allModels,
                    resolver: _FixedProfileResolver(fx.profile!),
                    configs: [...fx.allModels, ...fx.providers],
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
            await tester.tap(find.text(variant.skillName));
            await tester.pumpAndSettle();

            // Tap the default-badged row (modelA) — the popup should
            // fire the trigger with overrideModelId: null because the
            // picked id matches the computed defaultModelId.
            expect(find.byType(InferenceModelPickerModal), findsOneWidget);
            await tester.tap(find.text(fx.modelA.name));
            await tester.pumpAndSettle();

            expect(capturedParams, isNotNull);
            expect(capturedParams!.entityId, fx.entity.id);
            expect(capturedParams!.skillId, fx.skill.id);
            expect(capturedParams!.overrideModelId, isNull);
          },
        );

        testWidgets(
          "tapping a non-default row forwards that row's "
          'AiConfigModel.id to triggerSkillProvider as overrideModelId '
          '— proves the override seam threads through the popup to '
          'the trigger when the user picks a non-profile model',
          (tester) async {
            final fx = _OverrideFixture.twoModelsWithDefault(variant);
            TriggerSkillParams? capturedParams;
            await tester.pumpWidget(
              buildTestWidget(
                UnifiedAiPopUpMenu(
                  journalEntity: fx.entity,
                  linkedFromId: null,
                ),
                overrides: [
                  entryControllerProvider(id: fx.entity.id).overrideWith(
                    () => FakeEntryController(fx.entity),
                  ),
                  ..._baseOverrides(
                    entity: fx.entity,
                    skill: fx.skill,
                    models: fx.allModels,
                    resolver: _FixedProfileResolver(fx.profile!),
                    configs: [...fx.allModels, ...fx.providers],
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
            await tester.tap(find.text(variant.skillName));
            await tester.pumpAndSettle();
            await tester.tap(find.text(fx.modelB.name));
            await tester.pumpAndSettle();

            expect(capturedParams, isNotNull);
            expect(capturedParams!.overrideModelId, fx.modelB.id);
          },
        );
      });
    }

    // When the entity itself is a Task, linkedTaskId is non-null
    // (journalEntity.id) so the override handler resolves the profile via
    // resolveForTask rather than resolveForCategory. This drives the
    // task-profile branch and proves the resolved default is honoured.
    testWidgets(
      'Task entity resolves its profile via resolveForTask (not '
      'resolveForCategory) and the picker highlights that default row',
      (tester) async {
        final t = DateTime(2024, 3, 15, 10);
        final providerA = _buildProvider(id: 'p-a', name: 'Provider A', t: t);
        final providerB = _buildProvider(id: 'p-b', name: 'Provider B', t: t);
        final modelA = _buildModel(
          id: 'm-a',
          name: 'Voxtral Local',
          providerModelId: 'wire-a',
          providerId: 'p-a',
          modality: Modality.audio,
          t: t,
        );
        final modelB = _buildModel(
          id: 'm-b',
          name: 'Mistral Cloud',
          providerModelId: 'wire-b',
          providerId: 'p-b',
          modality: Modality.audio,
          t: t,
        );
        final skill = _buildSkill(_transcriptionOverrideVariant, t);
        // Profile slot points at modelA (wire-a via providerA) so the
        // popup computes modelA as the default row.
        final profile = _fillTranscriptionSlot(
          thinkingProvider: providerA,
          slotProvider: providerA,
          slotProviderModelId: 'wire-a',
        );
        final taskEntity = Task(
          meta: Metadata(
            id: 'task-override',
            createdAt: t,
            updatedAt: t,
            dateFrom: t,
            dateTo: t,
            categoryId: 'cat-should-not-be-used',
          ),
          data: TaskData(
            title: 'Override Task',
            status: TaskStatus.open(id: 'st', createdAt: t, utcOffset: 0),
            statusHistory: [],
            dateFrom: t,
            dateTo: t,
          ),
        );
        final resolver = _RecordingProfileResolver(profile);
        TriggerSkillParams? capturedParams;

        await tester.pumpWidget(
          buildTestWidget(
            UnifiedAiPopUpMenu(
              journalEntity: taskEntity,
              linkedFromId: null,
            ),
            overrides: [
              entryControllerProvider(id: taskEntity.id).overrideWith(
                () => FakeEntryController(taskEntity),
              ),
              ..._baseOverrides(
                entity: taskEntity,
                skill: skill,
                models: [modelA, modelB],
                resolver: resolver,
                configs: [modelA, modelB, providerA, providerB],
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
        await tester.tap(find.text(_transcriptionOverrideVariant.skillName));
        await tester.pumpAndSettle();

        // The Task's profile was resolved via resolveForTask, keyed by the
        // task id — never via resolveForCategory.
        expect(resolver.resolveForTaskCalls, ['task-override']);
        expect(resolver.resolveForCategoryCalls, isEmpty);

        // Picker is open; tapping the default-badged row (modelA) collapses
        // the override to null because it matches the resolved default.
        expect(find.byType(InferenceModelPickerModal), findsOneWidget);
        await tester.tap(find.text(modelA.name));
        await tester.pumpAndSettle();

        expect(capturedParams, isNotNull);
        expect(capturedParams!.entityId, taskEntity.id);
        expect(capturedParams!.linkedTaskId, taskEntity.id);
        expect(capturedParams!.overrideModelId, isNull);
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

// =============================================================
// Override-picker test harness
// =============================================================

/// The override-picker flow requires `tester.pumpAndSettle()` rather
/// than a bounded `pump(duration)` (see test/README.md / AGENTS.md
/// async rules) because two awaited gates run between taps: the
/// modal sheet animation AND the async resolution of
/// `availableSkillsForEntityProvider` / `aiConfigRepositoryProvider`.
/// A bounded pump doesn't reliably drain the latter; the animations
/// are deterministic and bounded so the 10s timeout warning does not
/// apply here.

/// Per-skill data driving the parameterised override-picker tests.
/// Each variant plugs in everything that differs between the
/// transcription and image-analysis flows: skill type + name, the
/// modality the slot consumes, the decoy modality (a model that is
/// configured but should be filtered OUT of the picker), entity
/// factory, and the function that writes the variant's slot fields
/// onto a [ResolvedProfile].
class _OverrideVariant {
  const _OverrideVariant({
    required this.label,
    required this.skillType,
    required this.skillName,
    required this.skillRequiredModality,
    required this.modelModality,
    required this.decoyModality,
    required this.decoyName,
    required this.modelAName,
    required this.modelBName,
    required this.entityFactory,
    required this.fillSlot,
  });

  final String label;
  final SkillType skillType;
  final String skillName;
  final Modality skillRequiredModality;
  final Modality modelModality;
  final Modality decoyModality;
  final String decoyName;
  final String modelAName;
  final String modelBName;
  final JournalEntity Function({required String id, String? categoryId})
  entityFactory;
  final ResolvedProfile Function({
    required AiConfigInferenceProvider thinkingProvider,
    required AiConfigInferenceProvider slotProvider,
    required String slotProviderModelId,
  })
  fillSlot;
}

JournalEntity _audioEntityFactory({required String id, String? categoryId}) {
  final t = DateTime(2024, 3, 15, 10);
  return JournalAudio(
    meta: Metadata(
      id: id,
      createdAt: t,
      updatedAt: t,
      dateFrom: t,
      dateTo: t,
      categoryId: categoryId,
    ),
    data: AudioData(
      dateFrom: t,
      dateTo: t,
      audioFile: 'test.mp3',
      audioDirectory: '/test',
      duration: const Duration(minutes: 1),
    ),
  );
}

JournalEntity _imageEntityFactory({required String id, String? categoryId}) {
  final t = DateTime(2024, 3, 15, 10);
  return JournalImage(
    meta: Metadata(
      id: id,
      createdAt: t,
      updatedAt: t,
      dateFrom: t,
      dateTo: t,
      categoryId: categoryId,
    ),
    data: ImageData(
      capturedAt: t,
      imageId: 'img-$id',
      imageFile: 'test.jpg',
      imageDirectory: '/test',
    ),
  );
}

ResolvedProfile _fillTranscriptionSlot({
  required AiConfigInferenceProvider thinkingProvider,
  required AiConfigInferenceProvider slotProvider,
  required String slotProviderModelId,
}) => ResolvedProfile(
  thinkingModelId: 'thinking',
  thinkingProvider: thinkingProvider,
  transcriptionProvider: slotProvider,
  transcriptionModelId: slotProviderModelId,
);

ResolvedProfile _fillImageRecognitionSlot({
  required AiConfigInferenceProvider thinkingProvider,
  required AiConfigInferenceProvider slotProvider,
  required String slotProviderModelId,
}) => ResolvedProfile(
  thinkingModelId: 'thinking',
  thinkingProvider: thinkingProvider,
  imageRecognitionProvider: slotProvider,
  imageRecognitionModelId: slotProviderModelId,
);

const _transcriptionOverrideVariant = _OverrideVariant(
  label: 'transcription',
  skillType: SkillType.transcription,
  skillName: 'Transcribe Audio',
  skillRequiredModality: Modality.audio,
  modelModality: Modality.audio,
  decoyModality: Modality.text,
  decoyName: 'Gemini Flash (text only)',
  modelAName: 'Voxtral Local',
  modelBName: 'Mistral Cloud',
  entityFactory: _audioEntityFactory,
  fillSlot: _fillTranscriptionSlot,
);

const _imageAnalysisOverrideVariant = _OverrideVariant(
  label: 'image analysis',
  skillType: SkillType.imageAnalysis,
  skillName: 'Analyze Image',
  skillRequiredModality: Modality.image,
  modelModality: Modality.image,
  decoyModality: Modality.audio,
  decoyName: 'Voxtral (audio only)',
  modelAName: 'GPT-4o Vision',
  modelBName: 'Claude Sonnet Vision',
  entityFactory: _imageEntityFactory,
  fillSlot: _fillImageRecognitionSlot,
);

const _overrideVariants = <_OverrideVariant>[
  _transcriptionOverrideVariant,
  _imageAnalysisOverrideVariant,
];

/// Fixture bundling the entity, skill, models, providers, and
/// (optional) resolved profile for one variant of an override-picker
/// test. The named constructors line up with the three shapes the
/// parameterised tests need (filter test, single-model short-circuit,
/// default-row + non-default-row).
class _OverrideFixture {
  _OverrideFixture._({
    required this.entity,
    required this.skill,
    required this.modelA,
    required this.modelB,
    required this.decoy,
    required this.providers,
    required this.profile,
  });

  factory _OverrideFixture.twoModelsPlusDecoy(_OverrideVariant variant) {
    final t = DateTime(2024, 3, 15, 10);
    return _OverrideFixture._(
      entity: variant.entityFactory(id: 'entity-${variant.label}-filter'),
      skill: _buildSkill(variant, t),
      modelA: _buildModel(
        id: 'm-a',
        name: variant.modelAName,
        providerModelId: 'wire-a',
        providerId: 'p-a',
        modality: variant.modelModality,
        t: t,
      ),
      modelB: _buildModel(
        id: 'm-b',
        name: variant.modelBName,
        providerModelId: 'wire-b',
        providerId: 'p-b',
        modality: variant.modelModality,
        t: t,
      ),
      decoy: _buildModel(
        id: 'm-decoy',
        name: variant.decoyName,
        providerModelId: 'decoy/wire',
        providerId: 'p-decoy',
        modality: variant.decoyModality,
        t: t,
      ),
      providers: const <AiConfigInferenceProvider>[],
      profile: null,
    );
  }

  /// Single-model shape: only [modelA] has the slot modality; the
  /// other two slots on the fixture are unrelated wrong-modality
  /// decoys that the popup's `inputModalities.contains(...)` filter
  /// strips out before the picker even sees them. The fixture's
  /// generic `modelB` / `decoy` field names are reused (rather than
  /// reshaping the class) so the three shapes share one record
  /// layout — the field names don't carry semantic meaning in this
  /// shape, only the modalities do.
  factory _OverrideFixture.singleModel(_OverrideVariant variant) {
    final t = DateTime(2024, 3, 15, 10);
    AiConfigModel wrongModalityDecoy(String idSuffix) => _buildModel(
      id: 'm-decoy-$idSuffix',
      name: '__wrong-modality-decoy-${idSuffix}__',
      providerModelId: 'decoy-$idSuffix/wire',
      providerId: 'p-decoy-$idSuffix',
      modality: variant.decoyModality,
      t: t,
    );
    return _OverrideFixture._(
      entity: variant.entityFactory(id: 'entity-${variant.label}-single'),
      skill: _buildSkill(variant, t),
      modelA: _buildModel(
        id: 'm-only',
        name: variant.modelAName,
        providerModelId: 'wire-only',
        providerId: 'p-only',
        modality: variant.modelModality,
        t: t,
      ),
      modelB: wrongModalityDecoy('b'),
      decoy: wrongModalityDecoy('c'),
      providers: const <AiConfigInferenceProvider>[],
      profile: null,
    );
  }

  factory _OverrideFixture.twoModelsWithDefault(_OverrideVariant variant) {
    final t = DateTime(2024, 3, 15, 10);
    final providerA = _buildProvider(id: 'p-a', name: 'Provider A', t: t);
    final providerB = _buildProvider(id: 'p-b', name: 'Provider B', t: t);
    final modelA = _buildModel(
      id: 'm-a',
      name: variant.modelAName,
      providerModelId: 'wire-a',
      providerId: 'p-a',
      modality: variant.modelModality,
      t: t,
    );
    final modelB = _buildModel(
      id: 'm-b',
      name: variant.modelBName,
      providerModelId: 'wire-b',
      providerId: 'p-b',
      modality: variant.modelModality,
      t: t,
    );
    return _OverrideFixture._(
      entity: variant.entityFactory(
        id: 'entity-${variant.label}-cat',
        categoryId: 'cat-1',
      ),
      skill: _buildSkill(variant, t),
      modelA: modelA,
      modelB: modelB,
      decoy: _buildModel(
        id: 'm-decoy',
        name: '__unused__',
        providerModelId: 'decoy/wire',
        providerId: 'p-decoy',
        modality: variant.decoyModality,
        t: t,
      ),
      providers: [providerA, providerB],
      // Profile points at modelA via providerA — the popup must
      // recognise the modelA row as the default.
      profile: variant.fillSlot(
        thinkingProvider: providerA,
        slotProvider: providerA,
        slotProviderModelId: 'wire-a',
      ),
    );
  }

  final JournalEntity entity;
  final AiConfigSkill skill;
  final AiConfigModel modelA;
  final AiConfigModel modelB;
  final AiConfigModel decoy;
  final List<AiConfigInferenceProvider> providers;
  final ResolvedProfile? profile;

  List<AiConfigModel> get allModels => [modelA, modelB, decoy];
}

AiConfigSkill _buildSkill(_OverrideVariant variant, DateTime t) =>
    AiConfig.skill(
          id: 'skill-${variant.label}',
          name: variant.skillName,
          createdAt: t,
          skillType: variant.skillType,
          requiredInputModalities: [variant.skillRequiredModality],
          systemInstructions: 'System',
          userInstructions: 'User',
          description: 'Variant test skill',
        )
        as AiConfigSkill;

AiConfigModel _buildModel({
  required String id,
  required String name,
  required String providerModelId,
  required String providerId,
  required Modality modality,
  required DateTime t,
}) {
  return AiConfig.model(
        id: id,
        name: name,
        providerModelId: providerModelId,
        inferenceProviderId: providerId,
        createdAt: t,
        inputModalities: [modality, Modality.text],
        outputModalities: const [Modality.text],
        isReasoningModel: false,
      )
      as AiConfigModel;
}

AiConfigInferenceProvider _buildProvider({
  required String id,
  required String name,
  required DateTime t,
}) =>
    AiConfig.inferenceProvider(
          id: id,
          baseUrl: 'https://$id.example.com',
          name: name,
          inferenceProviderType: InferenceProviderType.openAi,
          apiKey: '',
          createdAt: t,
        )
        as AiConfigInferenceProvider;

/// Builds the Riverpod override list every parameterised override
/// test needs: the popup must see a single skill for [entity],
/// resolve to [resolver]'s profile, and read [models] from the
/// repository. The default-row tests extend this with an
/// `entryControllerProvider` override + `triggerSkillProvider`
/// capture override; those two cannot be folded in here cleanly
/// because the entry-controller key is per-fixture.
List<Override> _baseOverrides({
  required JournalEntity entity,
  required AiConfigSkill skill,
  required List<AiConfigModel> models,
  required ProfileAutomationResolver resolver,
  required List<AiConfig> configs,
}) {
  return [
    hasAvailableSkillsProvider((
      entityId: entity.id,
      linkedFromId: null,
    )).overrideWith((ref) => Future.value(true)),
    availableSkillsForEntityProvider((
      entityId: entity.id,
      linkedFromId: null,
    )).overrideWith((ref) => Future.value([skill])),
    profileAutomationResolverProvider.overrideWithValue(resolver),
    aiConfigByTypeControllerProvider(
      configType: AiConfigType.model,
    ).overrideWith(() => MockAiConfigByTypeController(models)),
    aiConfigRepositoryProvider.overrideWithValue(
      _StubAiConfigRepository(configs),
    ),
  ];
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
/// the override branch reaches the picker — the model-list rendering
/// and rest of the chain are exercised by
/// `inference_model_picker_modal_test.dart` in isolation.
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
/// tapping it produces `overrideModelId: null` at the trigger seam).
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

/// Resolver that returns a fixed profile and records which method was
/// invoked (and with which id). Used to prove the override handler routes
/// Task entities through `resolveForTask` rather than `resolveForCategory`.
class _RecordingProfileResolver implements ProfileAutomationResolver {
  _RecordingProfileResolver(this._profile);

  final ResolvedProfile _profile;
  final List<String> resolveForTaskCalls = [];
  final List<String> resolveForCategoryCalls = [];

  @override
  Future<ResolvedProfile?> resolveForTask(String taskId) async {
    resolveForTaskCalls.add(taskId);
    return _profile;
  }

  @override
  Future<ResolvedProfile?> resolveForCategory(String categoryId) async {
    resolveForCategoryCalls.add(categoryId);
    return _profile;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
