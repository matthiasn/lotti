/// Tutorial-video driver: "create a task with your voice".
///
/// Drives the real app through the scenario in
/// `tools/tutorial_videos/config/scenarios/create_task_from_audio.yaml`
/// while the host workbench records the screen — the full
/// speak-a-thought-get-a-structured-task experience, all visibly on camera:
///
///  1. create a brand-new task via the + FAB,
///  2. dictate through the REAL audio recorder (the host's virtual
///     microphone carries the pre-generated user-voice clip),
///  3. watch the Voxtral transcript appear on the task,
///  4. watch the task agent propose a title + checklist items,
///  5. confirm all proposals, then check off the first item.
///
/// Requires the real agent runtime (the harness does NOT stub
/// `agentInitializationProvider`) plus a Melious profile whose thinking
/// model handles the wake tool calls. Run via the workbench
/// (`python3 -m tutorial_videos build`) or headless as documented in
/// `tools/tutorial_videos/README.md`.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lotti/beamer/beamer_app.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/service/agent_template_service.dart';
import 'package:lotti/features/agents/state/task_agent_providers.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/skill_assignment.dart';
import 'package:lotti/features/ai/skills/built_in_skills.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_floating_action_button.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';
import 'package:lotti/features/tasks/ui/pages/task_details_page.dart';
import 'package:lotti/features/tasks/ui/pages/tasks_tab_page.dart';
import 'package:lotti/features/tasks/ui/widgets/task_action_bar.dart';

import '../../test/helpers/manual_screenshot_locale.dart';
import '../manual_screenshot_utils.dart';
import 'tutorial_harness.dart';

const _thinkingModelId = 'tutorial-qwen-thinking-model';
const _voxtralModelId = 'tutorial-voxtral-model';
const _meliousProviderId = 'tutorial-melious-provider';
const _profileId = 'tutorial-melious-profile';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final manifest = TutorialManifest.fromEnvironment();
  final locale = manualScreenshotLocaleFromEnvironment(Platform.environment);
  String localized({required String en, required String de}) =>
      manualScreenshotText(en: en, de: de);

  testWidgets(
    'drives the create-task-from-audio tutorial flow',
    (tester) async {
      tester.platformDispatcher.localeTestValue = locale;
      addTearDown(tester.platformDispatcher.clearLocaleTestValue);

      final harness = await TutorialAppHarness.setUp(
        aiConfigs: _agentConfigs(),
        languageCode: locale.languageCode,
        // Category defaults make the FAB-created task get a real, non-dormant
        // agent (template + profile), and the speech dictionary biases
        // Voxtral toward the penguin vocabulary.
        categoryTransform: (category) => category.copyWith(
          defaultTemplateId: lauraTemplateId,
          defaultProfileId: _profileId,
          speechDictionary: manifest.dictionary,
        ),
      );
      addTearDown(harness.dispose);

      final cursor = TutorialCursorController();
      final hudClock = ValueNotifier<Duration>(Duration.zero);
      addTearDown(hudClock.dispose);
      await tester.pumpWidget(
        manualScreenshotBoundary(
          child: TutorialCursorLayer(
            controller: cursor,
            elapsed: hudClock,
            child: ProviderScope(
              overrides: harness.providerOverrides(),
              child: MyBeamerApp(
                navService: harness.navService,
                userActivityService: harness.userActivityService,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Let startup settle BEFORE timeline zero: agent seeding and the
      // Logbook's auto-select navigation run right after boot.
      for (var i = 0; i < 300; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }

      // Land on Tasks BEFORE the recorded timeline starts — the app's real
      // default landing tab is the Logbook (Journal); contrary to what the
      // comment above once assumed, that page is NOT trimmed by the
      // compositor and was flashing on screen during the intro step's
      // establishing hold.
      harness.navService.setIndex(
        harness.navService.beamerDelegates.indexOf(
          harness.navService.tasksDelegate,
        ),
      );
      await tester.pump();

      final driver =
          TutorialDriver(
              tester: tester,
              manifest: manifest,
              cursor: cursor,
              hud: hudClock,
            )
            ..diagnostics = () {
              final nav = harness.navService;
              final types = tester.allWidgets
                  .map((widget) => widget.runtimeType.toString())
                  .toSet();
              bool has(String type) => types.contains(type);
              return 'currentPath=${nav.currentPath} '
                  'isDesktopMode=${nav.isDesktopMode} '
                  'detailStack=${nav.desktopTaskDetailStack.value} '
                  'TaskDetailsPage=${has('TaskDetailsPage')} '
                  'TaskActionBar=${has('TaskActionBar')} '
                  'proposalRail=${find.byKey(const ValueKey('proposalBottomRail')).evaluate().length}';
            }
            ..onTimeout = (context) => captureManualScreenshot(
              binding: binding,
              tester: tester,
              name: 'failure_$context',
            );

      // Vertical scrollables only: the detail pane also contains horizontal
      // chip rows whose Scrollable would swallow vertical drags.
      final detailScrollable = find.descendant(
        of: find.byType(TaskDetailsPage),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Scrollable &&
              axisDirectionToAxis(widget.axisDirection) == Axis.vertical,
        ),
      );

      await driver.step('intro', () async {
        final tasksRailItem = find
            .text(localized(en: 'Tasks', de: 'Aufgaben'))
            .hitTestable();
        await driver.pumpUntilFound(tasksRailItem);
        await driver.holdUntil(const Duration(seconds: 2));
        await driver.tapLikeUser(tasksRailItem);
      });

      String? taskId;
      final container = ProviderScope.containerOf(
        tester.element(find.byType(MyBeamerApp)),
      );
      await driver.step('create_task', () async {
        final fab = find
            .descendant(
              of: find.byType(TasksTabPage),
              matching: find.byType(DesignSystemFloatingActionButton),
            )
            .hitTestable();
        await driver.pumpUntilFound(fab);
        await driver.tapLikeUser(fab);
        await driver.pumpUntilFound(find.byKey(TaskActionBar.audioKey));
        final path = harness.navService.currentPath;
        expect(path, startsWith('/tasks/'));
        taskId = path.split('/').last;

        // The unfiltered tasks list creates category-less tasks, so the
        // category-default agent assignment never fires. Give the fresh task
        // its category and a real (non-dormant) agent through the same
        // services the production auto-assign path uses.
        await container
            .read(journalRepositoryProvider)
            .updateCategoryId(taskId!, categoryId: harness.world.category.id);
        await container
            .read(taskAgentServiceProvider)
            .createTaskAgent(
              taskId: taskId!,
              allowedCategoryIds: {harness.world.category.id},
              templateId: lauraTemplateId,
              profileId: _profileId,
            );
      });

      await driver.step('record_dictation', () async {
        await driver.tapLikeUser(find.byKey(TaskActionBar.audioKey));
        await driver.pumpUntilFound(find.byKey(const ValueKey('record')));
        await driver.tapLikeUser(find.byKey(const ValueKey('record')));
        await tester.pump(const Duration(milliseconds: 500));

        // The narrator dictates in their own voice — wait for the step
        // narration to finish so they never talk over themselves.
        await driver.waitForNarration();
        await driver.speakIntoMic(manifest.step('record_dictation').dictation!);

        final stopControl = find
            .text(localized(en: 'STOP', de: 'STOPP'))
            .hitTestable();
        await driver.pumpUntilFound(stopControl);
        await driver.tapLikeUser(stopControl);
        await tester.pump(const Duration(milliseconds: 500));
      });

      // The transcript must be SEEN, not just stored: wait for the text to
      // land, then scroll it into view on camera.
      //
      // findRichText: true — flutter_quill's editor renders each line as a
      // bare RichText (text_line.dart), never wrapped in a Text widget, so
      // the default text finder (Text/EditableText only) never matches
      // editor-rendered content, regardless of whether it's populated.
      // Scoped to TaskDetailsPage: the demo world's stock task list
      // includes an unrelated seeded task titled "Startprüfung für Project
      // Waddle" in the sidebar, always in the tree — an unscoped search for
      // this word risks a false match there instead of actually verifying
      // the transcript.
      final transcriptText = find.descendant(
        of: find.byType(TaskDetailsPage),
        matching: find.textContaining('Waddle', findRichText: true),
      );
      await driver.step('transcription', () async {
        // Re-assert automatic updates before the transcription-complete
        // nudge fires — the agent's initial wake may have finished during
        // the recording and clobbered the earlier write.
        final agentService = container.read(taskAgentServiceProvider);
        await driver.pumpUntil(
          () async {
            final identity = await agentService.getTaskAgentForTask(taskId!);
            if (identity == null) return false;
            if (identity.config.automaticUpdatesEnabledEffective) return true;
            await agentService.updateAutomaticUpdates(
              agentId: identity.agentId,
              enabled: true,
            );
            return false;
          },
          description: 'automatic updates re-asserted on the task agent',
        );
        await driver.pumpUntil(
          () async {
            final transcript = await _linkedAudioTranscript(harness, taskId!);
            return transcript != null && transcript.trim().isNotEmpty;
          },
          description: 'Voxtral transcript on the linked audio entry',
          timeout: const Duration(minutes: 3),
        );
        // The DB write above lands ahead of the UI: EditorWidget's Quill
        // controller is (re)built from a microtask scheduled off the
        // update-notification stream, so give it a beat to actually render
        // before searching for it — unlike the other two scenarios, this
        // note is written asynchronously into an ALREADY-MOUNTED page
        // rather than seeded before the page ever mounts.
        await driver.pumpUntilFound(
          transcriptText,
          timeout: const Duration(seconds: 15),
        );
        // Bring the transcript into view on camera.
        await driver.scrollIntoView(
          transcriptText,
          scrollable: detailScrollable,
        );
      });
      expect(
        transcriptText,
        findsWidgets,
        reason: 'transcript must be visible on the task',
      );

      // The agent wake (title + checklist proposals) takes several cloud
      // roundtrips on the thinking model — keep pumping so the change-set
      // card animates in on camera.
      final proposalRail = find.byKey(const ValueKey('proposalBottomRail'));
      await driver.step('suggestions', () async {
        await driver.pumpUntil(
          () => proposalRail.evaluate().isNotEmpty,
          description: 'agent title/checklist proposals in the change-set card',
          timeout: const Duration(minutes: 4),
        );
        // Let the entrance animations finish, then bring the proposals into
        // view on camera. Target the confirm-all LABEL: the rail's SizedBox
        // never registers as hit-testable even when visible.
        await driver.holdUntil(
          driver.timeline.elapsed + const Duration(seconds: 2),
        );
        await driver.scrollIntoView(
          find.text(localized(en: 'Confirm all', de: 'Alle bestätigen')),
          scrollable: detailScrollable,
        );
        await driver.holdUntil(
          driver.timeline.elapsed + const Duration(seconds: 2),
        );
      });

      await driver.step('confirm', () async {
        final confirmAll = find.text(
          localized(en: 'Confirm all', de: 'Alle bestätigen'),
        );
        await driver.pumpUntilFound(confirmAll);
        if (confirmAll.hitTestable().evaluate().isEmpty) {
          await driver.scrollIntoView(
            confirmAll,
            scrollable: detailScrollable,
          );
        }
        await driver.tapLikeUser(confirmAll.hitTestable());
        await driver.pumpUntil(
          () async {
            final entity = await harness.journalDb.journalEntityById(taskId!);
            return entity is Task && entity.data.title.trim().isNotEmpty;
          },
          description: 'confirmed title persisted on the task',
        );
        await driver.pumpUntil(
          () async => (await _checklistItemIds(harness, taskId!)).isNotEmpty,
          description: 'confirmed checklist items persisted',
        );
      });

      await driver.step('check_off', () async {
        // `suggestions`/`confirm` left the pane scrolled down at "Confirm
        // all", but the point of this beat is showing the whole confirmed
        // checklist before checking an item off, not jumping straight to a
        // mid-scroll checkbox. Align the FIRST checklist item near the top
        // (rather than jumping to the page's absolute top) so this frames
        // the checklist from its own beginning regardless of whatever is
        // above it.
        final checklistItems = find.descendant(
          of: find.byType(TaskDetailsPage),
          matching: find.byType(Checkbox),
        );
        await driver.scrollIntoView(
          checklistItems,
          scrollable: detailScrollable,
          alignment: 0.1,
        );
        await driver.holdUntil(
          driver.timeline.elapsed + const Duration(seconds: 1),
        );

        final itemCheckbox = checklistItems.hitTestable();
        await driver.pumpUntilFound(itemCheckbox);
        await driver.tapLikeUser(itemCheckbox);
        await driver.pumpUntil(
          () => _anyChecklistItemChecked(harness, taskId!),
          description: 'checklist item persisted as checked',
        );
      });

      await driver.step('outro', () async {});

      driver.timeline.write();

      // Quiesce before teardown: a post-confirm agent wake may still be in
      // flight; disposing the ProviderScope mid-wake throws
      // UnmountedRefException after the test and fails the run.
      final thinking = find.text(
        localized(en: 'Thinking…', de: 'Denkt nach …'),
      );
      await driver.pumpUntil(
        () => thinking.evaluate().isEmpty,
        description: 'agent runtime quiesced (no in-flight wake)',
        timeout: const Duration(minutes: 2),
      );
      await driver.holdUntil(
        driver.timeline.elapsed + const Duration(seconds: 2),
      );
    },
    timeout: const Timeout(Duration(minutes: 15)),
  );
}

/// Profile-path agent seed: Melious provider (env creds), Voxtral
/// transcription model, Qwen thinking model (tool calling), and an inference
/// profile wired to both — mirroring the proven dev-app Melious profile. The
/// demo category's `defaultTemplateId`/`defaultProfileId` (see setUp) make
/// FAB-created tasks get a real, wakeable agent.
List<AiConfig> _agentConfigs() {
  final apiKey = Platform.environment['MELIOUS_API_KEY'];
  final baseUrl = Platform.environment['MELIOUS_BASE_URL'];
  if (apiKey == null || apiKey.isEmpty || baseUrl == null || baseUrl.isEmpty) {
    throw StateError(
      'MELIOUS_API_KEY / MELIOUS_BASE_URL are not set — source .env before '
      'launching (set -a; source .env; set +a).',
    );
  }
  final createdAt = DateTime.now();
  return [
    AiConfig.inferenceProvider(
      id: _meliousProviderId,
      name: 'Melious.ai',
      baseUrl: baseUrl,
      apiKey: apiKey,
      createdAt: createdAt,
      inferenceProviderType: InferenceProviderType.melious,
    ),
    AiConfig.model(
      id: _voxtralModelId,
      name: 'Voxtral Small',
      providerModelId: 'voxtral-small-24b-2507',
      inferenceProviderId: _meliousProviderId,
      createdAt: createdAt,
      inputModalities: const [Modality.audio, Modality.text],
      outputModalities: const [Modality.text],
      isReasoningModel: false,
    ),
    AiConfig.model(
      id: _thinkingModelId,
      name: 'Qwen3.5 122B A10B',
      providerModelId: 'qwen3.5-122b-a10b',
      inferenceProviderId: _meliousProviderId,
      createdAt: createdAt,
      inputModalities: const [Modality.text],
      outputModalities: const [Modality.text],
      isReasoningModel: true,
      supportsFunctionCalling: true,
    ),
    AiConfig.inferenceProfile(
      id: _profileId,
      name: 'Tutorial Melious',
      thinkingModelId: _thinkingModelId,
      transcriptionModelId: _voxtralModelId,
      createdAt: createdAt,
      skillAssignments: [
        const SkillAssignment(skillId: skillTranscribeContextId),
      ],
    ),
  ];
}

Future<String?> _linkedAudioTranscript(
  TutorialAppHarness harness,
  String taskId,
) async {
  final linked = await harness.journalDb.getLinkedEntities(taskId);
  for (final entity in linked) {
    if (entity is JournalAudio) {
      final fromTranscripts = entity.data.transcripts
          ?.map((transcript) => transcript.transcript)
          .join(' ');
      if (fromTranscripts != null && fromTranscripts.trim().isNotEmpty) {
        return fromTranscripts;
      }
      final text = entity.entryText?.plainText;
      if (text != null && text.trim().isNotEmpty) return text;
    }
  }
  return null;
}

Future<List<String>> _checklistItemIds(
  TutorialAppHarness harness,
  String taskId,
) async {
  final task = await harness.journalDb.journalEntityById(taskId);
  if (task is! Task) return const [];
  final ids = <String>[];
  for (final checklistId in task.data.checklistIds ?? const <String>[]) {
    final checklist = await harness.journalDb.journalEntityById(checklistId);
    if (checklist is Checklist) {
      ids.addAll(checklist.data.linkedChecklistItems);
    }
  }
  return ids;
}

Future<bool> _anyChecklistItemChecked(
  TutorialAppHarness harness,
  String taskId,
) async {
  for (final id in await _checklistItemIds(harness, taskId)) {
    final item = await harness.journalDb.journalEntityById(id);
    if (item is ChecklistItem && item.data.isChecked) return true;
  }
  return false;
}
