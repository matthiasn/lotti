/// Tutorial-video driver: "let AI create your task's cover art".
///
/// Drives the real app through the scenario in
/// `tools/tutorial_videos/config/scenarios/task_cover_art.yaml`:
///
///  1. open a simple task that carries a voice note describing it,
///  2. run "Generate Cover Art" from the note's AI assistant ("Generate…")
///     menu — the real trigger path, not the "More actions" overflow's
///     direct shortcut,
///  3. watch the generation progress, then the artwork land as the task's
///     cover in the header and on the list card.
///
/// The image GENERATION is mocked deterministically (the bundled penguin
/// artwork every run, short realistic latency) by overriding
/// `cloudInferenceRepositoryProvider` — everything else (skill modal,
/// progress view, image import, automatic cover assignment) is the real
/// product pipeline (`SkillInferenceRunner.runImageGeneration`).
@Tags(['tutorial-video'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lotti/beamer/beamer_app.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/agents/service/agent_template_service.dart';
import 'package:lotti/features/agents/state/task_agent_providers.dart';
import 'package:lotti/features/ai/model/ai_call_impact.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/cloud_inference_repository.dart';
import 'package:lotti/features/ai/repository/gemini_inference_payloads.dart';
import 'package:lotti/features/ai/util/image_processing_utils.dart';
import 'package:lotti/features/tasks/ui/pages/task_details_page.dart';
import 'package:lotti/features/tasks/ui/pages/tasks_tab_page.dart';
import 'package:lotti/features/tasks/ui/task_expandable_app_bar.dart';
import 'package:lotti/features/tasks/ui/widgets/task_action_bar.dart';

import '../../test/helpers/manual_screenshot_locale.dart';
import '../manual_screenshot_utils.dart';
import 'tutorial_harness.dart';

const _providerId = 'tutorial-image-provider';
const _thinkingModelId = 'tutorial-image-thinking-model';
const _imageModelId = 'tutorial-image-gen-model';
const _profileId = 'tutorial-image-profile';

/// Deterministic image "generation": returns the bundled penguin artwork
/// after a short, realistic delay. Same cover art every run.
class _FakeCloudInferenceRepository extends CloudInferenceRepository {
  _FakeCloudInferenceRepository(super.ref);

  @override
  Future<GeneratedImage> generateImage({
    required String prompt,
    required String model,
    required AiConfigInferenceProvider provider,
    String? systemMessage,
    List<ProcessedReferenceImage>? referenceImages,
    InferenceImpactCollector? impactCollector,
  }) async {
    await Future<void>.delayed(const Duration(seconds: 5));
    final data = await rootBundle.load(
      'assets/design_system/manual_task_cover_habitat.webp',
    );
    // The headless engine can hang indefinitely decoding a resized WebP
    // (same caveat as ManualDemoWorld's transcodeManualDemoMediaToPng) — a
    // real desktop run under Xvfb does not hang, but the image silently
    // never renders either, so no cover appears. Transcode to PNG for a
    // format the cover-art pipeline reliably decodes and displays.
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    final frame = await codec.getNextFrame();
    final png = await frame.image.toByteData(format: ui.ImageByteFormat.png);
    frame.image.dispose();
    codec.dispose();
    return GeneratedImage(
      bytes: png!.buffer.asUint8List(),
      mimeType: 'image/png',
    );
  }
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final manifest = TutorialManifest.fromEnvironment();
  final locale = manualScreenshotLocaleFromEnvironment(Platform.environment);
  String localized({
    required String en,
    required String de,
    String? fr,
    String? it,
    String? es,
    String? cs,
    String? nl,
    String? ro,
    String? pt,
    String? da,
    String? sv,
  }) => manualScreenshotText(
    en: en,
    de: de,
    fr: fr,
    it: it,
    es: es,
    cs: cs,
    nl: nl,
    ro: ro,
    pt: pt,
    da: da,
    sv: sv,
  );

  testWidgets(
    'drives the task-cover-art tutorial flow',
    (tester) async {
      tester.platformDispatcher.localeTestValue = locale;
      addTearDown(tester.platformDispatcher.clearLocaleTestValue);

      final harness = await TutorialAppHarness.setUp(
        aiConfigs: _imageGenConfigs(),
        languageCode: locale.languageCode,
        categoryTransform: (category) =>
            category.copyWith(defaultProfileId: _profileId),
      );
      addTearDown(harness.dispose);

      final taskTitle = localized(
        en: 'Plan the penguin photo expedition',
        de: 'Pinguin-Fotoexpedition planen',
        fr: "Planifier l'expédition photo des pingouins",
        it: 'Pianifica la spedizione fotografica dei pinguini',
        es: 'Planifica la expedición fotográfica de pingüinos',
        cs: 'Naplánuj fotoexpedici za tučňáky',
        nl: 'Plan de pinguïn-fotoexpeditie',
        ro: 'Planificați expediția foto cu pinguini',
        pt: 'Planeje a expedição fotográfica dos pinguins',
        da: 'Planlæg pingvinfotoekspeditionen',
        sv: 'Planera pingvinfotoexpeditionen',
      );
      final task = await harness.persistenceLogic.createTaskEntry(
        data: TaskData(
          title: taskTitle,
          status: TaskStatus.open(
            id: 'tutorial-cover-task-status',
            createdAt: DateTime.now(),
            utcOffset: DateTime.now().timeZoneOffset.inMinutes,
          ),
          dateFrom: DateTime.now(),
          dateTo: DateTime.now(),
          statusHistory: const [],
          // ProfileAutomationResolver.resolveForTask reads task.data.profileId
          // directly — it does NOT fall back to category.defaultProfileId.
          // Without this, the skill trigger silently no-ops (no profile
          // configured) and the progress modal spins forever.
          profileId: _profileId,
        ),
        entryText: const EntryText(plainText: ''),
        categoryId: harness.world.category.id,
      );
      expect(task, isNotNull);

      // The voice note whose description feeds the cover-art generation.
      final noteTranscript = localized(
        en:
            'A colony of emperor penguins on the ice shelf at '
            'golden hour, aurora overhead, expedition gear in the '
            'foreground — Project Waddle.',
        de:
            'Eine Kolonie Kaiserpinguine auf dem Schelfeis zur '
            'goldenen Stunde, Polarlicht am Himmel, '
            'Expeditionsausrüstung im Vordergrund — Projekt Waddle.',
        fr:
            'Une colonie de manchots empereurs sur la banquise à '
            "l'heure dorée, aurore boréale au-dessus, matériel "
            "d'expédition au premier plan — Projet Waddle.",
        it:
            'Una colonia di pinguini imperatore sulla piattaforma di '
            "ghiaccio all'ora dorata, aurora boreale sopra, "
            'attrezzatura da spedizione in primo piano — Progetto Waddle.',
        es:
            'Una colonia de pingüinos emperador en la plataforma de '
            'hielo a la hora dorada, aurora boreal en el cielo, '
            'equipo de expedición en primer plano — Proyecto Waddle.',
        cs:
            'Kolonie tučňáků císařských na ledovém šelfu za zlaté '
            'hodiny, polární záře na obloze, expediční vybavení '
            'v popředí — Projekt Waddle.',
        nl:
            'Een kolonie keizerspinguïns op de ijsplaat tijdens het '
            'gouden uur, een aurora aan de hemel, expeditieuitrusting '
            'op de voorgrond — Project Waddle.',
        ro:
            'O colonie de pinguini imperiali pe platforma de gheață în '
            'timpul orei aurii, aurora boreală deasupra, echipament de '
            'expediție în prim-plan — Proiect Waddle.',
        pt:
            'Uma colônia de pinguins-imperadores na plataforma de gelo '
            'durante a hora dourada, aurora no céu, equipamento de '
            'expedição em primeiro plano — Projeto Waddle.',
        da:
            'En koloni af kejserpingviner på iskappen i den gyldne '
            'time, nordlys i himlen, ekspeditionsudstyr i '
            'forgrunden — Projekt Waddle.',
        sv:
            'En koloni kejsarpingviner på isplattformen under den '
            'gyllene timmen, norrsken i himlen, expeditionsutrustning '
            'i förgrunden — Projekt Waddle.',
      );
      final noteMeta = await harness.persistenceLogic.createMetadata();
      final audioNote = JournalEntity.journalAudio(
        meta: noteMeta.copyWith(categoryId: harness.world.category.id),
        // The real recorder writes a finished transcript into BOTH
        // data.transcripts and entryText (RecorderController's
        // _saveRealtimeTranscript) — the note's visible card only ever
        // renders entryText (via the note editor), never
        // AudioTranscript.transcript directly.
        entryText: EntryText(
          plainText: noteTranscript,
          markdown: noteTranscript,
        ),
        data: AudioData(
          dateFrom: DateTime.now(),
          dateTo: DateTime.now(),
          audioFile: 'tutorial-note.m4a',
          audioDirectory: '/audio/tutorial/',
          duration: const Duration(seconds: 17),
          transcripts: [
            AudioTranscript(
              created: DateTime.now(),
              library: 'tutorial',
              model: 'voxtral-small-24b-2507',
              detectedLanguage: locale.languageCode,
              transcript: noteTranscript,
            ),
          ],
        ),
      );
      await harness.persistenceLogic.createDbEntity(
        audioNote,
        shouldAddGeolocation: false,
        enqueueSync: false,
        linkedId: task!.id,
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
                  _FakeCloudInferenceRepository.new,
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
                  'moreButtons=${find.byTooltip(localized(
                    en: 'More actions',
                    de: 'Weitere Aktionen',
                    fr: "Plus d'actions",
                    it: 'Altre azioni',
                    es: 'Más acciones',
                    cs: 'Další akce',
                    nl: 'Meer acties',
                    ro: 'Mai multe acțiuni',
                    pt: 'Mais ações',
                    da: 'Flere aktioner',
                    sv: 'Fler åtgärder',
                  )).evaluate().length}';
            }
            ..onTimeout = (context) => captureManualScreenshot(
              binding: binding,
              tester: tester,
              name: 'failure_$context',
            );

      final taskCard = find.descendant(
        of: find.byType(TasksTabPage),
        matching: find.byKey(ValueKey(task.id)),
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
            .text(
              localized(
                en: 'Tasks',
                de: 'Aufgaben',
                fr: 'Tâches',
                it: 'Compiti',
                es: 'Tareas',
                cs: 'Úkoly',
                nl: 'Taken',
                ro: 'Sarcini',
                pt: 'Tarefas',
                da: 'Opgaver',
                sv: 'Uppgifter',
              ),
            )
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
        // Bring the voice note (with its description) into view.
        //
        // findRichText: true — flutter_quill's editor renders each line as
        // a bare RichText (text_line.dart), never wrapped in a Text
        // widget, so the default text finder never matches editor-rendered
        // content, regardless of whether it's populated. Scoped to
        // TaskDetailsPage: the demo world's stock task list includes an
        // unrelated seeded task titled "Startprüfung für Project Waddle"
        // in the sidebar, always in the tree — an unscoped search for this
        // word risks a false match there instead of actually verifying
        // the note's transcript.
        final noteTranscriptText = find.descendant(
          of: find.byType(TaskDetailsPage),
          matching: find.textContaining('Waddle', findRichText: true),
        );
        // The action bar rendering doesn't guarantee the linked note's
        // EditorWidget further down the page has built its Quill
        // controller yet (a microtask scheduled off entry load) — give it
        // a beat before searching for it.
        await driver.pumpUntilFound(
          noteTranscriptText,
          timeout: const Duration(seconds: 15),
        );
        await driver.scrollIntoView(
          noteTranscriptText,
          scrollable: detailScrollable,
        );
      });

      await driver.step('generate', () async {
        // The AI assistant ("Generate…") menu on the note — the real
        // trigger path, not the "More actions" overflow's direct shortcut
        // item, which duplicates the same skill without going through the
        // skill picker a user actually sees.
        final assistantButton = find
            .descendant(
              of: find.byType(TaskDetailsPage),
              matching: find.byTooltip(
                localized(
                  en: 'Generate…',
                  de: 'Generieren…',
                  fr: 'Générer…',
                  it: 'Genera...',
                  es: 'Generar…',
                  cs: 'Generovat…',
                  nl: 'Genereren...',
                  ro: 'Generează…',
                  pt: 'Gerar…',
                  da: 'Generer...',
                  sv: 'Generera...',
                ),
              ),
            )
            .hitTestable();
        await driver.pumpUntilFound(assistantButton);
        await driver.scrollIntoView(
          assistantButton,
          scrollable: detailScrollable,
        );
        await driver.tapLikeUser(assistantButton.first);

        final skillRow = find.byKey(const ValueKey('skill-image-gen-001'));
        await driver.pumpUntilFound(skillRow);
        await driver.tapLikeUser(skillRow.hitTestable());

        // The harness's shared AI setup registers a real Gemini image
        // model alongside the scenario's own "Tutorial Cover Artist",
        // so 2+ image models means a provider/model picker appears —
        // select the profile's configured default (already marked
        // "Standard ✓") rather than overriding it.
        final defaultModelOption = find
            .text('Tutorial Cover Artist')
            .hitTestable();
        await driver.pumpUntilFound(defaultModelOption);
        await driver.tapLikeUser(defaultModelOption.first);

        // No other images are linked to this task, so
        // ReferenceImageSelectionWidget's `availableImages` is empty and it
        // auto-skips itself via a post-frame callback — there is no
        // tappable "Skip" button to wait for; generation starts right
        // after the model is picked.

        // Catch the "generating" state immediately — the mocked generation
        // is fast enough that this step's own min_duration hold (below)
        // can otherwise outlast it, so a later poll would only ever see the
        // completed state.
        await driver.pumpUntilFound(
          find.text(
            localized(
              en: 'Generating image...',
              de: 'Bild wird generiert...',
              fr: "Génération de l'image...",
              it: "Generando l'immagine...",
              es: 'Generando imagen...',
              cs: 'Generování obrázku...',
              nl: 'Afbeelding aanmaken...',
              ro: 'Se generează imaginea...',
              pt: 'Gerando imagem...',
              da: 'Genererer billede...',
              sv: 'Genererar bild...',
            ),
          ),
          timeout: const Duration(seconds: 15),
        );
      });

      await driver.step('generating', () async {
        await driver.pumpUntil(
          () async {
            final entity = await harness.journalDb.journalEntityById(task.id);
            return entity is Task && entity.data.coverArtId != null;
          },
          description: 'generated image assigned as task cover',
          timeout: const Duration(minutes: 2),
        );
      });

      await driver.step('cover_ready', () async {
        // Dismiss via the modal's own close button (ModalUtils.showSinglePageModal
        // uses MaterialLocalizations.closeButtonTooltip) — a barrier tap is
        // layout-position-dependent and broke when the pane widths changed.
        final closeButton = find
            .byTooltip(
              localized(
                en: 'Close',
                de: 'Schließen',
                fr: 'Fermer',
                it: 'Chiudi',
                es: 'Cerrar',
                cs: 'Zavřít',
                nl: 'Sluiten',
                ro: 'Închideți',
                pt: 'Fechar',
                da: 'Luk',
                sv: 'Stäng',
              ),
            )
            .hitTestable();
        await driver.pumpUntilFound(closeButton);
        await driver.tapLikeUser(closeButton.last);
        await driver.pumpUntilFound(
          find.byType(TaskExpandableAppBar),
          timeout: const Duration(seconds: 20),
        );
        await driver.scrollIntoView(taskCard, scrollable: listScrollable);
        await driver.pumpUntil(
          () => find
              .descendant(of: taskCard, matching: find.byType(Image))
              .evaluate()
              .isNotEmpty,
          description: 'cover art visible on the list card',
        );
      });

      await driver.step('outro', () async {});

      driver.timeline.write();
    },
    timeout: const Timeout(Duration(minutes: 10)),
  );
}

/// Image-generation seed: provider + image-output model + default profile
/// with the image-generation slot set. The fake repository makes no
/// network calls, but profile resolution requires the rows to exist. The
/// harness's shared setup also registers a real Gemini image model, so 2+
/// image models are configured in practice — the model picker does appear
/// (see the `generate` step).
List<AiConfig> _imageGenConfigs() {
  final createdAt = DateTime.now();
  return [
    AiConfig.inferenceProvider(
      id: _providerId,
      name: 'Tutorial Images',
      baseUrl: 'https://images.invalid',
      apiKey: 'tutorial-fake-key',
      createdAt: createdAt,
      inferenceProviderType: InferenceProviderType.gemini,
    ),
    AiConfig.model(
      id: _thinkingModelId,
      name: 'Tutorial Thinking',
      providerModelId: 'tutorial-thinking',
      inferenceProviderId: _providerId,
      createdAt: createdAt,
      inputModalities: const [Modality.text],
      outputModalities: const [Modality.text],
      isReasoningModel: true,
    ),
    AiConfig.model(
      id: _imageModelId,
      name: 'Tutorial Cover Artist',
      providerModelId: 'tutorial-cover-artist',
      inferenceProviderId: _providerId,
      createdAt: createdAt,
      inputModalities: const [Modality.text],
      outputModalities: const [Modality.image],
      isReasoningModel: false,
    ),
    AiConfig.inferenceProfile(
      id: _profileId,
      name: 'Tutorial Images',
      thinkingModelId: _thinkingModelId,
      imageGenerationModelId: _imageModelId,
      createdAt: createdAt,
    ),
  ];
}
