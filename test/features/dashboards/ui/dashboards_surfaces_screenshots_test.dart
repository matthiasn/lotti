/// Opt-in screenshot harness for the dashboard time-span picker and the habit
/// completion card surfaces (design review of the migrated surfaces).
///
/// Run: `LOTTI_SCREENSHOT_DIR=/tmp/surfaces fvm flutter test \
///   test/features/dashboards/ui/dashboards_surfaces_screenshots_test.dart`
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/habits/state/habit_completion_controller.dart';
import 'package:lotti/features/habits/ui/widgets/habit_completion_card.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/widgets/charts/habits/dashboard_habits_data.dart';
import 'package:lotti/widgets/misc/timespan_segmented_control.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../../../test_data/test_data.dart';
import '../../../widget_test_utils.dart';

const ValueKey<String> _boundaryKey = ValueKey<String>('surfaces-screenshot');
final DateTime _now = DateTime(2026, 3, 31, 12);
final DateTime _rangeStart = DateTime(2026, 3);
final DateTime _rangeEnd = DateTime(2026, 3, 31);

List<HabitResult> _results() {
  const cycle = [
    HabitCompletionType.success,
    HabitCompletionType.success,
    HabitCompletionType.skip,
    HabitCompletionType.fail,
    HabitCompletionType.open,
  ];
  return [
    for (var i = 0; i < 30; i++)
      HabitResult(
        dayString: _rangeStart.add(Duration(days: i)).toIso8601String().split(
          'T',
        )[0],
        completionType: cycle[i % cycle.length],
      ),
  ];
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

Future<void> _pump(WidgetTester tester, {required Brightness brightness}) async {
  tester.view
    ..physicalSize = const Size(800, 700)
    ..devicePixelRatio = 2;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await withClock(Clock.fixed(_now), () async {
    await tester.pumpWidget(
      RepaintBoundary(
        key: _boundaryKey,
        child: ProviderScope(
          overrides: [
            habitCompletionControllerProvider(
              habitId: habitFlossing.id,
              rangeStart: _rangeStart,
              rangeEnd: _rangeEnd,
            ).overrideWithBuild((ref, notifier) => _results()),
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
            home: Builder(
              builder: (context) {
                return Scaffold(
                  body: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TimeSpanSegmentedControl(
                          timeSpanDays: 90,
                          onValueChanged: (_) {},
                        ),
                        const SizedBox(height: 24),
                        HabitCompletionCard(
                          habitId: habitFlossing.id,
                          rangeStart: _rangeStart,
                          rangeEnd: _rangeEnd,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
  });
}

void main() {
  final captureEnabled =
      Platform.environment.containsKey('LOTTI_SCREENSHOT_DIR') ||
      Platform.environment['LOTTI_CAPTURE_SCREENSHOTS'] == 'true';
  if (!captureEnabled) {
    test('surfaces screenshot harness (opt-in)', () {}, skip: 'opt-in');
    return;
  }

  setUpAll(registerAllFallbackValues);

  setUp(() async {
    final mockCache = MockEntitiesCacheService();
    when(() => mockCache.getHabitById(any())).thenReturn(habitFlossing);
    when(() => mockCache.getCategoryById(any())).thenReturn(categoryMindfulness);
    await setUpTestGetIt(
      additionalSetup: () {
        getIt.registerSingleton<EntitiesCacheService>(mockCache);
      },
    );
  });

  tearDown(tearDownTestGetIt);

  testWidgets('picker + habit card — dark', (tester) async {
    await _pump(tester, brightness: Brightness.dark);
    await _capture(tester, '20_surfaces_dark');
  });
}
