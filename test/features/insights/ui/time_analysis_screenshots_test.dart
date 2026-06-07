/// Screenshot harness for the Time Analysis dashboard.
///
/// Renders the full page at desktop size (1400×900 logical, 2x DPR) across
/// the design-relevant scenarios and writes PNGs to
/// `screenshots/insights/` (gitignored) for design review. Not a golden
/// test — there are no stored baselines; the assertions only guard that
/// each scenario renders without exceptions.
///
/// Run: `fvm flutter test test/features/insights/ui/time_analysis_screenshots_test.dart`
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/categories/state/categories_list_controller.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/insights/model/insights_models.dart';
import 'package:lotti/features/insights/state/insights_preferences_controller.dart';
import 'package:lotti/features/insights/state/insights_providers.dart';
import 'package:lotti/features/insights/ui/time_analysis_page.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;

import '../../../mocks/mocks.dart';
import 'insights_test_scenarios.dart';

final DateTime _now = DateTime(2026, 6, 7, 16, 30);
const Size _desktopSize = Size(1400, 900);
const ValueKey<String> _boundaryKey = ValueKey<String>('insights-screenshot');

class _FixedPreferencesController extends InsightsPreferencesController {
  _FixedPreferencesController(this._ids);

  final Set<String> _ids;

  @override
  InsightsPreferences build() => InsightsPreferences(focusCategoryIds: _ids);
}

Future<void> _capture(WidgetTester tester, String name) async {
  final boundary =
      tester.element(find.byKey(_boundaryKey)).findRenderObject()!
          as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final dir =
        Platform.environment['LOTTI_SCREENSHOT_DIR'] ??
        p.join('screenshots', 'insights');
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

Future<void> _pumpDashboard(
  WidgetTester tester, {
  required List<InsightsTimeRow> rows,
  required List<CategoryDefinition> categories,
  Set<String> focusCategoryIds = const {},
  Brightness brightness = Brightness.dark,
}) async {
  tester.view
    ..physicalSize = _desktopSize * 2
    ..devicePixelRatio = 2;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final repository = MockInsightsRepository();
  when(
    () => repository.fetchTimeRows(
      start: any(named: 'start'),
      end: any(named: 'end'),
    ),
  ).thenAnswer((invocation) async {
    final start = invocation.namedArguments[#start]! as DateTime;
    final end = invocation.namedArguments[#end]! as DateTime;
    return rows
        .where((r) => r.dateTo.isAfter(start) && r.dateFrom.isBefore(end))
        .toList();
  });

  await withClock(Clock.fixed(_now), () async {
    await tester.pumpWidget(
      RepaintBoundary(
        key: _boundaryKey,
        child: ProviderScope(
          overrides: [
            insightsRepositoryProvider.overrideWithValue(repository),
            maybeUpdateNotificationsProvider.overrideWith((ref) => null),
            categoriesStreamProvider.overrideWith(
              (ref) => Stream.value(categories),
            ),
            insightsPreferencesControllerProvider.overrideWith(
              () => _FixedPreferencesController(focusCategoryIds),
            ),
          ],
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
            home: const TimeAnalysisPage(),
          ),
        ),
      ),
    );
    await tester.pump();
    // fl_chart animates data swaps implicitly (~150ms); give the chart a
    // full settle so captures are never mid-lerp.
    await tester.pump(const Duration(milliseconds: 600));
  });
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await withClock(Clock.fixed(_now), () async {
    await tester.tap(finder);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
  });
}

void main() {
  setUpAll(() async {
    // Widget tests render the blocky FlutterTest font unless the bundled
    // families are loaded explicitly — the screenshots are for design
    // review, so real type matters. Read straight from the repo files
    // (tests run with the package root as cwd).
    TestWidgetsFlutterBinding.ensureInitialized();
    Future<ByteData> fontBytes(String path) async {
      final bytes = await File(path).readAsBytes();
      return ByteData.view(bytes.buffer);
    }

    final inter = FontLoader('Inter')
      ..addFont(
        fontBytes('assets/fonts/Inter/Inter-VariableFont_opsz,wght.ttf'),
      );
    final inconsolata = FontLoader('Inconsolata')
      ..addFont(fontBytes('assets/fonts/Inconsolata/Inconsolata-Regular.ttf'))
      ..addFont(fontBytes('assets/fonts/Inconsolata/Inconsolata-Medium.ttf'))
      ..addFont(fontBytes('assets/fonts/Inconsolata/Inconsolata-Light.ttf'));
    await inter.load();
    await inconsolata.load();

    // Icon glyphs: load MaterialIcons from the Flutter SDK when available
    // so buttons don't render as tofu boxes in the review screenshots.
    final flutterRoot =
        Platform.environment['FLUTTER_ROOT'] ?? '.fvm/flutter_sdk';
    final iconFont = File(
      p.join(
        flutterRoot,
        'bin',
        'cache',
        'artifacts',
        'material_fonts',
        'MaterialIcons-Regular.otf',
      ),
    );
    if (iconFont.existsSync()) {
      final icons = FontLoader('MaterialIcons')
        ..addFont(fontBytes(iconFont.path));
      await icons.load();
    }
  });

  testWidgets('7d default — dark', (tester) async {
    await _pumpDashboard(
      tester,
      rows: insightsScenarioRows(_now),
      categories: insightsScenarioCategories,
    );
    expect(find.text('Time Analysis'), findsOneWidget);
    await _capture(tester, '01_7d_default_dark');
  });

  testWidgets('7d default — light', (tester) async {
    await _pumpDashboard(
      tester,
      rows: insightsScenarioRows(_now),
      categories: insightsScenarioCategories,
      brightness: Brightness.light,
    );
    expect(find.text('Time Analysis'), findsOneWidget);
    await _capture(tester, '02_7d_default_light');
  });

  testWidgets('7d with focus configured — dark', (tester) async {
    await _pumpDashboard(
      tester,
      rows: insightsScenarioRows(_now),
      categories: insightsScenarioCategories,
      focusCategoryIds: const {'cat-client', 'cat-deep'},
    );
    expect(find.text('FOCUS'), findsOneWidget);
    await _capture(tester, '03_7d_focus_dark');
  });

  testWidgets('30d — dark', (tester) async {
    await _pumpDashboard(
      tester,
      rows: insightsScenarioRows(_now),
      categories: insightsScenarioCategories,
    );
    await _tap(tester, find.text('30d'));
    await _capture(tester, '04_30d_dark');
  });

  testWidgets('YTD with many categories (weekly + Other) — dark', (
    tester,
  ) async {
    await _pumpDashboard(
      tester,
      rows: insightsScenarioRows(_now, manyCategories: true),
      categories: insightsScenarioCategories,
    );
    await _tap(tester, find.text('YTD'));
    expect(find.textContaining('Other'), findsWidgets);
    await _capture(tester, '05_ytd_weekly_other_dark');
  });

  testWidgets('30d cumulative — dark', (tester) async {
    await _pumpDashboard(
      tester,
      rows: insightsScenarioRows(_now),
      categories: insightsScenarioCategories,
    );
    await _tap(tester, find.text('30d'));
    await _tap(tester, find.text('Cumulative'));
    await _capture(tester, '06_30d_cumulative_dark');
  });

  testWidgets('1d hourly — dark', (tester) async {
    await _pumpDashboard(
      tester,
      rows: insightsScenarioRows(_now),
      categories: insightsScenarioCategories,
    );
    await _tap(tester, find.text('1d'));
    await _capture(tester, '07_1d_hourly_dark');
  });

  testWidgets('empty range — dark', (tester) async {
    await _pumpDashboard(
      tester,
      rows: const [],
      categories: insightsScenarioCategories,
    );
    expect(find.text('No tracked time in this range'), findsOneWidget);
    await _capture(tester, '08_empty_dark');
  });

  testWidgets('sparse data 30d — dark', (tester) async {
    await _pumpDashboard(
      tester,
      rows: insightsSparseRows(_now),
      categories: insightsScenarioCategories,
    );
    await _tap(tester, find.text('30d'));
    await _capture(tester, '09_sparse_30d_dark');
  });

  testWidgets('single category — dark', (tester) async {
    await _pumpDashboard(
      tester,
      rows: insightsSingleCategoryRows(_now),
      categories: insightsScenarioCategories,
    );
    await _capture(tester, '10_single_category_dark');
  });
}
