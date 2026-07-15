/// Opt-in dark-mode screenshot harness for the real measurement-capture route.
///
/// The captures cover the filled editor, the observed-at page at its initial
/// position, and the same page at maximum scroll so the sticky action footer
/// and final time controls can be reviewed together.
///
/// Run: `LOTTI_SCREENSHOT_DIR=/tmp/measure fvm flutter test \
///   test/pages/create/create_measurement_dialog_screenshots_test.dart`
library;

import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/pages/create/create_measurement_dialog.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;

import '../../features/dashboards/ui/screenshot_fonts.dart';
import '../../mocks/mocks.dart';
import '../../test_data/test_data.dart';
import '../../widget_test_utils.dart';
import 'test_utils.dart';

const _boundaryKey = ValueKey<String>('measurement-screenshot');
const _openKey = ValueKey<String>('open-measurement-capture');
const _valueKey = Key('measurement_value_field');
const _commentKey = Key('measurement_comment_field');
const _observedAtKey = Key('measurement_observed_at');
final _fixedNow = DateTime.utc(2024, 3, 15, 14, 30, 15, 16, 17);

Future<void> _capture(WidgetTester tester, String name) async {
  final boundary =
      tester.element(find.byKey(_boundaryKey)).findRenderObject()!
          as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final dir =
        Platform.environment['LOTTI_SCREENSHOT_DIR'] ??
        p.join('screenshots', 'measurement');
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

Future<void> _pumpLauncher(WidgetTester tester) async {
  tester.view
    ..physicalSize = const Size(804, 1748)
    ..devicePixelRatio = 2;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    RepaintBoundary(
      key: _boundaryKey,
      child: ProviderScope(
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: DesignSystemTheme.dark(),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) {
                final tokens = context.designTokens;
                return ColoredBox(
                  color: tokens.colors.background.level01,
                  child: Center(
                    child: DesignSystemButton(
                      key: _openKey,
                      label: 'Log measurement',
                      size: DesignSystemButtonSize.large,
                      onPressed: () {
                        unawaited(
                          withClock(
                            Clock.fixed(_fixedNow),
                            () => MeasurementCaptureModal.show(
                              context: context,
                              measurableDataType: measurableWater,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.byKey(_openKey));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 450));
  await tester.pump();
}

void main() {
  final captureEnabled =
      Platform.environment.containsKey('LOTTI_SCREENSHOT_DIR') ||
      Platform.environment['LOTTI_CAPTURE_SCREENSHOTS'] == 'true';
  if (!captureEnabled) {
    test(
      'measurement capture screenshot harness (opt-in)',
      () {},
      skip: 'opt-in',
    );
    return;
  }

  setUpAll(loadScreenshotFonts);

  late MockJournalDb mockJournalDb;
  late MockPersistenceLogic mockPersistenceLogic;

  setUp(() async {
    mockJournalDb = mockJournalDbWithMeasurableTypes([measurableWater]);
    mockPersistenceLogic = MockPersistenceLogic();
    await setUpTestGetIt(
      additionalSetup: () {
        getIt
          ..unregister<JournalDb>()
          ..registerSingleton<JournalDb>(mockJournalDb)
          ..registerSingleton<PersistenceLogic>(mockPersistenceLogic);
      },
    );
    when(
      () => mockJournalDb.getMeasurementsByType(
        rangeStart: any(named: 'rangeStart'),
        rangeEnd: any(named: 'rangeEnd'),
        type: measurableWater.id,
      ),
    ).thenAnswer((_) async => measurementSuggestionFixture());
  });

  tearDown(tearDownTestGetIt);

  testWidgets('captures the complete measurement flow in dark mode', (
    tester,
  ) async {
    await _pumpLauncher(tester);
    await tester.enterText(find.byKey(_valueKey), '750');
    await tester.enterText(find.byKey(_commentKey), 'After a long run');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    await _capture(tester, 'measurement_capture_after_editor_dark');

    await tester.tap(find.byKey(_observedAtKey));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 450));
    await _capture(tester, 'measurement_capture_after_observed_at_top_dark');

    final modalScrollView = find.byType(CustomScrollView);
    final scrollable = find.descendant(
      of: modalScrollView,
      matching: find.byType(Scrollable),
    );
    final scrollableState = tester.state<ScrollableState>(scrollable.first);
    scrollableState.position.jumpTo(scrollableState.position.maxScrollExtent);
    await tester.pump();
    await _capture(
      tester,
      'measurement_capture_after_observed_at_scrolled_dark',
    );
  });
}
