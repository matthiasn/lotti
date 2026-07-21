/// Tutorial-video driver: "turn a coding task into an AI-ready prompt".
///
/// Drives the real app through the scenario in
/// `tools/tutorial_videos/config/scenarios/task_coding_prompt.yaml`:
///
///  1. open a complex coding task (description + checklist) that carries a
///     linked text note with the "current situation",
///  2. run the "Generate Coding Prompt" skill from the note's assistant menu
///     (prompt generation runs on a text-bearing entry — audio transcript or
///     typed note — with the task pulled in as context; there is no
///     "Generate…" control on the task's own header),
///  3. wait for the GeneratedPromptCard to render,
///  4. expand the full prompt and scroll through it SLOWLY on camera,
///  5. copy it to the clipboard.
///
/// The LLM call itself is mocked deterministically (fixed two-section
/// markdown response, short realistic latency) by overriding
/// `cloudInferenceRepositoryProvider` — mirrors `task_cover_art`'s approach
/// to `generateImage`, and keeps nightly-build output byte-for-byte
/// reproducible instead of depending on live model output. Everything else
/// (skill modal, profile resolution, prompt building, streaming collection,
/// card rendering) is the real product pipeline
/// (`SkillInferenceRunner.runPromptGeneration`).
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
import 'package:lotti/features/agents/service/agent_template_service.dart';
import 'package:lotti/features/agents/state/task_agent_providers.dart';
import 'package:lotti/features/ai/model/ai_call_impact.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/cloud_inference_repository.dart';
import 'package:lotti/features/tasks/repository/checklist_repository.dart';
import 'package:lotti/features/tasks/ui/pages/task_details_page.dart';
import 'package:lotti/features/tasks/ui/pages/tasks_tab_page.dart';
import 'package:lotti/features/tasks/ui/widgets/task_action_bar.dart';
import 'package:openai_dart/openai_dart.dart';

import '../../test/helpers/manual_screenshot_locale.dart';
import '../manual_screenshot_utils.dart';
import 'tutorial_harness.dart';

const _providerId = 'tutorial-prompt-provider';
const _thinkingModelId = 'tutorial-prompt-thinking-model';
const _profileId = 'tutorial-prompt-profile';

/// Deterministic prompt "generation": returns a fixed, realistic two-section
/// markdown response after a short delay — long enough that the "generating"
/// state is visible on camera, short enough to keep the build fast.
class _FakeCloudInferenceRepository extends CloudInferenceRepository {
  _FakeCloudInferenceRepository(this._response, super.ref);

  final String _response;

  @override
  Stream<CreateChatCompletionStreamResponse> generate(
    String prompt, {
    required String model,
    required double? temperature,
    required String baseUrl,
    required String apiKey,
    String? systemMessage,
    int? maxCompletionTokens,
    OpenAIClient? overrideClient,
    AiConfigInferenceProvider? provider,
    List<ChatCompletionTool>? tools,
    ChatCompletionToolChoiceOption? toolChoice,
    GeminiThinkingMode? geminiThinkingMode,
    ReasoningEffort? reasoningEffort,
    InferenceImpactCollector? impactCollector,
  }) {
    return Stream<CreateChatCompletionStreamResponse>.fromFuture(
      Future<CreateChatCompletionStreamResponse>.delayed(
        const Duration(seconds: 3),
        () => CreateChatCompletionStreamResponse(
          id: 'tutorial-prompt-response',
          choices: [
            ChatCompletionStreamResponseChoice(
              delta: ChatCompletionStreamResponseDelta(content: _response),
              index: 0,
            ),
          ],
          object: 'chat.completion.chunk',
          created: 0,
        ),
      ),
    );
  }
}

const _fakeGeneratedPromptEn = '''
## Summary
A prompt for refactoring the penguin habitat telemetry service from a sequential polling loop into an event-driven pipeline with batched sensor reads and message-bus updates.

## Prompt
You are helping refactor the telemetry service in the penguin habitat monitoring system.

**Background**
The current implementation polls every sensor sequentially in a tight loop, which blocks the feeding scheduler whenever a poll cycle takes longer than expected. This creates cascading delays across the whole habitat automation stack, most visibly on the zero-gravity feeder integration described in the "Requirements" checklist below.

**Current task**
Refactor the telemetry service into an event-driven pipeline:
- Batch the sensor reads into a single poll cycle instead of firing one round-trip per sensor.
- Publish updates over the existing message bus rather than blocking callers on a synchronous read.
- Keep the public API backwards compatible so downstream consumers (including the feeding scheduler) do not need to change.
- Add latency tracing so mission control can diagnose spikes after the refactor ships.

**Requirements checklist**
- [ ] Batch sensor reads into one poll cycle
- [ ] Publish updates on the message bus
- [ ] Keep the public API backwards compatible
- [ ] Add latency tracing for mission control

**Constraints**
- Must not regress the zero-gravity feeder integration, which depends on low-latency reads during feeding windows.
- The public API surface (method signatures, return types) must remain unchanged; only the internal implementation should move to an event-driven model.
- Tracing spans should be tagged with the originating sensor id so mission control can correlate a spike back to a specific unit.

**Deliverable**
Provide the refactored service implementation, a brief migration note describing how existing callers are affected (if at all), and a short list of the new tracing spans you added.''';

// Section headers stay in English ("## Summary" / "## Prompt") even in the
// German build — GeneratedPromptCard's parsing regex matches those literal
// English words regardless of locale (matching the real skill's own system
// instructions, which always specify English headers with a
// locale-appropriate body). A translated heading here would fail the regex
// and silently fall back to "first line as summary".
const _fakeGeneratedPromptDe = '''
## Summary
Ein Prompt zur Refaktorisierung des Telemetrie-Dienstes im Pinguin-Habitat von einer sequenziellen Abfrageschleife zu einer ereignisgesteuerten Pipeline mit gebündelten Sensor-Reads und Message-Bus-Updates.

## Prompt
Du hilfst dabei, den Telemetrie-Dienst im Überwachungssystem des Pinguin-Habitats zu refaktorisieren.

**Hintergrund**
Die aktuelle Implementierung fragt alle Sensoren sequenziell in einer engen Schleife ab, was den Fütterungsplan blockiert, sobald ein Abfragezyklus länger dauert als erwartet. Das erzeugt kaskadierende Verzögerungen im gesamten Habitat-Automatisierungsstack, am deutlichsten bei der Integration des Schwerelosigkeits-Futterautomaten aus der Checkliste "Anforderungen" unten.

**Aktuelle Aufgabe**
Refaktorisiere den Telemetrie-Dienst zu einer ereignisgesteuerten Pipeline:
- Bündle die Sensor-Reads in einem einzigen Abfragezyklus, statt für jeden Sensor einen eigenen Roundtrip zu senden.
- Veröffentliche Updates über den vorhandenen Message-Bus, statt Aufrufer mit einem synchronen Read zu blockieren.
- Halte die öffentliche API abwärtskompatibel, damit nachgelagerte Konsumenten (einschließlich des Fütterungsplans) nicht angepasst werden müssen.
- Ergänze Latenz-Tracing, damit die Missionszentrale Spitzen nach dem Refactoring diagnostizieren kann.

**Checkliste Anforderungen**
- [ ] Sensor-Reads in einen Poll-Zyklus bündeln
- [ ] Updates über den Message-Bus veröffentlichen
- [ ] Öffentliche API abwärtskompatibel halten
- [ ] Latenz-Tracing für die Missionszentrale ergänzen

**Randbedingungen**
- Die Integration des Schwerelosigkeits-Futterautomaten darf nicht regressieren, da sie während der Fütterungsfenster auf Reads mit niedriger Latenz angewiesen ist.
- Die öffentliche API-Oberfläche (Methodensignaturen, Rückgabetypen) muss unverändert bleiben; nur die interne Implementierung soll auf ein ereignisgesteuertes Modell umgestellt werden.
- Tracing-Spans sollten mit der ursprünglichen Sensor-ID getaggt werden, damit die Missionszentrale eine Spitze auf eine bestimmte Einheit zurückführen kann.

**Ergebnis**
Liefere die refaktorisierte Dienst-Implementierung, einen kurzen Migrationshinweis dazu, wie bestehende Aufrufer betroffen sind (falls überhaupt), und eine kurze Liste der neu hinzugefügten Tracing-Spans.''';

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
          // ProfileAutomationResolver.resolveForTask reads task.data.profileId
          // directly — it does NOT fall back to category.defaultProfileId.
          // Without this, the skill trigger silently no-ops (no profile
          // configured) and the picker/progress flow never produces a result.
          profileId: _profileId,
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

      // Prompt generation runs on a text-bearing entry (audio transcript or
      // typed note), not on the task itself — this linked voice note is what
      // the "Generate…" menu actually attaches to; `linkedFromId: task.id`
      // gives the skill its full-task context (checklist, description).
      // JournalAudio (not a typed JournalEntry note) — mirrors
      // task_cover_art's linked-note shape, which is proven to render
      // correctly in the task detail split pane.
      final situationTranscript = localized(
        en:
            'Just hit this in staging: the telemetry poll loop '
            'stalls for 4-6 seconds whenever more than a dozen '
            'sensors report at once, and the feeding scheduler '
            'queue backs up right behind it. Need a prompt I can '
            'hand to a coding assistant to fix this properly.',
        de:
            'Gerade in der Staging-Umgebung aufgefallen: Die '
            'Telemetrie-Abfrageschleife hängt 4 bis 6 Sekunden, '
            'sobald mehr als ein Dutzend Sensoren gleichzeitig '
            'melden, und die Fütterungsplan-Warteschlange staut '
            'sich direkt dahinter. Brauche einen Prompt für einen '
            'Coding-Assistenten, um das sauber zu beheben.',
      );
      final noteMeta = await harness.persistenceLogic.createMetadata();
      final situationNote = JournalEntity.journalAudio(
        meta: noteMeta.copyWith(categoryId: harness.world.category.id),
        // The real recorder writes a finished transcript into BOTH
        // data.transcripts and entryText (RecorderController's
        // _saveRealtimeTranscript) — the note's visible card only ever
        // renders entryText (via the note editor), never
        // AudioTranscript.transcript directly, so this is needed for the
        // transcript to actually show on screen.
        entryText: EntryText(
          plainText: situationTranscript,
          markdown: situationTranscript,
        ),
        data: AudioData(
          dateFrom: DateTime.now(),
          dateTo: DateTime.now(),
          audioFile: 'tutorial-prompt-note.m4a',
          audioDirectory: '/audio/tutorial/',
          duration: const Duration(seconds: 14),
          transcripts: [
            AudioTranscript(
              created: DateTime.now(),
              library: 'tutorial',
              model: 'voxtral-small-24b-2507',
              detectedLanguage: locale.languageCode,
              transcript: situationTranscript,
            ),
          ],
        ),
      );
      await harness.persistenceLogic.createDbEntity(
        situationNote,
        shouldAddGeolocation: false,
        enqueueSync: false,
        linkedId: task.id,
      );

      final fakeResponse = localized(
        en: _fakeGeneratedPromptEn,
        de: _fakeGeneratedPromptDe,
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
              overrides: [
                ...harness.providerOverrides(),
                cloudInferenceRepositoryProvider.overrideWith(
                  (ref) => _FakeCloudInferenceRepository(fakeResponse, ref),
                ),
              ],
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

      // Land on Tasks BEFORE the recorded timeline starts — the app's real
      // default landing tab is the Logbook (Journal), which would
      // otherwise flash on screen during the intro step's establishing
      // hold.
      harness.navService.setIndex(
        harness.navService.beamerDelegates.indexOf(
          harness.navService.tasksDelegate,
        ),
      );
      await tester.pump();

      // Give the task a real (non-dormant) agent — without this the AI
      // summary card only shows an "Assign agent" CTA for the whole video.
      final container = ProviderScope.containerOf(
        tester.element(find.byType(MyBeamerApp)),
      );
      await container
          .read(taskAgentServiceProvider)
          .createTaskAgent(
            taskId: task.id,
            allowedCategoryIds: {harness.world.category.id},
            templateId: lauraTemplateId,
            profileId: _profileId,
          );

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

      // This scenario starts from a dictated voice note (the "current
      // situation") — its card carries both the transcript and the
      // "Generate…" control.
      final assistantButton = find
          .descendant(
            of: find.byType(TaskDetailsPage),
            matching: find.byTooltip(
              localized(en: 'Generate…', de: 'Generieren…'),
            ),
          )
          .hitTestable();
      // findRichText: true — flutter_quill's editor renders each line as a
      // bare RichText (text_line.dart), never wrapped in a Text widget, so
      // the default text finder (Text/EditableText only) never matches
      // editor-rendered content at all, regardless of whether it's
      // populated. Scoped to TaskDetailsPage: the demo world's stock task
      // list includes an unrelated seeded task titled "Startprüfung für
      // Project Waddle" in the sidebar, always in the tree — a search for
      // this content unscoped would risk a false match there instead of
      // actually verifying the editor.
      final transcriptText = find.descendant(
        of: find.byType(TaskDetailsPage),
        matching: find.textContaining(
          localized(en: 'staging', de: 'Staging-Umgebung'),
          findRichText: true,
        ),
      );

      await driver.step('review_transcript', () async {
        // Center the transcript text itself (not the button below it) —
        // Scrollable.ensureVisible walks outward through nested
        // scrollables (the checklist above it has its own reorderable
        // list) from the target's own position, so this reliably frames
        // the transcript regardless of what else is on the page.
        await driver.scrollIntoView(
          transcriptText,
          scrollable: detailScrollable,
        );
        // A dedicated step (its own min_duration/narration in the
        // scenario YAML) so the hold survives the compositor's wait-span
        // compression — a hold embedded mid-step got compressed away.
        await driver.holdUntil(
          driver.timeline.elapsed + const Duration(seconds: 2),
        );
      });

      await driver.step('generate', () async {
        await driver.tapLikeUser(assistantButton.first);

        final skillRow = find.byKey(const ValueKey('skill-prompt-gen-001'));
        await driver.pumpUntilFound(skillRow);
        await driver.tapLikeUser(skillRow.hitTestable());

        // Reasoning-capable skills open a model-override picker (thinking
        // slot) before running — select the profile's configured default
        // (Qwen3.5 122B A10B) rather than overriding it.
        final defaultModelOption = find.text('Qwen3.5 122B A10B').hitTestable();
        await driver.pumpUntilFound(defaultModelOption);
        await driver.tapLikeUser(defaultModelOption.first);
      });

      // The mocked LLM response lands after a short, realistic delay (see
      // _FakeCloudInferenceRepository) — deterministic, so no long timeout
      // is needed here.
      final promptCardTitle = find.text('Generate Coding Prompt');
      await driver.step('prompt_ready', () async {
        await driver.pumpUntilFound(
          promptCardTitle,
          timeout: const Duration(seconds: 30),
        );
        await driver.scrollIntoView(
          promptCardTitle,
          scrollable: detailScrollable,
        );
        // Regression guard: a persistence failure (e.g. a missing getIt
        // registration hit by createDbEntity's post-save side effects)
        // surfaces as this error toast while the card still renders with a
        // placeholder body — catch it here instead of shipping a video with
        // a visible error banner.
        expect(
          find.textContaining('Failed to persist').evaluate(),
          isEmpty,
          reason: 'prompt generation must persist without error',
        );
        // The summary (always visible, even collapsed) must show the real
        // mocked content, not a fallback/placeholder string.
        await driver.pumpUntilFound(
          find.textContaining(
            localized(
              en: 'event-driven pipeline with batched sensor reads',
              de: 'ereignisgesteuerten Pipeline mit gebündelten Sensor-Reads',
            ),
          ),
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
        // The copy button is pinned near the card's top (beside its title),
        // not the bottom — scroll_prompt just swept all the way down to
        // read the body, so scroll back up to reach it.
        final copyButton = find
            .text(localized(en: 'Copy Prompt', de: 'Prompt kopieren'))
            .hitTestable();
        await driver.scrollIntoView(copyButton, scrollable: detailScrollable);
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

/// Skill seed: Melious provider (fake credentials — the actual HTTP call is
/// fully intercepted by `_FakeCloudInferenceRepository`, so no real network
/// access or API key is ever needed) + Qwen thinking model + default
/// profile. The "Generate Coding Prompt" skill runs on the profile's
/// thinking slot.
List<AiConfig> _promptConfigs() {
  final createdAt = DateTime.now();
  return [
    AiConfig.inferenceProvider(
      id: _providerId,
      name: 'Melious.ai',
      baseUrl: 'https://melious.invalid',
      apiKey: 'tutorial-fake-key',
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
