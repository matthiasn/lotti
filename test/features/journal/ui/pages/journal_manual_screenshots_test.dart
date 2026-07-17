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
import 'package:lotti/features/journal/ui/widgets/entry_image_widget.dart';
import 'package:lotti/features/journal/ui/widgets/list_cards/card_wrapper_widget.dart';
import 'package:lotti/features/journal/utils/entry_types.dart';
import 'package:lotti/features/keyboard/ui/app_command_host.dart';
import 'package:lotti/features/labels/state/labels_list_controller.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/services/editor_state_service.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/services/time_service.dart';
import 'package:lotti/utils/consts.dart';
import 'package:lotti/utils/image_utils.dart';
import 'package:lotti/widgets/app_bar/journal_sliver_appbar.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/fake_entry_controller.dart';
import '../../../../helpers/manual_demo_world.dart';
import '../../../../helpers/target_platform.dart';
import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';
import '../../../categories/test_utils.dart';
import '../../../daily_os_next/screenshot_harness.dart';

const _subdir = 'journal';
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
          locale: const Locale('en'),
          theme: screenshotTheme,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
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
  late JournalEntry rehearsalTimer;
  late AiResponseEntry diagnosticPrompt;
  late List<EntryLink> links;
  late List<CategoryDefinition> categories;

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
      name: 'Mission Control',
      color: '#6750A4',
    );
    final fishDiplomacy = CategoryTestUtils.createTestCategory(
      id: 'manual-fish-diplomacy',
      name: 'Fish Diplomacy',
      color: '#FBA337',
    );
    final humanMaintenance = CategoryTestUtils.createTestCategory(
      id: 'manual-human-maintenance',
      name: 'Human Maintenance',
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
      entryText: const EntryText(
        plainText:
            'Project Waddle mission log — pressure seals green, 37 emperor '
            'penguins present, and the sardine cargo is cold.',
        markdown:
            '# Project Waddle mission log\n\n'
            'All **37 emperor penguins** reported for launch rehearsal.\n\n'
            '- Pressure seals: green\n'
            '- Sardine cargo: cold\n'
            '- Fish feeder: suspiciously enthusiastic',
      ),
    );

    final sourcePhoto = world.coverImageById(manualLaunchReviewCoverImageId);
    launchPhoto = sourcePhoto.copyWith(
      meta: metadata(
        sourcePhoto.meta.id,
        DateTime(2026, 7, 17, 9, 15),
        labelIds: const [manualDemoProjectLabelId],
      ),
      entryText: const EntryText(
        plainText:
            'Mission Control approves the Project Waddle launch corridor.',
      ),
    );

    final audioMemo = JournalAudio(
      meta: metadata(
        'journal-sardine-cold-chain-voice-memo',
        DateTime(2026, 7, 17, 7, 52),
        duration: const Duration(minutes: 7, seconds: 42),
        categoryId: missionControl.id,
        flag: EntryFlag.import,
      ),
      entryText: const EntryText(
        plainText:
            'Voice memo: Europa sardines are colder than the diplomatic '
            'protocol requires.',
      ),
      data: AudioData(
        dateFrom: DateTime(2026, 7, 17, 7, 52),
        dateTo: DateTime(2026, 7, 17, 7, 59, 42),
        duration: const Duration(minutes: 7, seconds: 42),
        audioFile: 'europa-cold-chain.m4a',
        audioDirectory: '/manual_demo/',
        language: 'en',
      ),
    );

    final summit = JournalEvent(
      meta: metadata(
        'event-europa-sardine-futures-summit',
        DateTime(2026, 8, 3, 14),
        duration: const Duration(hours: 2),
        categoryId: fishDiplomacy.id,
      ),
      data: const EventData(
        title: 'Europa sardine futures summit',
        status: EventStatus.planned,
        stars: 0,
      ),
      entryText: const EntryText(
        plainText:
            'Price discovery, cold-chain diplomacy, and formal fish hats.',
      ),
    );

    final cargoSummary = AiResponseEntry(
      meta: metadata(
        'ai-europa-cargo-telemetry-summary',
        DateTime(2026, 7, 17, 7, 35),
        categoryId: missionControl.id,
      ),
      data: const AiResponseData(
        model: 'Penguin Operations Analyst',
        systemMessage: '',
        prompt: 'Summarize the cargo telemetry.',
        thoughts: '',
        response:
            'Cargo telemetry is stable. One pod contains 4% more sardines '
            'than declared, which Mission Control considers excellent news.',
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
      entryText: const EntryText(
        plainText:
            'Rehearsed the emperor penguin roll call and rerouted one '
            'confused cargo pod.',
      ),
    );

    diagnosticPrompt = AiResponseEntry(
      meta: metadata(
        'ai-fish-feeder-diagnostic-prompt',
        DateTime(2026, 7, 17, 9),
      ),
      data: const AiResponseData(
        model: 'Penguin Operations Coder',
        systemMessage: '',
        prompt: 'Prepare a diagnostic prompt.',
        thoughts: '',
        response:
            'Prepare a read-only diagnostic for the zero-gravity fish feeder. '
            'Explain any result that points lunch toward Mission Control.',
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
            'Mission Control approves the Project Waddle launch corridor.',
          ),
          findsOneWidget,
        );
        expect(
          find.textContaining('Project Waddle mission log'),
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
        expect(find.text('Filter journal'), findsOneWidget);
        expect(find.text('Entry types'), findsOneWidget);
        expect(find.text('Category'), findsWidgets);
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
        expect(find.text('Add'), findsOneWidget);
        expect(find.text('Event'), findsOneWidget);
        expect(find.text('Task'), findsOneWidget);
        expect(find.text('Audio Recording'), findsOneWidget);
        expect(find.text('Text Entry'), findsOneWidget);
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
              'Project Waddle mission log',
            ),
          ),
          isTrue,
        );
        expect(find.text('Project Waddle'), findsWidgets);
        expect(find.text('Habitat critical'), findsWidgets);
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
          find.textContaining('Prepare a read-only diagnostic'),
          360,
          scrollable: scrollable.first,
        );
        await settleFrames(tester, 4);
        expect(find.text('Timer'), findsOneWidget);
        expect(find.text('Images'), findsOneWidget);
        expect(find.text('Code'), findsOneWidget);
        expect(
          find.textContaining('Prepare a read-only diagnostic'),
          findsOneWidget,
        );
        await captureScreenshot(
          tester,
          'journal_activity_${viewport}_$theme',
          subdir: _subdir,
        );
      });
    }
  }
}
