import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/companion/model/companion_customization.dart';
import 'package:lotti/features/companion/state/companion_customization_controller.dart';
import 'package:lotti/features/companion/ui/settings/companion_settings_page.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:mocktail/mocktail.dart';

import 'helpers/fallbacks.dart';
import 'mocks/mocks.dart';
import 'test_utils/screenshot_harness.dart';
import 'widget_test_utils.dart';

const _phase = String.fromEnvironment('PHASE', defaultValue: 'before');

void main() {
  setUpAll(() async {
    registerAllFallbackValues();
    await loadAppFonts();
  });

  setUp(() async {
    await setUpTestGetIt(
      additionalSetup: () {
        final activity = MockUserActivityService();
        when(activity.updateActivity).thenReturn(null);
        getIt.registerSingleton<UserActivityService>(activity);
      },
    );
  });
  tearDown(tearDownTestGetIt);

  Future<void> shoot(
    WidgetTester tester,
    String name,
    Size size,
    CompanionCustomization custom,
  ) async {
    final db = SettingsDb(inMemoryDatabase: true);
    addTearDown(db.close);
    final outbox = MockOutboxService();
    when(() => outbox.enqueueMessage(any())).thenAnswer((_) async {});
    await captureInApp(
      tester,
      child: const CompanionSettingsPage(),
      name: '$_phase/$name',
      size: size,
      dark: false,
      waitForIdle: false,
      interaction: (t) async {
        for (var i = 0; i < 40; i++) {
          await t.pump(const Duration(milliseconds: 25));
        }
      },
      overrides: [
        settingsDbProvider.overrideWithValue(db),
        outboxServiceProvider.overrideWithValue(outbox),
        companionCustomizationProvider.overrideWithBuild((ref, n) => custom),
      ],
    );
  }

  const lotti = CompanionCustomization(outfitId: 'grandma');

  testWidgets('lotti phone', (t) => shoot(t, 'companion_settings_lotti_mobile_light', ScreenshotViewport.phone, lotti));
  testWidgets('lotti phone full', (t) => shoot(t, 'companion_settings_lotti_full_mobile_light', const Size(390, 2100), lotti));
  testWidgets('lotti desktop', (t) => shoot(t, 'companion_settings_lotti_desktop_light', ScreenshotViewport.desktop, lotti));
}
