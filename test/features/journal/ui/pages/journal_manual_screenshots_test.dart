/// Deterministic manual screenshots for the production Journal surfaces.
///
/// The fixtures extend the shared Intergalactic Penguin Logistics world with
/// a Mission Control briefing, launch photography, an audio memo, an event,
/// an AI cargo summary, and linked follow-up activity. Captures render
/// [InfiniteJournalPage], [EntryDetailsPage], and their production modals
/// directly; no Widgetbook or showcase host is involved.
///
/// Opt in with an external output directory:
/// `LOTTI_SCREENSHOT_DIR=/tmp/journal fvm flutter test \
///   test/features/journal/ui/pages/journal_manual_screenshots_test.dart`
library;

import 'dart:async';
import 'dart:io';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/event_data.dart';
import 'package:lotti/classes/event_status.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/rating_data.dart';
import 'package:lotti/database/state/config_flag_provider.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_floating_action_button.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/journal/model/entry_state.dart';
import 'package:lotti/features/journal/state/journal_page_controller.dart';
import 'package:lotti/features/journal/state/journal_page_state.dart';
import 'package:lotti/features/journal/state/linked_entries_controller.dart';
import 'package:lotti/features/journal/state/linked_from_entries_controller.dart';
import 'package:lotti/features/journal/ui/pages/entry_details_page.dart';
import 'package:lotti/features/journal/ui/pages/infinite_journal_page.dart';
import 'package:lotti/features/journal/ui/widgets/entry_details/entry_datetime_multipage_modal.dart';
import 'package:lotti/features/journal/ui/widgets/entry_details/entry_datetime_widget.dart';
import 'package:lotti/features/journal/ui/widgets/entry_image_widget.dart';
import 'package:lotti/features/journal/ui/widgets/linked_entries_activity_filter_bar.dart';
import 'package:lotti/features/journal/ui/widgets/list_cards/card_wrapper_widget.dart';
import 'package:lotti/features/journal/utils/entry_types.dart';
import 'package:lotti/features/keyboard/ui/app_command_host.dart';
import 'package:lotti/features/labels/state/labels_list_controller.dart';
import 'package:lotti/features/ratings/repository/rating_repository.dart';
import 'package:lotti/features/ratings/ui/session_rating_modal.dart';
import 'package:lotti/features/speech/ui/widgets/speech_modal/speech_modal.dart';
import 'package:lotti/features/speech/ui/widgets/speech_modal/transcripts_list_item.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/editor_state_service.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/services/time_service.dart';
import 'package:lotti/utils/consts.dart';
import 'package:lotti/utils/image_utils.dart';
import 'package:lotti/widgets/app_bar/journal_sliver_appbar.dart';
import 'package:lotti/widgets/modal/index.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/fake_entry_controller.dart';
import '../../../../helpers/manual_demo_world.dart';
import '../../../../helpers/target_platform.dart';
import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';
import '../../../categories/test_utils.dart';
import '../../../daily_os_next/screenshot_harness.dart';

const _subdir = 'journal';
String _t(String en, String de) => manualScreenshotText(en: en, de: de);
const _briefingId = 'journal-project-waddle-briefing';

class _ManualJournalPageController extends JournalPageController {
  _ManualJournalPageController(this._snapshot);

  final JournalPageState _snapshot;

  @override
  JournalPageState build() => _snapshot;

  @override
  Future<void> refreshQuery({bool preserveVisibleItems = false}) async {}
}

class _ManualEntryController extends FakeEntryController {
  _ManualEntryController(this.entity) : super(entity);

  final JournalEntity entity;

  @override
  Future<EntryState?> build() {
    final result = super.build();
    final text =
        entity.entryText?.plainText ?? entity.entryText?.markdown ?? '';
    controller.dispose();
    controller = QuillController.basic();
    if (text.isNotEmpty) {
      controller.document.insert(0, text);
    }
    return result;
  }
}

Widget _app({
  required Widget home,
  required Brightness brightness,
  required ScreenshotDevice device,
  required List<Override> overrides,
  required TargetPlatform platform,
}) {
  final baseTheme = brightness == Brightness.dark
      ? DesignSystemTheme.dark()
      : DesignSystemTheme.light();
  final screenshotTheme = baseTheme.copyWith(
    // The production journal still uses Material's legacy titleSmall slot in
    // two places. The DS theme intentionally leaves that slot unmapped, while
    // widget tests substitute Ahem for the platform fallback. Reuse the
    // nearest mapped DS title style so captures show real app typography.
    textTheme: baseTheme.textTheme.copyWith(
      titleSmall: baseTheme.textTheme.titleMedium,
    ),
  );
  return RepaintBoundary(
    key: screenshotBoundaryKey,
    child: ProviderScope(
      overrides: overrides,
      child: MediaQuery(
        data: MediaQueryData(size: device.size, disableAnimations: true),
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: screenshotTheme,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          locale: manualScreenshotLocale,
          home: AppCommandHost(
            handlers: const {},
            platform: platform,
            child: home,
          ),
        ),
      ),
    ),
  );
}

void main() {
  if (!screenshotCaptureEnabled) {
    test(
      'journal manual screenshot harness (opt-in)',
      () {},
      skip: 'Set LOTTI_SCREENSHOT_DIR to capture manual screenshots.',
    );
    return;
  }

  setUpAll(loadScreenshotFonts);

  late ManualDemoWorld world;
  late Directory documentsDirectory;
  late PagingController<int, JournalEntity> pagingController;
  late JournalPageState pageState;
  late JournalEntry briefing;
  late JournalImage launchPhoto;
  late JournalAudio audioMemo;
  late JournalEntry rehearsalTimer;
  late AiResponseEntry diagnosticPrompt;
  late List<EntryLink> links;
  late List<CategoryDefinition> categories;
  late MockRatingRepository ratingRepository;

  Metadata metadata(
    String id,
    DateTime from, {
    Duration duration = Duration.zero,
    String? categoryId = manualDemoCategoryId,
    List<String>? labelIds,
    bool starred = false,
    bool private = false,
    EntryFlag? flag,
  }) => Metadata(
    id: id,
    createdAt: from,
    updatedAt: from,
    dateFrom: from,
    dateTo: from.add(duration),
    categoryId: categoryId,
    labelIds: labelIds,
    starred: starred,
    private: private,
    flag: flag,
  );

  setUp(() async {
    world = ManualDemoWorld.penguinLogistics();
    documentsDirectory = await Directory.systemTemp.createTemp(
      'lotti-manual-journal-',
    );
    final installedMedia = await world.installMedia(documentsDirectory);
    await transcodeManualDemoMediaToPng(installedMedia);

    final missionControl = CategoryTestUtils.createTestCategory(
      id: 'manual-mission-control',
      name: _t('Mission Control', 'Missionskontrolle'),
      color: '#6750A4',
    );
    final fishDiplomacy = CategoryTestUtils.createTestCategory(
      id: 'manual-fish-diplomacy',
      name: _t('Fish Diplomacy', 'Fischdiplomatie'),
      color: '#FBA337',
    );
    final humanMaintenance = CategoryTestUtils.createTestCategory(
      id: 'manual-human-maintenance',
      name: _t('Human Maintenance', 'Menschenwartung'),
      color: '#3CB371',
    );
    categories = [
      world.category,
      missionControl,
      fishDiplomacy,
      humanMaintenance,
    ];

    briefing = JournalEntry(
      meta: metadata(
        _briefingId,
        DateTime(2026, 7, 17, 8, 10),
        duration: const Duration(minutes: 30),
        labelIds: const [
          manualDemoProjectLabelId,
          manualDemoCriticalLabelId,
        ],
        starred: true,
      ),
      entryText: EntryText(
        plainText: _t(
          'Project Waddle mission log — pressure seals green, 37 emperor '
              'penguins present, and the sardine cargo is cold.',
          'Project-Waddle-Missionslog — Druckdichtungen grün, 37 '
              'Kaiserpinguine anwesend und die Sardinenfracht ist kalt.',
        ),
        markdown: _t(
          '# Project Waddle mission log\n\n'
              'All **37 emperor penguins** reported for launch rehearsal.\n\n'
              '- Pressure seals: green\n'
              '- Sardine cargo: cold\n'
              '- Fish feeder: suspiciously enthusiastic',
          '# Project-Waddle-Missionslog\n\n'
              'Alle **37 Kaiserpinguine** meldeten sich zur Startprobe.\n\n'
              '- Druckdichtungen: grün\n'
              '- Sardinenfracht: kalt\n'
              '- Futterautomat: verdächtig enthusiastisch',
        ),
      ),
    );

    final sourcePhoto = world.coverImageById(manualLaunchReviewCoverImageId);
    launchPhoto = sourcePhoto.copyWith(
      meta: metadata(
        sourcePhoto.meta.id,
        DateTime(2026, 7, 17, 9, 15),
        labelIds: const [manualDemoProjectLabelId],
      ),
      entryText: EntryText(
        plainText: _t(
          'Mission Control approves the Project Waddle launch corridor.',
          'Die Missionskontrolle genehmigt den Startkorridor für Project Waddle.',
        ),
      ),
    );

    audioMemo = JournalAudio(
      meta: metadata(
        'journal-sardine-cold-chain-voice-memo',
        DateTime(2026, 7, 17, 7, 52),
        duration: const Duration(minutes: 7, seconds: 42),
        categoryId: missionControl.id,
        flag: EntryFlag.import,
      ),
      entryText: EntryText(
        plainText: _t(
          'Voice memo: Europa sardines are colder than the diplomatic '
              'protocol requires.',
          'Sprachnotiz: Die Europa-Sardinen sind kälter, als es das '
              'diplomatische Protokoll verlangt.',
        ),
      ),
      data: AudioData(
        dateFrom: DateTime(2026, 7, 17, 7, 52),
        dateTo: DateTime(2026, 7, 17, 7, 59, 42),
        duration: const Duration(minutes: 7, seconds: 42),
        audioFile: 'europa-cold-chain.m4a',
        audioDirectory: '/manual_demo/',
        language: manualScreenshotLocale.languageCode,
        transcripts: [
          AudioTranscript(
            created: DateTime(2026, 7, 17, 8, 2),
            library: 'Mistral',
            model: 'voxtral-mini-latest',
            detectedLanguage: manualScreenshotLocale.languageCode,
            processingTime: const Duration(seconds: 8),
            transcript: _t(
              'Project Waddle voice memo. Europa sardine cargo is holding '
                  'at minus eighteen degrees. All 37 emperor penguins are '
                  'present. Recalibrate the zero-gravity fish feeder before '
                  'the launch review, and ask Sir Flaps-a-Lot to stop saluting '
                  'the pressure gauge.',
              'Project-Waddle-Sprachnotiz. Die Europa-Sardinenfracht bleibt '
                  'bei minus achtzehn Grad. Alle 37 Kaiserpinguine sind '
                  'anwesend. Kalibriere den Schwerelos-Futterautomaten vor '
                  'der Startprüfung neu und bitte Sir Flaps-a-Lot, die '
                  'Druckanzeige nicht mehr zu salutieren.',
            ),
          ),
          AudioTranscript(
            created: DateTime(2026, 7, 17, 8),
            library: 'Whisper',
            model: 'large-v3-turbo',
            detectedLanguage: manualScreenshotLocale.languageCode,
            processingTime: const Duration(seconds: 12),
            transcript: _t(
              'Europa cold-chain check: sardines stable, emperor penguin '
                  'roll call complete, feeder calibration still pending.',
              'Europa-Kühlkettenprüfung: Sardinen stabil, Kaiserpinguine '
                  'vollzählig, Futterautomat-Kalibrierung noch ausstehend.',
            ),
          ),
        ],
      ),
    );

    final summit = JournalEvent(
      meta: metadata(
        'event-europa-sardine-futures-summit',
        DateTime(2026, 8, 3, 14),
        duration: const Duration(hours: 2),
        categoryId: fishDiplomacy.id,
      ),
      data: EventData(
        title: _t(
          'Europa sardine futures summit',
          'Europa-Sardinen-Futures-Gipfel',
        ),
        status: EventStatus.planned,
        stars: 0,
      ),
      entryText: EntryText(
        plainText: _t(
          'Price discovery, cold-chain diplomacy, and formal fish hats.',
          'Preisfindung, Kühlketten-Diplomatie und formelle Fischhüte.',
        ),
      ),
    );

    final cargoSummary = AiResponseEntry(
      meta: metadata(
        'ai-europa-cargo-telemetry-summary',
        DateTime(2026, 7, 17, 7, 35),
        categoryId: missionControl.id,
      ),
      data: AiResponseData(
        model: _t('Penguin Operations Analyst', 'Pinguinbetriebs-Analyst'),
        systemMessage: '',
        prompt: _t(
          'Summarize the cargo telemetry.',
          'Fasse die Frachttelemetrie zusammen.',
        ),
        thoughts: '',
        response: _t(
          'Cargo telemetry is stable. One pod contains 4% more sardines '
              'than declared, which Mission Control considers excellent news.',
          'Die Frachttelemetrie ist stabil. Eine Kapsel enthält 4 % mehr '
              'Sardinen als angegeben, was die Missionskontrolle für '
              'ausgezeichnete Nachrichten hält.',
        ),
        type: AiResponseType.imageAnalysis,
      ),
    );

    rehearsalTimer = JournalEntry(
      meta: metadata(
        'journal-emperor-roll-call-rehearsal',
        DateTime(2026, 7, 17, 8, 42),
        duration: const Duration(minutes: 23),
        labelIds: const [manualDemoProjectLabelId],
      ),
      entryText: EntryText(
        plainText: _t(
          'Rehearsed the emperor penguin roll call and rerouted one '
              'confused cargo pod.',
          'Den Zählappell der Kaiserpinguine geprobt und eine verwirrte '
              'Frachtkapsel umgeleitet.',
        ),
      ),
    );

    diagnosticPrompt = AiResponseEntry(
      meta: metadata(
        'ai-fish-feeder-diagnostic-prompt',
        DateTime(2026, 7, 17, 9),
      ),
      data: AiResponseData(
        model: _t('Penguin Operations Coder', 'Pinguinbetriebs-Programmierer'),
        systemMessage: '',
        prompt: _t(
          'Prepare a diagnostic prompt.',
          'Erstelle einen Diagnose-Prompt.',
        ),
        thoughts: '',
        response: _t(
          'Prepare a read-only diagnostic for the zero-gravity fish feeder. '
              'Explain any result that points lunch toward Mission Control.',
          'Erstelle eine schreibgeschützte Diagnose für den '
              'Schwerelos-Futterautomaten. Erkläre jedes Ergebnis, das das '
              'Mittagessen in Richtung Missionskontrolle lenkt.',
        ),
        type: AiResponseType.promptGeneration,
        skillId: 'coding-prompt',
      ),
    );

    final feedEntries = <JournalEntity>[
      launchPhoto,
      briefing,
      audioMemo,
      summit,
      cargoSummary,
    ];
    pagingController =
        PagingController<int, JournalEntity>(
            getNextPageKey: (_) => null,
            fetchPage: (_) async => const <JournalEntity>[],
          )
          ..value = PagingState<int, JournalEntity>(
            pages: [feedEntries],
            keys: const [0],
            hasNextPage: false,
          );
    pageState = JournalPageState(
      pagingController: pagingController,
      selectedEntryTypes: entryTypes,
      showPrivateEntries: true,
      enableVectorSearch: true,
    );

    links = [
      EntryLink.basic(
        id: 'link-briefing-photo',
        fromId: briefing.id,
        toId: launchPhoto.id,
        createdAt: launchPhoto.meta.dateFrom,
        updatedAt: launchPhoto.meta.dateFrom,
        vectorClock: null,
      ),
      EntryLink.basic(
        id: 'link-briefing-diagnostic',
        fromId: briefing.id,
        toId: diagnosticPrompt.id,
        createdAt: diagnosticPrompt.meta.dateFrom,
        updatedAt: diagnosticPrompt.meta.dateFrom,
        vectorClock: null,
      ),
      EntryLink.basic(
        id: 'link-briefing-rehearsal',
        fromId: briefing.id,
        toId: rehearsalTimer.id,
        createdAt: rehearsalTimer.meta.dateFrom,
        updatedAt: rehearsalTimer.meta.dateFrom,
        vectorClock: null,
      ),
    ];

    final entitiesCache = MockEntitiesCacheService();
    final userActivity = MockUserActivityService();
    final timeService = MockTimeService();
    final navService = MockNavService();
    ratingRepository = MockRatingRepository();

    final sessionRating = RatingEntry(
      meta: Metadata(
        id: 'rating-emperor-roll-call-rehearsal',
        createdAt: DateTime(2026, 7, 17, 9, 6),
        updatedAt: DateTime(2026, 7, 17, 9, 6),
        dateFrom: DateTime(2026, 7, 17, 9, 6),
        dateTo: DateTime(2026, 7, 17, 9, 6),
      ),
      data: RatingData(
        targetId: rehearsalTimer.id,
        dimensions: const [
          RatingDimension(key: 'productivity', value: 0.8),
          RatingDimension(key: 'energy', value: 0.6),
          RatingDimension(key: 'focus', value: 0.9),
          RatingDimension(key: 'challenge_skill', value: 0.5),
        ],
        note: _t(
          'Mission Control briefing stayed focused despite one airborne sardine.',
          'Das Briefing der Missionskontrolle blieb trotz einer fliegenden '
              'Sardine fokussiert.',
        ),
      ),
    );

    when(userActivity.updateActivity).thenReturn(null);
    when(timeService.getStream).thenAnswer((_) => const Stream.empty());
    when(timeService.getCurrent).thenReturn(null);
    when(() => entitiesCache.sortedCategories).thenReturn(categories);
    when(() => entitiesCache.showPrivateEntries).thenReturn(true);
    when(() => entitiesCache.getCategoryById(any())).thenAnswer((invocation) {
      final id = invocation.positionalArguments.first as String?;
      return categories.where((category) => category.id == id).firstOrNull;
    });
    when(() => entitiesCache.getLabelById(any())).thenAnswer((invocation) {
      final id = invocation.positionalArguments.first as String?;
      return world.labels.where((label) => label.id == id).firstOrNull;
    });
    when(
      () => navService.beamToNamed(any(), data: any(named: 'data')),
    ).thenReturn(null);
    when(
      () => ratingRepository.getRatingForTargetEntry(rehearsalTimer.id),
    ).thenAnswer((_) async => sessionRating);

    final mocks = await setUpTestGetIt(
      additionalSetup: () {
        getIt
          ..registerSingleton<Directory>(documentsDirectory)
          ..registerSingleton<EditorStateService>(MockEditorStateService())
          ..registerSingleton<EntitiesCacheService>(entitiesCache)
          ..registerSingleton<UserActivityService>(userActivity)
          ..registerSingleton<TimeService>(timeService)
          ..registerSingleton<NavService>(navService);
      },
    );
    when(
      () => mocks.journalDb.watchConfigFlag(any()),
    ).thenAnswer((_) => Stream.value(true));
  });

  tearDown(() async {
    pagingController.dispose();
    await tearDownTestGetIt();
    await documentsDirectory.delete(recursive: true);
  });

  List<Override> overrides() => [
    journalPageControllerProvider(false).overrideWith(
      () => _ManualJournalPageController(pageState),
    ),
    labelsStreamProvider.overrideWith((ref) => Stream.value(world.labels)),
    configFlagProvider(
      enableEventsFlag,
    ).overrideWith((ref) => Stream.value(true)),
    entryControllerProvider(briefing.id).overrideWith(
      () => _ManualEntryController(briefing),
    ),
    entryControllerProvider(launchPhoto.id).overrideWith(
      () => _ManualEntryController(launchPhoto),
    ),
    entryControllerProvider(audioMemo.id).overrideWith(
      () => _ManualEntryController(audioMemo),
    ),
    entryControllerProvider(rehearsalTimer.id).overrideWith(
      () => _ManualEntryController(rehearsalTimer),
    ),
    entryControllerProvider(diagnosticPrompt.id).overrideWith(
      () => _ManualEntryController(diagnosticPrompt),
    ),
    linkedEntriesControllerProvider(briefing.id).overrideWith(
      () => MockLinkedEntriesController(links, briefing.id),
    ),
    linkedFromEntriesControllerProvider(briefing.id).overrideWith(
      () => MockLinkedFromEntriesController([
        world.taskById(manualLaunchReviewTaskId),
      ]),
    ),
    linkedEntriesControllerProvider(audioMemo.id).overrideWith(
      () => MockLinkedEntriesController(const [], audioMemo.id),
    ),
    linkedFromEntriesControllerProvider(audioMemo.id).overrideWith(
      () => MockLinkedFromEntriesController(const []),
    ),
    linkedEntriesControllerProvider(rehearsalTimer.id).overrideWith(
      () => MockLinkedEntriesController(const [], rehearsalTimer.id),
    ),
    linkedFromEntriesControllerProvider(rehearsalTimer.id).overrideWith(
      () => MockLinkedFromEntriesController(const []),
    ),
    ratingRepositoryProvider.overrideWithValue(ratingRepository),
  ];

  Future<void> pumpSurface(
    WidgetTester tester, {
    required ScreenshotDevice device,
    required Brightness brightness,
    required Widget home,
  }) async {
    applyScreenshotDevice(tester, device);
    final platform = device.isPhone
        ? TargetPlatform.android
        : TargetPlatform.linux;
    await withTargetPlatform(platform, () async {
      await withClock(Clock.fixed(manualDemoNow), () async {
        await tester.pumpWidget(
          _app(
            home: const SizedBox(key: ValueKey('journal-precache-host')),
            brightness: brightness,
            device: device,
            overrides: overrides(),
            platform: platform,
          ),
        );
        final context = tester.element(
          find.byKey(const ValueKey('journal-precache-host')),
        );
        final file = File(
          getFullImagePath(
            launchPhoto,
            documentsDirectory: documentsDirectory.path,
          ),
        );
        await tester.runAsync(() async {
          await precacheImage(
            ResizeImage(
              FileImage(file),
              width: 104,
              height: 104,
              policy: ResizeImagePolicy.fit,
            ),
            context,
          );
          await precacheImage(
            ResizeImage(
              FileImage(file),
              width: device.size.width.round(),
              height: (device.isPhone ? 400 : device.size.width).round(),
              policy: ResizeImagePolicy.fit,
            ),
            context,
          );
        });
        await tester.pumpWidget(
          _app(
            home: home,
            brightness: brightness,
            device: device,
            overrides: overrides(),
            platform: platform,
          ),
        );
        await settleFrames(tester, 12);
      });
    });
  }

  for (final device in [proDevice, desktopDevice]) {
    final viewport = device.isPhone ? 'mobile' : 'desktop';
    for (final brightness in [Brightness.light, Brightness.dark]) {
      final theme = brightness.name;

      testWidgets('$viewport journal overview — $theme', (tester) async {
        await pumpSurface(
          tester,
          device: device,
          brightness: brightness,
          home: const InfiniteJournalPage(),
        );
        expect(find.byType(CardWrapperWidget), findsNWidgets(5));
        expect(
          find.text(
            _t(
              'Mission Control approves the Project Waddle launch corridor.',
              'Die Missionskontrolle genehmigt den Startkorridor für '
                  'Project Waddle.',
            ),
          ),
          findsOneWidget,
        );
        expect(
          find.textContaining(
            _t('Project Waddle mission log', 'Project-Waddle-Missionslog'),
          ),
          findsOneWidget,
        );
        await captureScreenshot(
          tester,
          'journal_overview_${viewport}_$theme',
          subdir: _subdir,
        );
      });

      testWidgets('$viewport journal filters — $theme', (tester) async {
        await pumpSurface(
          tester,
          device: device,
          brightness: brightness,
          home: const InfiniteJournalPage(),
        );
        await tester.tap(
          find.descendant(
            of: find.byType(JournalFilterIcon),
            matching: find.byType(IconButton),
          ),
        );
        await settleFrames(tester, 6);
        expect(
          find.text(_t('Filter journal', 'Tagebuch filtern')),
          findsOneWidget,
        );
        expect(
          find.text(_t('Entry types', 'Eintragstypen')),
          findsOneWidget,
        );
        expect(find.text(_t('Category', 'Kategorie')), findsWidgets);
        await captureScreenshot(
          tester,
          'journal_filters_${viewport}_$theme',
          subdir: _subdir,
        );
      });

      testWidgets('$viewport journal create menu — $theme', (tester) async {
        await pumpSurface(
          tester,
          device: device,
          brightness: brightness,
          home: const InfiniteJournalPage(),
        );
        await tester.tap(find.byType(DesignSystemFloatingActionButton));
        await settleFrames(tester, 6);
        expect(find.text(_t('Add', 'Hinzufügen')), findsOneWidget);
        expect(find.text(_t('Event', 'Ereignis')), findsOneWidget);
        expect(find.text(_t('Task', 'Aufgabe')), findsOneWidget);
        expect(
          find.text(_t('Audio Recording', 'Audioaufnahme')),
          findsOneWidget,
        );
        expect(find.text(_t('Text Entry', 'Texteingabe')), findsOneWidget);
        await captureScreenshot(
          tester,
          'journal_create_${viewport}_$theme',
          subdir: _subdir,
        );
      });

      testWidgets('$viewport journal detail — $theme', (tester) async {
        await pumpSurface(
          tester,
          device: device,
          brightness: brightness,
          home: const EntryDetailsPage(itemId: _briefingId),
        );
        final editors = tester.widgetList<QuillEditor>(
          find.byType(QuillEditor),
        );
        expect(
          editors.any(
            (editor) => editor.controller.document.toPlainText().contains(
              _t('Project Waddle mission log', 'Project-Waddle-Missionslog'),
            ),
          ),
          isTrue,
        );
        expect(find.text('Project Waddle'), findsWidgets);
        expect(
          find.text(_t('Habitat critical', 'Habitat kritisch')),
          findsWidgets,
        );
        final image = find.descendant(
          of: find.byType(EntryImageWidget),
          matching: find.byType(RawImage),
        );
        expect(image, findsOneWidget);
        if (!device.isPhone) {
          expect(tester.renderObject<RenderImage>(image).image, isNotNull);
        }
        await captureScreenshot(
          tester,
          'journal_detail_${viewport}_$theme',
          subdir: _subdir,
        );
      });

      testWidgets('$viewport journal date and time — $theme', (tester) async {
        await pumpSurface(
          tester,
          device: device,
          brightness: brightness,
          home: const EntryDetailsPage(itemId: _briefingId),
        );
        final dateTimeTrigger = find.byType(EntryDatetimeWidget).first;
        expect(dateTimeTrigger, findsOneWidget);
        await tester.tap(dateTimeTrigger);
        await settleFrames(tester, 8);

        expect(find.byType(EntryDateTimeEditor), findsOneWidget);
        expect(
          find.text(_t('Date & Time', 'Datum & Uhrzeit')),
          findsOneWidget,
        );
        expect(find.text(_t('Start time', 'Startzeit')), findsOneWidget);
        expect(find.text(_t('End time', 'Endzeit')), findsOneWidget);
        await captureScreenshot(
          tester,
          'journal_date_time_editor_${viewport}_$theme',
          subdir: _subdir,
        );

        await tester.tap(
          find
              .text(
                _t(
                  'Friday, July 17, 2026',
                  'Freitag, 17. Juli 2026',
                ),
              )
              .first,
        );
        await settleFrames(tester, 8);
        expect(find.text(_t('Start date', 'Startdatum')), findsOneWidget);
        expect(find.text(_t('July 2026', 'Juli 2026')), findsOneWidget);
        await captureScreenshot(
          tester,
          'journal_date_picker_${viewport}_$theme',
          subdir: _subdir,
        );
      });

      testWidgets('$viewport journal linked activity — $theme', (tester) async {
        await pumpSurface(
          tester,
          device: device,
          brightness: brightness,
          home: const EntryDetailsPage(itemId: _briefingId),
        );
        final page = find.byType(EntryDetailsPage);
        final scrollable = find.descendant(
          of: page,
          matching: find.byType(Scrollable),
        );
        await tester.scrollUntilVisible(
          find.textContaining(
            _t(
              'Prepare a read-only diagnostic',
              'Erstelle eine schreibgeschützte Diagnose',
            ),
          ),
          360,
          scrollable: scrollable.first,
        );
        await settleFrames(tester, 4);
        expect(find.text('Timer'), findsOneWidget);
        expect(find.text(_t('Images', 'Bilder')), findsOneWidget);
        expect(find.text('Code'), findsOneWidget);
        expect(
          find.textContaining(
            _t(
              'Prepare a read-only diagnostic',
              'Erstelle eine schreibgeschützte Diagnose',
            ),
          ),
          findsOneWidget,
        );
        await captureScreenshot(
          tester,
          'journal_activity_${viewport}_$theme',
          subdir: _subdir,
        );
      });

      testWidgets('$viewport journal linked filter — $theme', (tester) async {
        await pumpSurface(
          tester,
          device: device,
          brightness: brightness,
          home: const EntryDetailsPage(itemId: _briefingId),
        );
        final page = find.byType(EntryDetailsPage);
        final scrollable = find.descendant(
          of: page,
          matching: find.byType(Scrollable),
        );
        final filterTrigger = find.byKey(
          const ValueKey('linked-entries-sort-trigger-visual'),
        );
        await tester.scrollUntilVisible(
          filterTrigger,
          360,
          scrollable: scrollable.first,
        );
        await settleFrames(tester, 4);
        expect(find.byType(LinkedEntriesActivityFilterBar), findsOneWidget);
        await tester.tap(filterTrigger);
        await settleFrames(tester, 6);

        expect(
          find.text(_t('Filter & Sort', 'Filtern & Sortieren')),
          findsOneWidget,
        );
        expect(
          find.text(_t('Newest first', 'Neueste zuerst')),
          findsWidgets,
        );
        expect(
          find.text(_t('Oldest first', 'Älteste zuerst')),
          findsOneWidget,
        );
        await tester.tap(find.text(_t('Oldest first', 'Älteste zuerst')));
        await tester.tap(
          find.text(
            _t('Show hidden entries', 'Versteckte Einträge anzeigen'),
          ),
        );
        await settleFrames(tester, 3);
        await captureScreenshot(
          tester,
          'journal_linked_filter_${viewport}_$theme',
          subdir: _subdir,
        );
      });

      testWidgets('$viewport recording transcript review — $theme', (
        tester,
      ) async {
        await pumpSurface(
          tester,
          device: device,
          brightness: brightness,
          home: EntryDetailsPage(itemId: audioMemo.id),
        );
        expect(find.text('00:00 / 07:42'), findsOneWidget);

        final pageContext = tester.element(find.byType(EntryDetailsPage));
        final providerContainer = ProviderScope.containerOf(pageContext);
        unawaited(
          ModalUtils.showMultiPageModal<void>(
            context: pageContext,
            pageListBuilder: (modalContext) => [
              // This is the exact production transcript page from
              // ExtendedHeaderModal. The shared provider container keeps the
              // root-navigator overlay attached to this deterministic entry.
              ModalUtils.modalSheetPage(
                context: modalContext,
                padding: const EdgeInsets.only(bottom: 20),
                title: pageContext.messages.speechModalTitle,
                child: UncontrolledProviderScope(
                  container: providerContainer,
                  child: SpeechModalContent(entryId: audioMemo.id),
                ),
                onTapBack: () => Navigator.of(modalContext).pop(),
              ),
            ],
          ),
        );
        await settleFrames(tester, 6);

        expect(find.byType(SpeechModalContent), findsOneWidget);
        expect(find.byType(TranscriptListItem), findsNWidgets(2));
        expect(
          find.text('Model: Mistral, voxtral-mini-latest'),
          findsOneWidget,
        );
        await captureScreenshot(
          tester,
          'recording_transcripts_${viewport}_$theme',
          subdir: _subdir,
        );

        await tester.tap(
          find.byIcon(Icons.keyboard_double_arrow_down_outlined).first,
        );
        await settleFrames(tester, 4);
        expect(
          find.textContaining(
            _t('All 37 emperor penguins', 'Alle 37 Kaiserpinguine'),
          ),
          findsOneWidget,
        );
        await captureScreenshot(
          tester,
          'recording_transcript_expanded_${viewport}_$theme',
          subdir: _subdir,
        );
      });

      testWidgets('$viewport session rating — $theme', (tester) async {
        await pumpSurface(
          tester,
          device: device,
          brightness: brightness,
          home: EntryDetailsPage(itemId: rehearsalTimer.id),
        );

        final pageContext = tester.element(find.byType(EntryDetailsPage));
        unawaited(RatingModal.show(pageContext, rehearsalTimer.id));
        await settleFrames(tester, 8);

        expect(find.byType(RatingModal), findsOneWidget);
        expect(
          find.text(_t('Rate this session', 'Sitzung bewerten')),
          findsOneWidget,
        );
        expect(
          find.text(
            _t(
              'How productive was this session?',
              'Wie produktiv war diese Sitzung?',
            ),
          ),
          findsOneWidget,
        );
        expect(
          find.text(
            _t(
              'How energized did you feel?',
              'Wie energiegeladen hast du dich gefühlt?',
            ),
          ),
          findsOneWidget,
        );
        expect(
          find.text(
            _t(
              'How focused were you?',
              'Wie fokussiert warst du?',
            ),
          ),
          findsOneWidget,
        );
        expect(
          find.text(_t('Just right', 'Genau richtig')),
          findsOneWidget,
        );
        expect(
          find.text(
            _t(
              'Mission Control briefing stayed focused despite one airborne sardine.',
              'Das Briefing der Missionskontrolle blieb trotz einer fliegenden '
                  'Sardine fokussiert.',
            ),
          ),
          findsOneWidget,
        );
        final saveButton = tester.widget<FilledButton>(
          find.widgetWithText(FilledButton, _t('Save', 'Speichern')),
        );
        expect(saveButton.onPressed, isNotNull);

        await captureScreenshot(
          tester,
          'session_rating_${viewport}_$theme',
          subdir: _subdir,
        );
      });
    }
  }
}
