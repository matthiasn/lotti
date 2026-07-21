/// Tutorial-video driver: "create a task with your voice".
///
/// Drives the real app through the scenario in
/// `tools/tutorial_videos/config/scenarios/create_task_from_audio.yaml`
/// while the host workbench records the screen:
///
///  1. open the penguin task from the tasks list,
///  2. record a dictation through the REAL audio recorder (the host's
///     virtual microphone carries the pre-generated user-voice clip),
///  3. wait for live Voxtral-on-Melious transcription to land on the entry,
///  4. check off a checklist item.
///
/// Run headless (Phase-2 verification, no video):
///
///   Xvfb :99 -screen 0 1920x1080x24 &
///   pactl load-module module-null-sink sink_name=lotti_tutorial_mic
///   pactl set-default-source lotti_tutorial_mic.monitor
///   set -a; source .env; set +a
///   DISPLAY=:99 LOTTI_MANUAL_LOCALE=de \
///     LOTTI_TUTORIAL_MANIFEST=build/tutorial_videos/create_task_from_audio_de.manifest.json \
///     LOTTI_TUTORIAL_TIMELINE=build/tutorial_videos/timeline_de.json \
///     LOTTI_TUTORIAL_MIC_SINK=lotti_tutorial_mic \
///     fvm flutter test integration_test/tutorial/create_task_from_audio_tutorial_test.dart -d linux
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lotti/beamer/beamer_app.dart';
import 'package:lotti/classes/checklist_item_data.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/tasks/repository/checklist_repository.dart';
import 'package:lotti/features/tasks/ui/pages/tasks_tab_page.dart';
import 'package:lotti/features/tasks/ui/widgets/task_action_bar.dart';

import '../../test/helpers/manual_screenshot_locale.dart';
import '../manual_screenshot_utils.dart';
import 'tutorial_harness.dart';

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
        aiConfigs: _transcriptionConfigs(),
        languageCode: locale.languageCode,
      );
      addTearDown(harness.dispose);

      // Speech-dictionary terms come from the scenario manifest so Voxtral
      // gets context bias for the penguin vocabulary.
      await harness.persistenceLogic.upsertEntityDefinition(
        harness.world.category.copyWith(
          speechDictionary: manifest.dictionary,
        ),
      );

      // The tutorial's target task is created through the real creation path
      // so it gets a UUID id — the desktop split view only auto-selects
      // UUID task routes.
      final taskTitle = localized(
        en: 'Project Waddle briefing',
        de: 'Projekt-Waddle-Briefing',
      );
      final checklistItemTitle = localized(
        en: 'Confirm sardine rations',
        de: 'Sardinenrationen bestätigen',
      );
      final task = await harness.persistenceLogic.createTaskEntry(
        data: TaskData(
          title: taskTitle,
          status: TaskStatus.open(
            id: 'tutorial-task-status',
            createdAt: DateTime.now(),
            utcOffset: DateTime.now().timeZoneOffset.inMinutes,
          ),
          dateFrom: DateTime.now(),
          dateTo: DateTime.now(),
          statusHistory: const [],
        ),
        entryText: const EntryText(plainText: ''),
        categoryId: harness.world.category.id,
      );
      expect(task, isNotNull, reason: 'tutorial task must be created');
      final checklist = await ChecklistRepository().createChecklist(
        taskId: task!.id,
        title: localized(en: 'Launch prep', de: 'Startvorbereitung'),
        items: [
          ChecklistItemData(
            title: checklistItemTitle,
            isChecked: false,
            linkedChecklists: const [],
          ),
        ],
      );
      final checklistItemId = checklist.createdItems.single.id;

      final cursor = TutorialCursorController();
      await tester.pumpWidget(
        manualScreenshotBoundary(
          child: TutorialCursorLayer(
            controller: cursor,
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

      final driver =
          TutorialDriver(tester: tester, manifest: manifest, cursor: cursor)
            ..diagnostics = () {
              final nav = harness.navService;
              final types = tester.allWidgets
                  .map((widget) => widget.runtimeType.toString())
                  .toSet();
              bool has(String type) => types.contains(type);
              return 'currentPath=${nav.currentPath} '
                  'isDesktopMode=${nav.isDesktopMode} '
                  'detailStack=${nav.desktopTaskDetailStack.value} '
                  'surface=${tester.view.physicalSize}@${tester.view.devicePixelRatio} '
                  'TasksRootPage=${has('TasksRootPage')} '
                  'TasksTabPage=${has('TasksTabPage')} '
                  'TaskDetailsPage=${has('TaskDetailsPage')} '
                  'TaskActionBar=${has('TaskActionBar')} '
                  'scrollables=${find.byType(Scrollable).evaluate().length}';
            }
            ..onTimeout = (context) => captureManualScreenshot(
              binding: binding,
              tester: tester,
              name: 'failure_$context',
            );

      // The tasks list keys each row with the task's UUID
      // (KeyedSubtree(key: ValueKey(task.id)) around TaskBrowseListItem).
      // Other tab stacks stay alive offstage and can carry the same key, so
      // scope to the tasks page. The card may sit below the fold once the
      // list fills, so scroll it into view before tapping.
      final taskCard = find.descendant(
        of: find.byType(TasksTabPage),
        matching: find.byKey(ValueKey(task.id)),
      );

      await driver.step('intro', () async {
        // Let the startup settle: the Logbook's auto-select navigation fires
        // asynchronously and would otherwise steal a too-early tab switch.
        await driver.holdUntil(
          driver.timeline.elapsed + const Duration(seconds: 3),
        );
        // Switch tabs like a user would: click the "Tasks" rail item.
        final tasksRailItem = find
            .text(localized(en: 'Tasks', de: 'Aufgaben'))
            .hitTestable();
        await driver.pumpUntilFound(tasksRailItem);
        await driver.tapLikeUser(tasksRailItem);
        await driver.pumpUntilFound(taskCard);
      });

      await driver.step('open_task', () async {
        await driver.scrollIntoView(
          taskCard,
          scrollable: find.descendant(
            of: find.byType(TasksTabPage),
            matching: find.byType(Scrollable),
          ),
        );
        await driver.tapLikeUser(taskCard.hitTestable());
        await driver.pumpUntilFound(find.byKey(TaskActionBar.audioKey));
      });

      await driver.step('record_dictation', () async {
        await driver.tapLikeUser(find.byKey(TaskActionBar.audioKey));
        await driver.pumpUntilFound(find.byKey(const ValueKey('record')));
        await driver.tapLikeUser(find.byKey(const ValueKey('record')));
        await tester.pump(const Duration(milliseconds: 500));

        await driver.speakIntoMic(manifest.step('record_dictation').dictation!);

        // The stop control carries no key of its own — the row under
        // ValueKey('stop_controls') also contains cancel/pause, so target
        // the localized STOP label instead.
        final stopControl = find
            .text(localized(en: 'STOP', de: 'STOPP'))
            .hitTestable();
        await driver.pumpUntilFound(stopControl);
        await driver.tapLikeUser(stopControl);
        await tester.pump(const Duration(milliseconds: 500));
      });

      String? transcript;
      await driver.step('transcription', () async {
        await driver.pumpUntil(
          () async {
            transcript = await _linkedAudioTranscript(harness, task.id);
            return transcript != null && transcript!.trim().isNotEmpty;
          },
          description: 'Voxtral transcript on the linked audio entry',
          timeout: const Duration(minutes: 3),
        );
      });
      expect(
        transcript!.toLowerCase(),
        contains('waddle'),
        reason: 'transcript should carry the speech-dictionary vocabulary',
      );

      await driver.step('check_off', () async {
        final itemCheckbox = find.descendant(
          of: find.ancestor(
            of: find.text(checklistItemTitle),
            matching: find.byType(Row),
          ),
          matching: find.byType(Checkbox),
        );
        await driver.pumpUntilFound(find.text(checklistItemTitle));
        await driver.pumpUntilFound(itemCheckbox);
        await driver.tapLikeUser(itemCheckbox);
        await driver.pumpUntil(
          () => _checklistItemChecked(harness, checklistItemId),
          description: 'checklist item persisted as checked',
        );
      });

      await driver.step('outro', () async {});

      driver.timeline.write();
    },
    timeout: const Timeout(Duration(minutes: 10)),
  );
}

/// Direct-fallback transcription seed: one Melious provider with real
/// credentials plus one audio->text Voxtral model.
/// `ProfileAutomationService.tryTranscribe` selects them without any profile,
/// agent, or persisted skill (the built-in transcription skill lives in code).
List<AiConfig> _transcriptionConfigs() {
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
      id: 'tutorial-melious-provider',
      name: 'Melious.ai',
      baseUrl: baseUrl,
      apiKey: apiKey,
      createdAt: createdAt,
      inferenceProviderType: InferenceProviderType.melious,
    ),
    AiConfig.model(
      id: 'tutorial-voxtral-model',
      name: 'Voxtral Small',
      providerModelId: 'voxtral-small-24b-2507',
      inferenceProviderId: 'tutorial-melious-provider',
      createdAt: createdAt,
      inputModalities: const [Modality.audio, Modality.text],
      outputModalities: const [Modality.text],
      isReasoningModel: false,
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

Future<bool> _checklistItemChecked(
  TutorialAppHarness harness,
  String itemId,
) async {
  final entity = await harness.journalDb.journalEntityById(itemId);
  return entity is ChecklistItem && entity.data.isChecked;
}
