/// Production screenshot harness for the What's New manual.
///
/// Captures the real release modal over the real Settings surface, with a
/// Project Waddle release feed and bundled task cover art primed into Flutter's
/// network-image cache. Every case is rendered at mobile and desktop size in
/// light and dark mode.
///
/// Opt in with:
/// `LOTTI_SCREENSHOT_DIR=/tmp/whats-new fvm flutter test \
///   test/features/whats_new/ui/whats_new_manual_screenshots_test.dart`
library;

import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:form_builder_validators/localization/l10n.dart';
import 'package:lotti/database/state/config_flag_provider.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/settings/ui/pages/settings_root_page.dart';
import 'package:lotti/features/whats_new/model/whats_new_content.dart';
import 'package:lotti/features/whats_new/model/whats_new_release.dart';
import 'package:lotti/features/whats_new/model/whats_new_state.dart';
import 'package:lotti/features/whats_new/state/whats_new_controller.dart';
import 'package:lotti/features/whats_new/ui/whats_new_modal.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/utils/consts.dart';

import '../../../widget_test_utils.dart';
import '../../daily_os_next/screenshot_harness.dart';

const _launchBannerUrl =
    'https://manual.invalid/project-waddle-launch-review.webp';
const _sardineBannerUrl =
    'https://manual.invalid/project-waddle-sardine-futures.webp';

final _manualReleases = <WhatsNewContent>[
  WhatsNewContent(
    release: WhatsNewRelease(
      version: '0.9.1049',
      date: DateTime.utc(2026, 7, 17),
      title: 'Project Waddle is cleared for orbit',
      folder: '0.9.1049',
    ),
    headerMarkdown: '''
# Project Waddle is cleared for orbit

The emperor penguin logistics crew can now plan the whole mission in Lotti.
''',
    sections: const [
      '''
## A calmer Daily OS

Task cover art now travels with each agenda item, so the Europa relay,
orbital habitat, and sardine cargo review remain easy to spot.

## Sharper task operations

Use the refreshed task workspace to inspect priorities, linked evidence, and
time records without losing the mission context.
''',
    ],
    bannerImageUrl: _launchBannerUrl,
  ),
  WhatsNewContent(
    release: WhatsNewRelease(
      version: '0.9.1048',
      date: DateTime.utc(2026, 7, 10),
      title: 'Sardine telemetry reaches Mission Control',
      folder: '0.9.1048',
    ),
    headerMarkdown: '''
# Sardine telemetry reaches Mission Control

Project Waddle has a clearer view of every crate, habitat, and hungry crew.
''',
    sections: const [
      '''
## Compare the mission

Time Analysis now makes it easier to compare habitat inspections with cargo
handling and see where the week really went.

## Dashboard-ready signals

Track sardines consumed, cargo pods delivered, and penguins safely accounted
for with the same definitions used throughout the workspace.
''',
    ],
    bannerImageUrl: _sardineBannerUrl,
  ),
];

class _ManualWhatsNewController extends WhatsNewController {
  @override
  Future<WhatsNewState> build() async => WhatsNewState(
    unseenContent: _manualReleases,
  );

  @override
  Future<void> markAllAsSeen() async {}

  @override
  Future<void> markAsSeen(String version) async {}
}

class _WhatsNewLaunchHost extends ConsumerStatefulWidget {
  const _WhatsNewLaunchHost();

  @override
  ConsumerState<_WhatsNewLaunchHost> createState() =>
      _WhatsNewLaunchHostState();
}

class _WhatsNewLaunchHostState extends ConsumerState<_WhatsNewLaunchHost> {
  var _launched = false;

  @override
  Widget build(BuildContext context) {
    if (!_launched) {
      _launched = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(WhatsNewModal.show(context, ref));
      });
    }
    return const SettingsRootPage();
  }
}

Widget _app({
  required Brightness brightness,
  required Size size,
  required List<Override> overrides,
}) {
  return RepaintBoundary(
    key: screenshotBoundaryKey,
    child: ProviderScope(
      overrides: overrides,
      child: MediaQuery(
        data: MediaQueryData(size: size, disableAnimations: true),
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          locale: const Locale('en'),
          theme: brightness == Brightness.dark
              ? DesignSystemTheme.dark()
              : DesignSystemTheme.light(),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            FormBuilderLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: const _WhatsNewLaunchHost(),
        ),
      ),
    ),
  );
}

Future<void> _primeNetworkImage(String url, String assetPath) async {
  final bytes = await File(assetPath).readAsBytes();
  final codec = await ui.instantiateImageCodec(bytes);
  final frame = await codec.getNextFrame();
  codec.dispose();

  final provider = NetworkImage(url);
  final key = await provider.obtainKey(ImageConfiguration.empty);
  PaintingBinding.instance.imageCache.putIfAbsent(
    key,
    () => OneFrameImageStreamCompleter(
      SynchronousFuture<ImageInfo>(ImageInfo(image: frame.image)),
    ),
  );
}

void main() {
  if (!screenshotCaptureEnabled) {
    test(
      "what's-new screenshot harness (opt-in)",
      () {},
      skip:
          'Manual screenshots are opt-in: run with '
          'LOTTI_SCREENSHOT_DIR=<dir> (or LOTTI_CAPTURE_SCREENSHOTS=true).',
    );
    return;
  }

  setUpAll(loadScreenshotFonts);

  late NavService navService;

  setUp(() async {
    await setUpTestGetIt();
    navService = NavService();
    getIt.registerSingleton<NavService>(navService);
    beamToNamedOverride = (_) {};

    await _primeNetworkImage(
      _launchBannerUrl,
      'assets/design_system/manual_task_cover_launch_review.webp',
    );
    await _primeNetworkImage(
      _sardineBannerUrl,
      'assets/design_system/manual_task_cover_sardine_futures.webp',
    );
  });

  tearDown(() async {
    beamToNamedOverride = null;
    PaintingBinding.instance.imageCache
      ..clear()
      ..clearLiveImages();
    await navService.dispose();
    await tearDownTestGetIt();
  });

  List<Override> overrides() => [
    whatsNewControllerProvider.overrideWith(_ManualWhatsNewController.new),
    for (final flag in [
      enableHabitsPageFlag,
      enableDashboardsPageFlag,
      enableMatrixFlag,
      enableWhatsNewFlag,
      enableAiSummaryTtsFlag,
    ])
      configFlagProvider(flag).overrideWith(
        (ref) => Stream.value(flag == enableWhatsNewFlag),
      ),
  ];

  Future<void> pumpModal(
    WidgetTester tester, {
    required ScreenshotDevice device,
    required Brightness brightness,
    required bool pastRelease,
  }) async {
    applyScreenshotDevice(tester, device);
    navService.isDesktopMode = !device.isPhone;

    await tester.pumpWidget(
      _app(
        brightness: brightness,
        size: device.size,
        overrides: overrides(),
      ),
    );
    await settleFrames(tester, 18);

    expect(find.text('v0.9.1049'), findsOneWidget);
    if (pastRelease) {
      await tester.tap(find.byIcon(Icons.chevron_right));
      await settleFrames(tester, 10);
      expect(find.text('v0.9.1048'), findsOneWidget);
    }
  }

  for (final (viewport, device) in [
    ('mobile', miniDevice),
    ('desktop', desktopDevice),
  ]) {
    for (final brightness in [Brightness.light, Brightness.dark]) {
      final theme = brightness.name;

      testWidgets('latest $viewport manual — $theme', (tester) async {
        await pumpModal(
          tester,
          device: device,
          brightness: brightness,
          pastRelease: false,
        );

        expect(find.text('NEW'), findsOneWidget);
        expect(
          find.textContaining(
            'Project Waddle is cleared for orbit',
            findRichText: true,
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        await captureScreenshot(
          tester,
          'whats_new_latest_${viewport}_$theme',
          subdir: 'whats_new',
        );
      });

      testWidgets('past release $viewport manual — $theme', (tester) async {
        await pumpModal(
          tester,
          device: device,
          brightness: brightness,
          pastRelease: true,
        );

        expect(find.text('NEW'), findsNothing);
        expect(
          find.textContaining(
            'Sardine telemetry reaches Mission Control',
            findRichText: true,
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        await captureScreenshot(
          tester,
          'whats_new_past_release_${viewport}_$theme',
          subdir: 'whats_new',
        );
      });
    }
  }
}
