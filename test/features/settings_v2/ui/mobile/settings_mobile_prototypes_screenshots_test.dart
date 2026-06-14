/// Design-review screenshot harness for the unified mobile settings
/// drill-down ([SettingsMobileTreePage]), rendered from the SAME
/// `buildSettingsTree(...)` data the desktop tree-nav uses — so this also
/// proves the unified construction renders correctly on a phone. PNGs
/// land in `$LOTTI_SCREENSHOT_DIR` (or `screenshots/settings_mobile/`).
///
/// Opt-in (real-font loading leaks process-wide — see the harness). Run:
/// `LOTTI_SCREENSHOT_DIR=/tmp/settings_mobile fvm flutter test \
///   test/features/settings_v2/ui/mobile/settings_mobile_prototypes_screenshots_test.dart`
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:form_builder_validators/localization/l10n.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/settings_v2/domain/settings_node.dart';
import 'package:lotti/features/settings_v2/domain/settings_tree_data.dart';
import 'package:lotti/features/settings_v2/ui/labels/settings_tree_labels.dart';
import 'package:lotti/features/settings_v2/ui/mobile/settings_mobile_tree_page.dart';
import 'package:lotti/l10n/app_localizations.dart';

import '../../../daily_os_next/screenshot_harness.dart';

const String _subdir = 'settings_mobile';

List<SettingsNode> _tree(BuildContext context) => buildSettingsTree(
  labels: settingsTreeLabelsFor(context),
  enableHabits: true,
  enableDashboards: true,
  enableMatrix: true,
  enableWhatsNew: false,
);

Widget _app({
  required WidgetBuilder builder,
  required Brightness brightness,
  required Size size,
  double textScale = 1.0,
}) {
  return RepaintBoundary(
    key: screenshotBoundaryKey,
    child: ProviderScope(
      child: MediaQuery(
        data: MediaQueryData(
          size: size,
          textScaler: TextScaler.linear(textScale),
        ),
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
          home: Builder(builder: builder),
        ),
      ),
    ),
  );
}

Future<void> _pump(
  WidgetTester tester, {
  required WidgetBuilder builder,
  Brightness brightness = Brightness.dark,
  double textScale = 1.0,
}) async {
  applyScreenshotDevice(tester, miniDevice);
  await tester.pumpWidget(
    _app(
      builder: builder,
      brightness: brightness,
      size: miniDevice.size,
      textScale: textScale,
    ),
  );
  await settleFrames(tester);
}

Widget _root(BuildContext context) => SettingsMobileTreePage(
  title: 'Settings',
  nodes: _tree(context),
  onNodeTap: (_) {},
);

Widget _definitions(BuildContext context) {
  final definitions = _tree(context).firstWhere((n) => n.id == 'definitions');
  return SettingsMobileTreePage(
    title: definitions.title,
    nodes: definitions.children!,
    showBack: true,
    onNodeTap: (_) {},
  );
}

void main() {
  if (!screenshotCaptureEnabled) {
    test(
      'settings-mobile screenshots (opt-in)',
      () {},
      skip:
          'Design-review screenshots are opt-in: run with '
          'LOTTI_SCREENSHOT_DIR=<dir> (or LOTTI_CAPTURE_SCREENSHOTS=true) '
          'because the real-font loading leaks process-wide.',
    );
    return;
  }

  setUpAll(loadScreenshotFonts);

  testWidgets('mobile root — dark', (tester) async {
    await _pump(tester, builder: _root);
    expect(find.text('Theming'), findsOneWidget);
    await captureScreenshot(tester, 'mobile_root_dark', subdir: _subdir);
  });

  testWidgets('mobile root — light', (tester) async {
    await _pump(tester, brightness: Brightness.light, builder: _root);
    expect(find.text('Theming'), findsOneWidget);
    await captureScreenshot(tester, 'mobile_root_light', subdir: _subdir);
  });

  testWidgets('mobile Definitions level — dark', (tester) async {
    await _pump(tester, builder: _definitions);
    expect(find.text('Categories'), findsOneWidget);
    await captureScreenshot(tester, 'mobile_definitions_dark', subdir: _subdir);
  });

  // 1.6x text — proves the row min-height grows for large text and the
  // 2-line description instead of clipping (the a11y must-fix).
  testWidgets('mobile root — dark, 1.6x text', (tester) async {
    await _pump(tester, textScale: 1.6, builder: _root);
    expect(find.text('Theming'), findsOneWidget);
    await captureScreenshot(tester, 'mobile_root_dark_1_6x', subdir: _subdir);
  });
}
