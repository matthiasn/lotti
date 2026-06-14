import 'package:beamer/beamer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/pages/create/create_measurement_dialog.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/widgets/create/suggest_measurement.dart';
import 'package:mocktail/mocktail.dart';

import '../../mocks/mocks.dart';
import '../../test_data/test_data.dart';
import '../../widget_test_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  var mockJournalDb = MockJournalDb();
  var mockPersistenceLogic = MockPersistenceLogic();
  final mockEntitiesCacheService = MockEntitiesCacheService();

  /// Two measurements sharing [value] on the test day — the fixture the
  /// suggestion chips aggregate over.
  List<MeasurementEntry> buildMockMeasurements({required num value}) {
    MeasurementEntry entry(String id, DateTime at) => MeasurementEntry(
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
      entry('test-1', DateTime(2024, 3, 15, 10, 30)),
      entry('test-2', DateTime(2024, 3, 15, 14, 45)),
    ];
  }

  /// The Save button as a [DesignSystemButton]; `onPressed == null` means
  /// disabled (the value is not yet a valid number).
  DesignSystemButton saveButton(WidgetTester tester) =>
      tester.widget<DesignSystemButton>(
        find.byKey(const Key('measurement_save')),
      );

  /// Pumps the dialog inside the shared Beamer + scaffold harness.
  Future<void> pumpMeasurementDialog(
    WidgetTester tester, {
    required String measurableId,
  }) async {
    final delegate = BeamerDelegate(
      locationBuilder: RoutesLocationBuilder(
        routes: {
          '/': (context, state, data) => Container(),
        },
      ).call,
    );

    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        BeamerProvider(
          routerDelegate: delegate,
          child: Material(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxHeight: 800,
                maxWidth: 800,
              ),
              child: MeasurementDialog(measurableId: measurableId),
            ),
          ),
        ),
      ),
    );
  }

  group('MeasurementDialog Widget Tests - ', () {
    setUpAll(() {
      registerFallbackValue(FakeMeasurementData());
    });

    setUp(() async {
      mockJournalDb = mockJournalDbWithMeasurableTypes([
        measurableWater,
        measurableChocolate,
      ]);
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
      ).thenAnswer((_) async => []);

      when(
        () => mockJournalDb.getMeasurableDataTypeById(any()),
      ).thenAnswer((_) async => measurableWater);
    });
    tearDown(tearDownTestGetIt);

    testWidgets(
      'renders the hero value field, unit, observed-at and a Save button that '
      'enables only once a valid value is entered, then saves',
      (tester) async {
        Future<MeasurementEntry?> mockCreateMeasurementEntry() {
          return mockPersistenceLogic.createMeasurementEntry(
            data: any(named: 'data'),
            comment: any(named: 'comment'),
            private: false,
          );
        }

        when(mockCreateMeasurementEntry).thenAnswer((_) async => null);

        await pumpMeasurementDialog(tester, measurableId: measurableWater.id);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Value field is the hero and the unit reads alongside it.
        expect(
          find.byKey(const Key('measurement_value_field')),
          findsOneWidget,
        );
        expect(find.text(measurableWater.unitName), findsOneWidget);

        // Save is always present but disabled until a valid value is entered.
        expect(find.byKey(const Key('measurement_save')), findsOneWidget);
        expect(saveButton(tester).onPressed, isNull);

        await tester.enterText(
          find.byKey(const Key('measurement_value_field')),
          '1000',
        );
        await tester.pump();

        // Now enabled.
        expect(saveButton(tester).onPressed, isNotNull);

        await tester.tap(find.byKey(const Key('measurement_save')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        verify(mockCreateMeasurementEntry).called(1);
      },
    );

    testWidgets('renders the measurable display name in the value field area', (
      tester,
    ) async {
      await pumpMeasurementDialog(tester, measurableId: measurableWater.id);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // The unit is surfaced even before the title is added by the modal
      // wrapper.
      expect(find.text('ml'), findsOneWidget);
    });

    testWidgets('Save is a DesignSystemButton with a check icon', (
      tester,
    ) async {
      await pumpMeasurementDialog(tester, measurableId: measurableWater.id);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byKey(const Key('measurement_save')), findsOneWidget);
      expect(saveButton(tester).leadingIcon, Icons.check_rounded);
    });

    testWidgets('value field has autofocus enabled', (tester) async {
      await pumpMeasurementDialog(tester, measurableId: measurableWater.id);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final textField = tester.widget<TextField>(
        find.byKey(const Key('measurement_value_field')),
      );
      expect(textField.autofocus, isTrue);
    });

    testWidgets('description is not displayed in dialog body', (tester) async {
      // Description is shown in the modal title (provided by the caller), not
      // in the dialog body itself.
      await pumpMeasurementDialog(tester, measurableId: measurableWater.id);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('H₂O, with or without bubbles'), findsNothing);
    });

    testWidgets('comment field renders and accepts input', (tester) async {
      await pumpMeasurementDialog(tester, measurableId: measurableWater.id);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final commentFieldFinder = find.byKey(
        const Key('measurement_comment_field'),
      );
      expect(commentFieldFinder, findsOneWidget);

      await tester.enterText(commentFieldFinder, 'Test comment');
      await tester.pump();

      expect(find.text('Test comment'), findsOneWidget);
    });

    testWidgets('quick-add chips are hidden when there is no history', (
      tester,
    ) async {
      await pumpMeasurementDialog(tester, measurableId: measurableWater.id);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // No prior measurements -> no suggestions rendered.
      expect(find.byType(MeasurementSuggestions), findsOneWidget);
      expect(find.text('Quick add'), findsNothing);
    });

    testWidgets(
      'tapping a quick-add chip logs the value (with unit) immediately',
      (tester) async {
        final mockMeasurements = buildMockMeasurements(value: 500);
        when(
          () => mockJournalDb.getMeasurementsByType(
            rangeStart: any(named: 'rangeStart'),
            rangeEnd: any(named: 'rangeEnd'),
            type: measurableWater.id,
          ),
        ).thenAnswer((_) async => mockMeasurements);

        MeasurementData? capturedData;
        when(
          () => mockPersistenceLogic.createMeasurementEntry(
            data: any(named: 'data'),
            comment: any(named: 'comment'),
            private: any(named: 'private'),
          ),
        ).thenAnswer((invocation) async {
          capturedData =
              invocation.namedArguments[const Symbol('data')]
                  as MeasurementData;
          return null;
        });

        await pumpMeasurementDialog(tester, measurableId: measurableWater.id);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // The chip is self-describing: value + unit.
        expect(find.text('Quick add'), findsOneWidget);
        final chipFinder = find.text('500 ml');
        expect(chipFinder, findsOneWidget);

        await tester.tap(chipFinder);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        verify(
          () => mockPersistenceLogic.createMeasurementEntry(
            data: any(named: 'data'),
            comment: any(named: 'comment'),
            private: any(named: 'private'),
          ),
        ).called(1);
        expect(capturedData?.value, equals(500));
      },
    );

    testWidgets('returns empty widget when dataType is null', (tester) async {
      when(
        () => mockEntitiesCacheService.getDataTypeById('nonexistent-id'),
      ).thenAnswer((_) => null);

      await pumpMeasurementDialog(tester, measurableId: 'nonexistent-id');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Nothing actionable renders for an unknown measurable.
      expect(find.byKey(const Key('measurement_value_field')), findsNothing);
      expect(find.byKey(const Key('measurement_save')), findsNothing);
    });

    testWidgets('Save stays disabled for invalid numeric input like 1..2', (
      tester,
    ) async {
      await pumpMeasurementDialog(tester, measurableId: measurableWater.id);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.enterText(
        find.byKey(const Key('measurement_value_field')),
        '1..2',
      );
      await tester.pump();

      // The character filter allows it, but it does not parse to a number, so
      // Save remains disabled.
      expect(saveButton(tester).onPressed, isNull);
    });

    testWidgets('observed-at row opens the date/time picker on tap', (
      tester,
    ) async {
      await pumpMeasurementDialog(tester, measurableId: measurableWater.id);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.byKey(const Key('measurement_observed_at')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // The shared picker modal exposes a "now" reset control.
      final nowButton = find.textContaining(
        RegExp('now', caseSensitive: false),
      );
      expect(nowButton, findsOneWidget);

      await tester.tap(nowButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Back on the dialog: the value field is still present.
      expect(find.byKey(const Key('measurement_value_field')), findsOneWidget);
    });
  });
}
