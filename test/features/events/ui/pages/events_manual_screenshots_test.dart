/// Deterministic manual screenshots for the production Events surfaces.
///
/// The fixtures reuse the Intergalactic Penguin Logistics artwork and extend
/// the shared world with upcoming and completed expedition events, a photo
/// timeline, operational notes, and linked tasks. Captures render
/// [EventsOverviewPage] and [EventDetailPage] directly; no Widgetbook or
/// showcase host is involved.
///
/// Opt in with an external output directory:
/// `LOTTI_SCREENSHOT_DIR=/tmp/events fvm flutter test \
///   test/features/events/ui/pages/events_manual_screenshots_test.dart`
library;

import 'dart:io';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/event_data.dart';
import 'package:lotti/classes/event_status.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/agents/state/event_agent_providers.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/events/state/events_controller.dart';
import 'package:lotti/features/events/state/events_overview_controller.dart';
import 'package:lotti/features/events/ui/pages/event_detail_page.dart';
import 'package:lotti/features/events/ui/pages/events_overview_page.dart';
import 'package:lotti/features/events/ui/widgets/event_detail_view.dart';
import 'package:lotti/features/events/ui/widgets/event_photo_gallery.dart';
import 'package:lotti/features/events/ui/widgets/events_overview_view.dart';
import 'package:lotti/features/journal/state/linked_entries_controller.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/services/editor_state_service.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/utils/image_utils.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/fake_entry_controller.dart';
import '../../../../helpers/manual_demo_world.dart';
import '../../../../helpers/target_platform.dart';
import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';
import '../../../categories/test_utils.dart';
import '../../../daily_os_next/screenshot_harness.dart';

const _subdir = 'events';
const _detailEventId = 'event-project-waddle-launch-gala';
String _t(String en, String de) => manualScreenshotText(en: en, de: de);
const ValueKey<String> _precacheKey = ValueKey<String>(
  'events-manual-precache-host',
);

class _ManualEventsOverviewController extends EventsOverviewController {
  _ManualEventsOverviewController(this._events);

  final List<ResolvedEvent> _events;

  EventsOverviewState _snapshot(String? categoryId) => EventsOverviewState(
    events: categoryId == null
        ? _events
        : _events
              .where((event) => event.event.meta.categoryId == categoryId)
              .toList(),
    hasMore: false,
    categoryId: categoryId,
  );

  @override
  Future<EventsOverviewState> build() async => _snapshot(null);

  @override
  Future<void> setCategory(String? categoryId) async {
    state = AsyncData(_snapshot(categoryId));
  }
}

Widget _app({
  required Widget home,
  required Brightness brightness,
  required ScreenshotDevice device,
  required List<Override> overrides,
}) {
  return RepaintBoundary(
    key: screenshotBoundaryKey,
    child: ProviderScope(
      overrides: overrides,
      child: MediaQuery(
        data: MediaQueryData(
          size: device.size,
          disableAnimations: true,
        ),
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: brightness == Brightness.dark
              ? DesignSystemTheme.dark()
              : DesignSystemTheme.light(),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          locale: manualScreenshotLocale,
          home: home,
        ),
      ),
    ),
  );
}

void main() {
  if (!screenshotCaptureEnabled) {
    test(
      'events manual screenshot harness (opt-in)',
      () {},
      skip: 'Set LOTTI_SCREENSHOT_DIR to capture manual screenshots.',
    );
    return;
  }

  setUpAll(loadScreenshotFonts);

  late ManualDemoWorld world;
  late Directory documentsDirectory;
  late List<CategoryDefinition> categories;
  late List<ResolvedEvent> overviewEvents;
  late JournalEvent detailEvent;
  late List<JournalEntity> detailLinkedEntries;

  setUp(() async {
    world = ManualDemoWorld.penguinLogistics();
    documentsDirectory = await Directory.systemTemp.createTemp(
      'lotti-manual-events-',
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

    JournalEvent event({
      required String id,
      required String title,
      required DateTime date,
      required EventStatus status,
      required CategoryDefinition category,
      required String coverArtId,
      required String summary,
      double stars = 0,
    }) => JournalEvent(
      meta: Metadata(
        id: id,
        createdAt: date,
        updatedAt: date,
        dateFrom: date,
        dateTo: date.add(const Duration(hours: 2)),
        categoryId: category.id,
      ),
      data: EventData(
        title: title,
        stars: stars,
        status: status,
        coverArtId: coverArtId,
      ),
      entryText: EntryText(plainText: summary),
    );

    detailEvent = event(
      id: _detailEventId,
      title: _t('Project Waddle launch gala', 'Project-Waddle-Startgala'),
      date: DateTime(2026, 7, 16, 18, 30),
      status: EventStatus.completed,
      category: world.category,
      coverArtId: manualLaunchReviewCoverImageId,
      stars: 5,
      summary: _t(
        'The habitat passed inspection, all 37 emperor penguins saluted in '
            'roughly the same direction, and the sardine cargo arrived cold.',
        'Das Habitat bestand die Inspektion, alle 37 Kaiserpinguine salutierten '
            'grob in dieselbe Richtung und die Sardinenfracht kam kalt an.',
      ),
    );

    final sardineSummit = event(
      id: 'event-europa-sardine-futures-summit',
      title: _t(
        'Europa sardine futures summit',
        'Europa-Sardinen-Futures-Gipfel',
      ),
      date: DateTime(2026, 8, 3, 14),
      status: EventStatus.planned,
      category: fishDiplomacy,
      coverArtId: manualSardineFuturesCoverImageId,
      summary: _t(
        'Price discovery, cold-chain diplomacy, and formal fish hats.',
        'Preisfindung, Kühlketten-Diplomatie und formelle Fischhüte.',
      ),
    );
    final rollCallGala = event(
      id: 'event-emperor-penguin-roll-call',
      title: _t(
        'Emperor penguin roll-call gala',
        'Kaiserpinguin-Zählappell-Gala',
      ),
      date: DateTime(2026, 7, 12, 17),
      status: EventStatus.completed,
      category: world.category,
      coverArtId: manualRollCallCoverImageId,
      summary: _t(
        'Every penguin was present; two attended twice.',
        'Jeder Pinguin war anwesend; zwei nahmen doppelt teil.',
      ),
      stars: 5,
    );
    final cargoOpening = event(
      id: 'event-europa-cold-chain-opening',
      title: _t(
        'Europa cold-chain grand opening',
        'Eröffnung der Europa-Kühlkette',
      ),
      date: DateTime(2025, 11, 8, 10),
      status: EventStatus.completed,
      category: missionControl,
      coverArtId: manualSardineCargoCoverImageId,
      summary: _t(
        'The ribbon froze before anyone could cut it.',
        'Das Band fror ein, bevor es jemand durchschneiden konnte.',
      ),
      stars: 4,
    );
    final iceGardenOpening = event(
      id: 'event-orbital-ice-garden-opening',
      title: _t(
        'Orbital ice-garden opening',
        'Eröffnung des Orbital-Eisgartens',
      ),
      date: DateTime(2024, 12, 2, 16),
      status: EventStatus.completed,
      category: humanMaintenance,
      coverArtId: manualHeadsetWalkCoverImageId,
      summary: _t(
        'One quiet lap, zero status meetings.',
        'Eine stille Runde, null Statusbesprechungen.',
      ),
      stars: 5,
    );

    FileImage coverProvider(String coverArtId) {
      final image = world.coverImageById(coverArtId);
      return FileImage(
        File(
          getFullImagePath(
            image,
            documentsDirectory: documentsDirectory.path,
          ),
        ),
      );
    }

    ResolvedEvent resolved(
      JournalEvent value,
      CategoryDefinition category,
    ) => ResolvedEvent(
      event: value,
      categoryColor: Color(
        int.parse(category.color!.substring(1), radix: 16) + 0xFF000000,
      ),
      categoryName: category.name,
      coverImage: coverProvider(value.data.coverArtId!),
    );

    overviewEvents = [
      resolved(sardineSummit, fishDiplomacy),
      resolved(detailEvent, world.category),
      resolved(rollCallGala, world.category),
      resolved(cargoOpening, missionControl),
      resolved(iceGardenOpening, humanMaintenance),
    ];

    JournalImage linkedPhoto(
      String imageId,
      DateTime capturedAt,
      String caption,
    ) {
      final source = world.coverImageById(imageId);
      return source.copyWith(
        meta: source.meta.copyWith(
          createdAt: capturedAt,
          updatedAt: capturedAt,
          dateFrom: capturedAt,
          dateTo: capturedAt,
          categoryId: world.category.id,
        ),
        entryText: EntryText(plainText: caption),
      );
    }

    detailLinkedEntries = [
      linkedPhoto(
        manualLaunchReviewCoverImageId,
        DateTime(2026, 7, 16, 18, 35),
        _t(
          'Mission Control declares the ice-pad trajectory officially waddly.',
          'Die Missionskontrolle erklärt die Eisplattform-Flugbahn offiziell '
              'für watschelig.',
        ),
      ),
      JournalEntry(
        meta: Metadata(
          id: 'event-note-pressure-seals',
          createdAt: DateTime(2026, 7, 16, 18, 50),
          updatedAt: DateTime(2026, 7, 16, 18, 50),
          dateFrom: DateTime(2026, 7, 16, 18, 50),
          dateTo: DateTime(2026, 7, 16, 18, 50),
          categoryId: world.category.id,
        ),
        entryText: EntryText(
          plainText: _t(
            'Pressure seals green. Tiny oxygen packs counted twice.',
            'Druckdichtungen grün. Winzige Sauerstoffpakete doppelt gezählt.',
          ),
        ),
      ),
      linkedPhoto(
        manualHabitatCoverImageId,
        DateTime(2026, 7, 16, 19, 5),
        _t(
          'The orbital habitat, five minutes before the ceremonial sardines.',
          'Das Orbital-Habitat, fünf Minuten vor den Zeremonialsardinen.',
        ),
      ),
      linkedPhoto(
        manualSardineCargoCoverImageId,
        DateTime(2026, 7, 16, 19, 20),
        _t(
          'Europa cargo pods arrive at a crisp and diplomatic temperature.',
          'Europa-Frachtkapseln kommen bei knackig-diplomatischer Temperatur an.',
        ),
      ),
      world.fishFeederTask,
      world.sardineCargoTask,
    ];

    final cache = MockEntitiesCacheService();
    when(() => cache.sortedCategories).thenReturn(categories);
    when(() => cache.getCategoryById(any())).thenAnswer((invocation) {
      final id = invocation.positionalArguments.first as String?;
      return categories.where((category) => category.id == id).firstOrNull;
    });

    await setUpTestGetIt(
      additionalSetup: () {
        getIt
          ..registerSingleton<Directory>(documentsDirectory)
          ..registerSingleton<EditorStateService>(MockEditorStateService())
          ..registerSingleton<EntitiesCacheService>(cache);
      },
    );
  });

  tearDown(() async {
    await tearDownTestGetIt();
    await documentsDirectory.delete(recursive: true);
  });

  List<Override> overviewOverrides() => [
    eventsOverviewControllerProvider.overrideWith(
      () => _ManualEventsOverviewController(overviewEvents),
    ),
  ];

  List<Override> detailOverrides() => [
    entryControllerProvider(
      _detailEventId,
    ).overrideWith(() => FakeEntryController(detailEvent)),
    resolvedOutgoingLinkedEntriesProvider(
      _detailEventId,
    ).overrideWithValue(detailLinkedEntries),
    eventAgentProvider(_detailEventId).overrideWith((ref) async => null),
  ];

  Future<void> pumpSurface(
    WidgetTester tester, {
    required ScreenshotDevice device,
    required Brightness brightness,
    required Widget home,
    required List<Override> overrides,
  }) async {
    applyScreenshotDevice(tester, device);
    await primeManualDemoCoverArt(
      tester,
      documentsDirectory: documentsDirectory,
      world: world,
      extents: const [360],
    );
    final platform = device.isPhone
        ? TargetPlatform.android
        : TargetPlatform.linux;
    await withTargetPlatform(platform, () async {
      await withClock(Clock.fixed(manualDemoNow), () async {
        await tester.pumpWidget(
          _app(
            home: const SizedBox(key: _precacheKey),
            brightness: brightness,
            device: device,
            overrides: overrides,
          ),
        );
        final context = tester.element(find.byKey(_precacheKey));
        final decodeWidth = device.size.width.round();
        await tester.runAsync(() async {
          for (final coverImage in world.coverImages) {
            final file = File(
              getFullImagePath(
                coverImage,
                documentsDirectory: documentsDirectory.path,
              ),
            );
            await precacheImage(
              ResizeImage(
                FileImage(file),
                width: decodeWidth,
                policy: ResizeImagePolicy.fit,
              ),
              context,
            );
          }
        });
        await tester.pumpWidget(
          _app(
            home: home,
            brightness: brightness,
            device: device,
            overrides: overrides,
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

      testWidgets('$viewport events overview — $theme', (tester) async {
        await pumpSurface(
          tester,
          device: device,
          brightness: brightness,
          home: const EventsOverviewPage(),
          overrides: overviewOverrides(),
        );
        expect(find.byType(EventsOverviewView), findsOneWidget);
        expect(
          find.text(
            _t(
              'Europa sardine futures summit',
              'Europa-Sardinen-Futures-Gipfel',
            ),
          ),
          findsOneWidget,
        );
        expect(
          find.text(
            _t('Project Waddle launch gala', 'Project-Waddle-Startgala'),
          ),
          findsOneWidget,
        );
        await captureScreenshot(
          tester,
          'events_overview_${viewport}_$theme',
          subdir: _subdir,
        );
      });

      testWidgets('$viewport event detail — $theme', (tester) async {
        await pumpSurface(
          tester,
          device: device,
          brightness: brightness,
          home: const EventDetailPage(eventId: _detailEventId),
          overrides: detailOverrides(),
        );
        expect(find.byType(EventDetailView), findsOneWidget);
        expect(
          find.text(
            _t('Project Waddle launch gala', 'Project-Waddle-Startgala'),
          ),
          findsOneWidget,
        );
        expect(
          find.text(_t('Penguin Operations', 'Pinguinbetrieb')),
          findsOneWidget,
        );
        expect(find.text(_t('Summary', 'Zusammenfassung')), findsOneWidget);
        final galleryImages = find.descendant(
          of: find.byType(EventPhotoGrid),
          matching: find.byType(RawImage),
        );
        expect(galleryImages, findsNWidgets(3));
        for (var index = 0; index < 3; index++) {
          expect(
            tester.renderObject<RenderImage>(galleryImages.at(index)).image,
            isNotNull,
          );
        }
        await captureScreenshot(
          tester,
          'events_detail_${viewport}_$theme',
          subdir: _subdir,
        );
      });

      testWidgets('$viewport event timeline — $theme', (tester) async {
        await pumpSurface(
          tester,
          device: device,
          brightness: brightness,
          home: const EventDetailPage(eventId: _detailEventId),
          overrides: detailOverrides(),
        );
        final detail = find.byType(EventDetailView);
        final scrollable = find.descendant(
          of: detail,
          matching: find.byType(Scrollable),
        );
        await tester.scrollUntilVisible(
          find.text(
            _t(
              'Recalibrate the zero-gravity fish feeder',
              'Schwerelosen Fischfütterer neu kalibrieren',
            ),
          ),
          360,
          scrollable: scrollable.first,
        );
        await settleFrames(tester, 4);
        expect(find.text(_t('Photos', 'Fotos')), findsOneWidget);
        expect(find.text(_t('Timeline', 'Zeitleiste')), findsOneWidget);
        expect(
          find.text(
            _t(
              'Recalibrate the zero-gravity fish feeder',
              'Schwerelosen Fischfütterer neu kalibrieren',
            ),
          ),
          findsOneWidget,
        );
        await captureScreenshot(
          tester,
          'events_timeline_${viewport}_$theme',
          subdir: _subdir,
        );
      });
    }
  }
}
