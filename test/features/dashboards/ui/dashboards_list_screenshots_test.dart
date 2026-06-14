/// Opt-in screenshot harness for the dashboards list page (the Insights tab
/// list) and the habit completion card, for design review of their surfaces.
///
/// Run: `LOTTI_SCREENSHOT_DIR=/tmp/list fvm flutter test \
///   test/features/dashboards/ui/dashboards_list_screenshots_test.dart`
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/dashboards/ui/pages/dashboards_list_page.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../../../test_data/test_data.dart';
import '../../../widget_test_utils.dart';
import 'screenshot_fonts.dart';

const ValueKey<String> _boundaryKey = ValueKey<String>('list-screenshot');

Future<void> _capture(WidgetTester tester, String name) async {
  final boundary =
      tester.element(find.byKey(_boundaryKey)).findRenderObject()!
          as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final dir =
        Platform.environment['LOTTI_SCREENSHOT_DIR'] ??
        p.join('screenshots', 'dashboards');
    final file = File(p.join(dir, '$name.png'));
    await file.parent.create(recursive: true);
    await file.writeAsBytes(
      byteData!.buffer.asUint8List(
        byteData.offsetInBytes,
        byteData.lengthInBytes,
      ),
      flush: true,
    );
    stdout.writeln('wrote screenshot: ${file.path}');
  });
}

Future<void> _pump(
  WidgetTester tester, {
  required Brightness brightness,
}) async {
  tester.view
    ..physicalSize = const Size(900, 1400)
    ..devicePixelRatio = 2;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    RepaintBoundary(
      key: _boundaryKey,
      child: ProviderScope(
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
          home: const DashboardsListPage(),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 200));
}

void main() {
  final captureEnabled =
      Platform.environment.containsKey('LOTTI_SCREENSHOT_DIR') ||
      Platform.environment['LOTTI_CAPTURE_SCREENSHOTS'] == 'true';
  if (!captureEnabled) {
    test('list screenshot harness (opt-in)', () {}, skip: 'opt-in');
    return;
  }

  setUpAll(registerAllFallbackValues);
  setUpAll(loadScreenshotFonts);

  late MockJournalDb mockJournalDb;

  setUp(() async {
    mockJournalDb = mockJournalDbWithMeasurableTypes([measurableWater]);
    when(
      mockJournalDb.getAllCategories,
    ).thenAnswer((_) async => [categoryMindfulness]);
    when(mockJournalDb.getAllDashboards).thenAnswer(
      (_) async => [testDashboardConfig, emptyTestDashboardConfig],
    );

    final mockNav = MockNavService();
    when(() => mockNav.isDesktopMode).thenReturn(false);
    when(
      () => mockNav.desktopSelectedDashboardId,
    ).thenReturn(ValueNotifier<String?>(null));

    final mockCache = MockEntitiesCacheService();
    when(
      () => mockCache.getCategoryById(any()),
    ).thenReturn(categoryMindfulness);

    await setUpTestGetIt(
      additionalSetup: () {
        getIt
          ..unregister<JournalDb>()
          ..registerSingleton<JournalDb>(mockJournalDb)
          ..registerSingleton<UserActivityService>(UserActivityService())
          ..registerSingleton<EntitiesCacheService>(mockCache)
          ..registerSingleton<NavService>(mockNav);
      },
    );
  });

  tearDown(tearDownTestGetIt);

  testWidgets('dashboards list — dark', (tester) async {
    await _pump(tester, brightness: Brightness.dark);
    await _capture(tester, '10_dashboards_list_dark');
  });

  testWidgets('dashboards list — light', (tester) async {
    await _pump(tester, brightness: Brightness.light);
    await _capture(tester, '11_dashboards_list_light');
  });
}
