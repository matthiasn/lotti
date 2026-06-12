import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/design_system/components/glass_action_bar.dart';
import 'package:lotti/features/settings/ui/pages/measurables/measurable_details_page.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../mocks/mocks.dart';
import '../../../../../test_data/test_data.dart';
import '../../../../../widget_test_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockPersistenceLogic mockPersistenceLogic;
  String? beamedTo;

  setUpAll(() {
    registerFallbackValue(FakeMeasurableDataType());
  });

  setUp(() async {
    mockPersistenceLogic = MockPersistenceLogic();

    await setUpTestGetIt(
      additionalSetup: () {
        // EditMeasurablePage resolves JournalDb at construction time, so
        // replace the helper's bare mock with one stubbed for measurables.
        getIt
          ..unregister<JournalDb>()
          ..registerSingleton<JournalDb>(
            mockJournalDbWithMeasurableTypes([
              measurableWater,
              measurableChocolate,
            ]),
          )
          ..registerSingleton<PersistenceLogic>(mockPersistenceLogic);
      },
    );

    when(
      () => mockPersistenceLogic.upsertEntityDefinition(any()),
    ).thenAnswer((_) async => 1);

    // Back/cancel/save/delete beam to the list route (V2's desktop detail
    // surface mounts the page inline; there is no Navigator route to pop).
    beamedTo = null;
    beamToNamedOverride = (path) => beamedTo = path;
  });

  tearDown(() async {
    beamToNamedOverride = null;
    await tearDownTestGetIt();
  });

  /// Pumps [child] on a tall surface so the whole form including the
  /// sticky action bar is hittable, then drains the initial frames.
  Future<void> pumpPage(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        child,
        mediaQueryData: const MediaQueryData(size: Size(1200, 1600)),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  DsGlassPill saveAction(WidgetTester tester) => tester.widget<DsGlassPill>(
    find.widgetWithText(DsGlassPill, 'Save'),
  );

  MeasurableDataType capturedUpsert() {
    final captured = verify(
      () => mockPersistenceLogic.upsertEntityDefinition(captureAny()),
    ).captured;
    return captured.last as MeasurableDataType;
  }

  group('MeasurableDetailsPage', () {
    testWidgets(
      'edit mode seeds fields, gates Save on dirty, persists edited values, '
      'and beams to the measurables list',
      (tester) async {
        await pumpPage(
          tester,
          MeasurableDetailsPage(dataType: measurableWater),
        );

        // Seeded from the passed-in data type.
        expect(find.text('Water'), findsOneWidget);
        expect(find.text('H₂O, with or without bubbles'), findsOneWidget);
        expect(find.text('ml'), findsOneWidget);

        // Save pill renders disabled while the form is clean.
        expect(saveAction(tester).enabled, isFalse);

        await tester.enterText(
          find.byKey(const Key('measurable_name_field')),
          'Sparkling water',
        );
        await tester.pump();

        expect(saveAction(tester).enabled, isTrue);

        await tester.tap(find.widgetWithText(DsGlassPill, 'Save'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        final saved = capturedUpsert();
        expect(saved.id, measurableWater.id);
        expect(saved.displayName, 'Sparkling water');
        // Untouched fields keep their seeded values through the save.
        expect(saved.description, 'H₂O, with or without bubbles');
        expect(saved.unitName, 'ml');
        expect(saved.aggregationType, AggregationType.dailySum);
        expect(beamedTo, '/settings/measurables');
      },
    );

    testWidgets(
      'toggling the private and favorite switches and picking another '
      'aggregation type in the modal persists all three',
      (tester) async {
        await pumpPage(
          tester,
          MeasurableDetailsPage(dataType: measurableWater),
        );

        // The aggregation picker renders the localized name, never the raw
        // enum identifier.
        expect(find.text('Daily sum'), findsOneWidget);
        expect(find.text('dailySum'), findsNothing);

        // The whole switch row is tappable; hit it via its title.
        final switchFinder = find.text('Private');
        await tester.ensureVisible(switchFinder);
        await tester.pump();
        await tester.tap(switchFinder);
        await tester.pump();

        final favoriteFinder = find.text('Favorite');
        await tester.ensureVisible(favoriteFinder);
        await tester.pump();
        await tester.tap(favoriteFinder);
        await tester.pump();

        // Tapping the picker field opens the single-page modal listing the
        // localized aggregation names.
        final pickerFinder = find.byKey(
          const Key('measurable_aggregation_field'),
        );
        await tester.ensureVisible(pickerFinder);
        await tester.pump();
        await tester.tap(pickerFinder);
        await tester.pumpAndSettle();

        expect(find.text('Daily average'), findsOneWidget);
        expect(find.text('Hourly sum'), findsOneWidget);

        await tester.tap(find.text('Daily maximum'));
        await tester.pumpAndSettle();

        // The picker now shows the newly selected localized name.
        expect(find.text('Daily maximum'), findsOneWidget);
        expect(find.text('Daily sum'), findsNothing);

        await tester.tap(find.widgetWithText(DsGlassPill, 'Save'));
        await tester.pump();

        final saved = capturedUpsert();
        expect(saved.private, isTrue);
        expect(saved.favorite, isTrue);
        expect(saved.aggregationType, AggregationType.dailyMax);
      },
    );

    testWidgets(
      'saving an unrelated edit preserves a seeded favorite flag',
      (tester) async {
        await pumpPage(
          tester,
          MeasurableDetailsPage(
            dataType: measurableWater.copyWith(favorite: true),
          ),
        );

        await tester.enterText(
          find.byKey(const Key('measurable_name_field')),
          'Sparkling water',
        );
        await tester.pump();

        await tester.tap(find.widgetWithText(DsGlassPill, 'Save'));
        await tester.pump();

        // The favorite switch carries the seeded value through the save
        // instead of silently resetting it to false.
        final saved = capturedUpsert();
        expect(saved.displayName, 'Sparkling water');
        expect(saved.favorite, isTrue);
      },
    );

    testWidgets(
      'delete flow confirms via the action sheet, soft-deletes the '
      'measurable, and beams to the measurables list',
      (tester) async {
        await pumpPage(
          tester,
          MeasurableDetailsPage(dataType: measurableWater),
        );

        await tester.tap(find.widgetWithText(DsGlassPill, 'Delete'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        expect(
          find.text('Do you want to delete this measurable data type?'),
          findsOneWidget,
        );

        await tester.tap(find.text('YES, DELETE THIS MEASURABLE'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        final saved = capturedUpsert();
        expect(saved.id, measurableWater.id);
        expect(saved.deletedAt, isNotNull);
        expect(beamedTo, '/settings/measurables');
      },
    );

    testWidgets(
      'back arrow and Cancel beam to the measurables list without saving',
      (tester) async {
        await pumpPage(
          tester,
          MeasurableDetailsPage(dataType: measurableWater),
        );

        await tester.tap(find.byIcon(Icons.chevron_left));
        await tester.pump();
        expect(beamedTo, '/settings/measurables');

        beamedTo = null;
        await tester.tap(find.widgetWithText(DsGlassPill, 'Cancel'));
        await tester.pump();
        expect(beamedTo, '/settings/measurables');

        verifyNever(() => mockPersistenceLogic.upsertEntityDefinition(any()));
      },
    );

    testWidgets(
      'Ctrl+S only saves once the form is dirty',
      (tester) async {
        await pumpPage(
          tester,
          MeasurableDetailsPage(dataType: measurableWater),
        );

        // Focus the form without changing any value.
        await tester.tap(find.byKey(const Key('measurable_name_field')));
        await tester.pump();

        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        await tester.pump();

        verifyNever(() => mockPersistenceLogic.upsertEntityDefinition(any()));

        await tester.enterText(
          find.byKey(const Key('measurable_name_field')),
          'Still water',
        );
        await tester.pump();

        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(capturedUpsert().displayName, 'Still water');
        expect(beamedTo, '/settings/measurables');
      },
    );

    testWidgets(
      'edit page resolves the measurable by id and seeds the form',
      (tester) async {
        await pumpPage(
          tester,
          EditMeasurablePage(measurableId: measurableWater.id),
        );

        expect(find.text('Water'), findsOneWidget);
        expect(find.text('Edit measurable'), findsOneWidget);
        // Delete pill present in edit mode.
        expect(find.widgetWithText(DsGlassPill, 'Delete'), findsOneWidget);
      },
    );

    testWidgets(
      'edit page falls back to the not-found scaffold for an unknown id',
      (tester) async {
        await pumpPage(
          tester,
          EditMeasurablePage(measurableId: 'unknown-id'),
        );

        expect(find.text('Measurable not found'), findsOneWidget);
        expect(find.byType(DsGlassPill), findsNothing);
      },
    );
  });
}
