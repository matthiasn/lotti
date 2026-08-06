import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/demo/media/demo_media_hydrator.dart';
import 'package:lotti/features/demo/ui/demo_mode_banner.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/profiles/state/profile_providers.dart';
import 'package:lotti/get_it.dart';

import 'test_utils/screenshot_harness.dart';
import 'widget_test_utils.dart';

void main() {
  setUpAll(loadAppFonts);

  late DemoMediaHydrator hydrator;

  setUp(() async {
    await setUpTestGetIt();
    hydrator = DemoMediaHydrator(
      root: Directory.systemTemp,
      assets: const [],
      download: (_) async => throw UnimplementedError(),
    );
    getIt.registerSingleton<DemoMediaHydrator>(
      hydrator,
      dispose: (service) => service.dispose(),
    );
  });
  tearDown(tearDownTestGetIt);

  /// A plausible app body behind the banner, so the panel can judge how the
  /// strip sits against real content rather than a blank rectangle.
  Widget appBody(BuildContext context) {
    final tokens = context.designTokens;
    return ColoredBox(
      color: tokens.colors.background.level01,
      child: Padding(
        padding: EdgeInsets.all(tokens.spacing.step5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tasks',
              style: tokens.typography.styles.heading.heading1.copyWith(
                color: tokens.colors.text.highEmphasis,
              ),
            ),
            SizedBox(height: tokens.spacing.step4),
            for (final title in const [
              'Recalibrate the zero-gravity fish feeder',
              'Inspect orbital penguin habitat',
              'Route the sardine cargo pods',
            ])
              Padding(
                padding: EdgeInsets.only(bottom: tokens.spacing.step3),
                child: Container(
                  padding: EdgeInsets.all(tokens.spacing.step4),
                  decoration: BoxDecoration(
                    color: tokens.colors.background.level02,
                    borderRadius: BorderRadius.circular(tokens.radii.l),
                  ),
                  child: Text(
                    title,
                    style: tokens.typography.styles.body.bodyMedium.copyWith(
                      color: tokens.colors.text.highEmphasis,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget banner() => DemoModeScaffold(
    child: Builder(builder: appBody),
  );

  List<Override> overrides() => [
    demoModeActiveProvider.overrideWithValue(true),
  ];

  Future<void> capture(
    WidgetTester tester, {
    required String name,
    required Size size,
    DemoMediaHydrationProgress? progress,
  }) async {
    if (progress != null) hydrator.progress.value = progress;
    await captureInApp(
      tester,
      child: banner(),
      name: name,
      size: size,
      devicePixelRatio: 2,
      overrides: overrides(),
      waitForIdle: false,
    );
  }

  testWidgets('banner desktop idle', (tester) async {
    await capture(
      tester,
      name: 'banner_desktop_idle',
      size: ScreenshotViewport.desktop,
      progress: const DemoMediaHydrationProgress(completed: 91, total: 91),
    );
  });

  testWidgets('banner desktop downloading', (tester) async {
    await capture(
      tester,
      name: 'banner_desktop_downloading',
      size: ScreenshotViewport.desktop,
      progress: const DemoMediaHydrationProgress(completed: 37, total: 91),
    );
  });

  testWidgets('banner phone idle', (tester) async {
    await capture(
      tester,
      name: 'banner_phone_idle',
      size: ScreenshotViewport.phone,
      progress: const DemoMediaHydrationProgress(completed: 91, total: 91),
    );
  });

  testWidgets('banner phone downloading', (tester) async {
    await capture(
      tester,
      name: 'banner_phone_downloading',
      size: ScreenshotViewport.phone,
      progress: const DemoMediaHydrationProgress(completed: 37, total: 91),
    );
  });
}
