import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/onboarding/ui/widgets/onboarding_connect_panel.dart';
import 'package:lotti/features/onboarding/ui/widgets/onboarding_hero.dart';
import 'package:lotti/l10n/app_localizations.dart';

import 'test_utils/screenshot_harness.dart';

void main() {
  setUpAll(loadAppFonts);

  Future<void> snap(WidgetTester tester, Widget panel, String name) async {
    const size = Size(390, 844);
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: screenshotTheme(),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (ctx) => MediaQuery(
            data: MediaQuery.of(ctx).copyWith(disableAnimations: true),
            child: Scaffold(
              backgroundColor: const Color(0xFF0E0E0E),
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: panel,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('screenshots/$name.png'),
    );
  }

  testWidgets('welcome', (tester) async {
    await snap(
      tester,
      OnboardingHeroPanel(onConnect: () {}, onSkip: () {}),
      'welcome_v3',
    );
  });

  testWidgets('connect', (tester) async {
    await snap(
      tester,
      OnboardingConnectPanel(onSelect: (_) {}, onBack: () {}),
      'connect_v3',
    );
  });
}
