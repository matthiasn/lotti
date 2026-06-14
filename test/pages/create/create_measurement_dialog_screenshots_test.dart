/// Opt-in screenshot harness for the measurement-entry modal, for design
/// review of its surface (value field, observed-at field, comment field,
/// quick-value suggestions, and the save action).
///
/// Renders the real [MeasurementDialog] inside a faithful mock of the Wolt
/// modal chrome (centered title + close button, `surfaceContainerHigh`
/// background, the modal's content padding) so the screenshots reflect what
/// the user actually sees when they tap the chart "+" button. The modal
/// chrome itself is shared infrastructure (`ModalUtils`); the review target
/// is the dialog body.
///
/// Run: `LOTTI_SCREENSHOT_DIR=/tmp/measure fvm flutter test \
///   test/pages/create/create_measurement_dialog_screenshots_test.dart`
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:beamer/beamer.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/pages/create/create_measurement_dialog.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;

import '../../features/dashboards/ui/screenshot_fonts.dart';
import '../../mocks/mocks.dart';
import '../../test_data/test_data.dart';
import '../../widget_test_utils.dart';

const ValueKey<String> _boundaryKey = ValueKey<String>(
  'measurement-screenshot',
);

/// Faithful mock of the Wolt single-page modal chrome around [child]:
/// a centered title with a trailing close button over the modal's
/// `surfaceContainerHigh` surface, with the shared content padding.
Widget _modalChrome(
  BuildContext context, {
  required Widget child,
  required String title,
  String? subtitle,
}) {
  final theme = Theme.of(context);
  final colorScheme = theme.colorScheme;
  return Container(
    width: 460,
    decoration: BoxDecoration(
      color: colorScheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(28),
    ),
    clipBehavior: Clip.antiAlias,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 65,
          child: Stack(
            children: [
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.2,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant.withValues(
                            alpha: 0.8,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Positioned(
                top: 0,
                right: 0,
                child: IconButton(
                  padding: const EdgeInsets.all(12),
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHigh.withValues(
                        alpha: 0.5,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.close_rounded,
                      color: colorScheme.onSurfaceVariant,
                      size: 20,
                    ),
                  ),
                  onPressed: () {},
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(
            left: 20,
            top: 8,
            right: 20,
            bottom: 32,
          ),
          child: child,
        ),
      ],
    ),
  );
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

Future<void> _pump(
  WidgetTester tester, {
  required Brightness brightness,
  String? enterValue,
}) async {
  tester.view
    ..physicalSize = const Size(1100, 1400)
    ..devicePixelRatio = 2;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final delegate = BeamerDelegate(
    locationBuilder: RoutesLocationBuilder(
      routes: {'/': (context, state, data) => Container()},
    ).call,
  );

  await tester.pumpWidget(
    RepaintBoundary(
      key: _boundaryKey,
      child: ProviderScope(
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme:
              (brightness == Brightness.dark
                      ? DesignSystemTheme.dark()
                      : DesignSystemTheme.light())
                  // The real app theme defines an outline input border; mirror
                  // it here so the harness reproduces any border that bleeds
                  // through a field's own decoration (it must not).
                  .copyWith(
                    inputDecorationTheme: const InputDecorationTheme(
                      border: OutlineInputBorder(),
                      enabledBorder: OutlineInputBorder(),
                      focusedBorder: OutlineInputBorder(),
                    ),
                  ),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: BeamerProvider(
            routerDelegate: delegate,
            child: Scaffold(
              body: Center(
                child: Builder(
                  builder: (context) => _modalChrome(
                    context,
                    title: measurableWater.displayName,
                    subtitle: measurableWater.description,
                    child: MeasurementDialog(measurableId: measurableWater.id),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));

  if (enterValue != null) {
    await tester.enterText(
      find.byKey(const Key('measurement_value_field')),
      enterValue,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }
}

void main() {
  final captureEnabled =
      Platform.environment.containsKey('LOTTI_SCREENSHOT_DIR') ||
      Platform.environment['LOTTI_CAPTURE_SCREENSHOTS'] == 'true';
  if (!captureEnabled) {
    test(
      'measurement modal screenshot harness (opt-in)',
      () {},
      skip: 'opt-in',
    );
    return;
  }

  setUpAll(loadScreenshotFonts);

  late MockJournalDb mockJournalDb;
  final mockEntitiesCacheService = MockEntitiesCacheService();
  late MockPersistenceLogic mockPersistenceLogic;

  /// Two same-value measurements so the suggestion controller surfaces a
  /// couple of quick-value chips.
  List<MeasurementEntry> suggestionFixture() {
    MeasurementEntry entry(String id, num value, DateTime at) =>
        MeasurementEntry(
          meta: Metadata(
            id: id,
            createdAt: at,
            dateFrom: at,
            dateTo: at,
            updatedAt: at,
            starred: false,
            private: false,
          ),
          data: MeasurementData(
            value: value,
            dataTypeId: measurableWater.id,
            dateTo: at,
            dateFrom: at,
          ),
        );
    return [
      entry('s1', 500, DateTime(2024, 3, 15, 10, 30)),
      entry('s2', 500, DateTime(2024, 3, 14, 9)),
      entry('s3', 250, DateTime(2024, 3, 13, 8)),
    ];
  }

  setUp(() async {
    mockJournalDb = mockJournalDbWithMeasurableTypes([measurableWater]);
    mockPersistenceLogic = MockPersistenceLogic();

    await setUpTestGetIt(
      additionalSetup: () {
        getIt
          ..unregister<JournalDb>()
          ..registerSingleton<JournalDb>(mockJournalDb)
          ..registerSingleton<EntitiesCacheService>(mockEntitiesCacheService)
          ..registerSingleton<PersistenceLogic>(mockPersistenceLogic);
      },
    );

    when(
      () => mockEntitiesCacheService.getDataTypeById(measurableWater.id),
    ).thenAnswer((_) => measurableWater);
    when(
      () => mockJournalDb.getMeasurementsByType(
        rangeStart: any(named: 'rangeStart'),
        rangeEnd: any(named: 'rangeEnd'),
        type: measurableWater.id,
      ),
    ).thenAnswer((_) async => suggestionFixture());
  });

  tearDown(tearDownTestGetIt);

  testWidgets('measurement modal — empty, dark', (tester) async {
    await _pump(tester, brightness: Brightness.dark);
    await _capture(tester, '20_measurement_empty_dark');
  });

  testWidgets('measurement modal — empty, light', (tester) async {
    await _pump(tester, brightness: Brightness.light);
    await _capture(tester, '21_measurement_empty_light');
  });

  testWidgets('measurement modal — filled (save), dark', (tester) async {
    await _pump(tester, brightness: Brightness.dark, enterValue: '750');
    await _capture(tester, '22_measurement_filled_dark');
  });
}
