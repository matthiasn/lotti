import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/design_system/components/glass_action_bar.dart';
import 'package:lotti/features/settings/ui/pages/measurables/measurable_create_page.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/widgets/settings/settings_delete_row.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../mocks/mocks.dart';
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
        getIt.registerSingleton<PersistenceLogic>(mockPersistenceLogic);
      },
    );

    when(
      () => mockPersistenceLogic.upsertEntityDefinition(any()),
    ).thenAnswer((_) async => 1);

    beamedTo = null;
    beamToNamedOverride = (path) => beamedTo = path;
  });

  tearDown(() async {
    beamToNamedOverride = null;
    await tearDownTestGetIt();
  });

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

  group('CreateMeasurablePage', () {
    testWidgets(
      'mounts the details page in create mode: create title, no delete '
      'affordance, Create gated on dirty, and a filled form persists the '
      'new measurable',
      (tester) async {
        await pumpPage(tester, CreateMeasurablePage());

        expect(find.text('Create measurable'), findsOneWidget);
        expect(find.widgetWithText(SettingsDeleteRow, 'Delete'), findsNothing);

        // An unset aggregation type renders the localized hint, never a
        // raw enum identifier.
        expect(find.text('None'), findsOneWidget);

        final createFinder = find.widgetWithText(DsGlassPill, 'Create');
        expect(tester.widget<DsGlassPill>(createFinder).enabled, isFalse);

        await tester.enterText(
          find.byKey(const Key('measurable_name_field')),
          'Steps',
        );
        await tester.pump();

        expect(tester.widget<DsGlassPill>(createFinder).enabled, isTrue);

        await tester.tap(createFinder);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        final saved =
            verify(
                  () => mockPersistenceLogic.upsertEntityDefinition(
                    captureAny(),
                  ),
                ).captured.single
                as MeasurableDataType;
        expect(saved.displayName, 'Steps');
        // Untouched switches and picker persist their pristine defaults.
        expect(saved.favorite, isFalse);
        expect(saved.private, isFalse);
        expect(saved.aggregationType, isNull);
        expect(beamedTo, '/settings/measurables');
      },
    );
  });
}
