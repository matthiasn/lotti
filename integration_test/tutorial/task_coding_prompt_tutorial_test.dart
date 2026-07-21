/// Tutorial-video driver: "turn a coding task into an AI-ready prompt".
///
/// Drives the real app through the scenario in
/// `tools/tutorial_videos/config/scenarios/task_coding_prompt.yaml`:
///
///  1. open a complex coding task (description + checklist),
///  2. run the "Generate Coding Prompt" skill from the assistant menu,
///  3. wait for the REAL LLM (Qwen on Melious) to produce the
///     GeneratedPromptCard,
///  4. expand the full prompt and scroll through it SLOWLY on camera,
///  5. copy it to the clipboard.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lotti/beamer/beamer_app.dart';
import 'package:lotti/classes/checklist_item_data.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/tasks/repository/checklist_repository.dart';
import 'package:lotti/features/tasks/ui/pages/task_details_page.dart';
import 'package:lotti/features/tasks/ui/pages/tasks_tab_page.dart';
import 'package:lotti/features/tasks/ui/widgets/task_action_bar.dart';

import '../../test/helpers/manual_screenshot_locale.dart';
import '../manual_screenshot_utils.dart';
import 'tutorial_harness.dart';

const _providerId = 'tutorial-prompt-provider';
const _thinkingModelId = 'tutorial-prompt-thinking-model';
const _profileId = 'tutorial-prompt-profile';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final manifest = TutorialManifest.fromEnvironment();
  final locale = manualScreenshotLocaleFromEnvironment(Platform.environment);
  String localized({required String en, required String de}) =>
      manualScreenshotText(en: en, de: de);

  testWidgets(
    'drives the task-coding-prompt tutorial flow',
    (tester) async {
      tester.platformDispatcher.localeTestValue = locale;
      addTearDown(tester.platformDispatcher.clearLocaleTestValue);

      final harness = await TutorialAppHarness.setUp(
        aiConfigs: _promptConfigs(),
        languageCode: locale.languageCode,
        categoryTransform: (category) =>
            category.copyWith(defaultProfileId: _profileId),
      );
      addTearDown(harness.dispose);

      final taskTitle = localized(
        en: 'Refactor the habitat telemetry service',
        de: 'Habitat-Telemetrie-Dienst refaktorisieren',
      );
      final task = await harness.persistenceLogic.createTaskEntry(
        data: TaskData(
          title: taskTitle,
          status: TaskStatus.inProgress(
            id: 'tutorial-prompt-task-status',
            createdAt: DateTime.now(),
            utcOffset: DateTime.now().timeZoneOffset.inMinutes,
          ),
          dateFrom: DateTime.now(),
          dateTo: DateTime.now(),
          statusHistory: const [],
        ),
        entryText: EntryText(
          plainText: localized(
            en:
                'The telemetry service in the penguin habitat polls every '
                'sensor sequentially and blocks the feeding scheduler. '
                'Refactor it to an event-driven pipeline: batch the sensor '
                'reads, push updates over the existing message bus, and '
                'keep the public API backwards compatible. Mind the '
                'zero-gravity feeder integration and add tracing so '
                'mission control can debug latency spikes.',
            de:
                'Der Telemetrie-Dienst im Pinguin-Habitat fragt alle '
                'Sensoren sequenziell ab und blockiert den Fütterungsplan. '
                'Refaktorisiere ihn zu einer ereignisgesteuerten Pipeline: '
                'bündle die Sensor-Reads, schicke Updates über den '
                'vorhandenen Message-Bus und halte die öffentliche API '
                'abwärtskompatibel. Beachte die Integration des '
                'Schwerelosigkeits-Futterautomaten und ergänze Tracing, '
                'damit die Missionszentrale Latenzspitzen debuggen kann.',
          ),
        ),
        categoryId: harness.world.category.id,
      );
      expect(task, isNotNull);
      await ChecklistRepository().createChecklist(
        taskId: task!.meta.id,
        title: localized(en: 'Requirements', de: 'Anforderungen'),
        items: [
          ChecklistItemData(
            title: localized(
              en: 'Batch sensor reads into one poll cycle',
              de: 'Sensor-Reads in einen Poll-Zyklus bündeln',
            ),
            isChecked: false,
            linkedChecklists: const [],
          ),
          ChecklistItemData(
            title: localized(
              en: 'Publish updates on the message bus',
              de: 'Updates über den Message-Bus veröffentlichen',
            ),
            isChecked: false,
            linkedChecklists: const [],
          ),
          ChecklistItemData(
            title: localized(
              en: 'Keep the public API backwards compatible',
              de: 'Öffentliche API abwärtskompatibel halten',
            ),
            isChecked: false,
            linkedChecklists: const [],
          ),
          ChecklistItemData(
            title: localized(
              en: 'Add latency tracing for mission control',
              de: 'Latenz-Tracing für die Missionszentrale ergänzen',
            ),
            isChecked: false,
            linkedChecklists: const [],
          ),
        ],
      );

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
      for (var i = 0; i < 300; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }

      final driver =
          TutorialDriver(
              tester: tester,
              manifest: manifest,
              cursor: cursor,
              hud: hudClock,
            )
            ..diagnostics = () {
              final nav = harness.navService;
              return 'currentPath=${nav.currentPath} '
                  'detailStack=${nav.desktopTaskDetailStack.value} '
                  'promptCards=${find.text('Generate Coding Prompt').evaluate().length}';
            }
            ..onTimeout = (context) => captureManualScreenshot(
              binding: binding,
              tester: tester,
              name: 'failure_$context',
            );

      final taskCard = find.descendant(
        of: find.byType(TasksTabPage),
        matching: find.byKey(ValueKey(task.meta.id)),
      );
      final listScrollable = find.descendant(
        of: find.byType(TasksTabPage),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Scrollable &&
              axisDirectionToAxis(widget.axisDirection) == Axis.vertical,
        ),
      );
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
        await driver.pumpUntilFound(taskCard);
      });

      await driver.step('open_task', () async {
        await driver.scrollIntoView(taskCard, scrollable: listScrollable);
        await driver.tapLikeUser(taskCard.hitTestable());
        await driver.pumpUntilFound(find.byKey(TaskActionBar.audioKey));
      });

      await driver.step('generate', () async {
        // The assistant ("Generate…") button in the task detail header.
        final assistantButton = find
            .descendant(
              of: find.byType(TaskDetailsPage),
              matching: find.byTooltip(
                localized(en: 'Generate…', de: 'Generieren…'),
              ),
            )
            .hitTestable();
        await driver.pumpUntilFound(assistantButton);
        await driver.tapLikeUser(assistantButton.first);

        final skillRow = find.byKey(const ValueKey('skill-prompt-gen-001'));
        await driver.pumpUntilFound(skillRow);
        await driver.tapLikeUser(skillRow.hitTestable());
      });

      // The REAL LLM (Qwen on Melious) writes the prompt — a genuine wait,
      // fast-forwarded by the compositor.
      final promptCardTitle = find.text('Generate Coding Prompt');
      await driver.step('prompt_ready', () async {
        await driver.pumpUntilFound(
          promptCardTitle,
          timeout: const Duration(minutes: 4),
        );
        await driver.scrollIntoView(
          promptCardTitle,
          scrollable: detailScrollable,
        );
      });

      await driver.step('scroll_prompt', () async {
        final expandCaret = find.byTooltip(
          localized(
            en: 'Show full prompt',
            de: 'Vollständigen Prompt anzeigen',
          ),
        );
        await driver.pumpUntilFound(expandCaret);
        await driver.tapLikeUser(expandCaret.hitTestable());

        final copyButton = find.text(
          localized(en: 'Copy Prompt', de: 'Prompt kopieren'),
        );
        await driver.pumpUntilFound(copyButton);

        // Scroll through the expanded prompt SLOWLY: small position steps
        // with generous frame time, so viewers can actually read it.
        final scrollableElements = detailScrollable.evaluate().toList();
        ScrollableState? best;
        for (final element in scrollableElements) {
          final state = (element as StatefulElement).state as ScrollableState;
          if (!state.position.hasViewportDimension) continue;
          if (best == null ||
              state.position.viewportDimension >
                  best.position.viewportDimension) {
            best = state;
          }
        }
        expect(best, isNotNull, reason: 'detail pane must be scrollable');
        final position = best!.position;
        while (position.pixels < position.maxScrollExtent - 1) {
          position.jumpTo(
            (position.pixels + 30).clamp(0, position.maxScrollExtent),
          );
          for (var frame = 0; frame < 10; frame++) {
            await driver.tick();
          }
        }
        await driver.holdUntil(
          driver.timeline.elapsed + const Duration(seconds: 1),
        );
      });

      await driver.step('copy_prompt', () async {
        final copyButton = find
            .text(localized(en: 'Copy Prompt', de: 'Prompt kopieren'))
            .hitTestable();
        await driver.pumpUntilFound(copyButton);
        await driver.tapLikeUser(copyButton.first);
        await driver.pumpUntilFound(
          find.text(
            localized(
              en: 'Prompt copied to clipboard',
              de: 'Prompt in Zwischenablage kopiert',
            ),
          ),
          timeout: const Duration(seconds: 15),
        );
      });

      await driver.step('outro', () async {});

      driver.timeline.write();
    },
    timeout: const Timeout(Duration(minutes: 15)),
  );
}

/// Real-LLM seed: Melious provider (env creds) + Qwen thinking model +
/// default profile — the "Generate Coding Prompt" skill runs on the
/// profile's thinking slot.
List<AiConfig> _promptConfigs() {
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
      id: _providerId,
      name: 'Melious.ai',
      baseUrl: baseUrl,
      apiKey: apiKey,
      createdAt: createdAt,
      inferenceProviderType: InferenceProviderType.melious,
    ),
    AiConfig.model(
      id: _thinkingModelId,
      name: 'Qwen3.5 122B A10B',
      providerModelId: 'qwen3.5-122b-a10b',
      inferenceProviderId: _providerId,
      createdAt: createdAt,
      inputModalities: const [Modality.text],
      outputModalities: const [Modality.text],
      isReasoningModel: true,
      supportsFunctionCalling: true,
    ),
    AiConfig.inferenceProfile(
      id: _profileId,
      name: 'Tutorial Prompts',
      thinkingModelId: _thinkingModelId,
      createdAt: createdAt,
    ),
  ];
}
