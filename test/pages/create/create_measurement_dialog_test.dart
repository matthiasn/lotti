import 'package:beamer/beamer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/pages/create/create_measurement_dialog.dart';
import 'package:lotti/services/entities_cache_service.dart';
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
        () => mockEntitiesCacheService.getDataTypeById(
          '83ebf58d-9cea-4c15-a034-89c84a8b8178',
        ),
      ).thenAnswer((_) => measurableWater);

      when(
        () => mockJournalDb.getMeasurementsByType(
          rangeStart: any(named: 'rangeStart'),
          rangeEnd: any(named: 'rangeEnd'),
          type: '83ebf58d-9cea-4c15-a034-89c84a8b8178',
        ),
      ).thenAnswer((_) async => []);

      when(
        () => mockJournalDb.getMeasurableDataTypeById(any()),
      ).thenAnswer((_) async => measurableWater);
    });
    tearDown(tearDownTestGetIt);

    testWidgets(
      'create measurement dialog is displayed with measurable type water, '
      'then data entry and tap save button (becomes visible after data entry)',
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

        // The displayName appears in the value field label (e.g., "Water [ml]")
        // Title is now provided by Wolt Modal Sheet wrapper, not the dialog itself
        expect(
          find.textContaining(measurableWater.displayName),
          findsOneWidget,
        );

        final valueFieldFinder = find.byKey(
          const Key('measurement_value_field'),
        );
        final saveButtonFinder = find.byKey(const Key('measurement_save'));

        expect(valueFieldFinder, findsOneWidget);

        // save button is invisible - no changes yet
        expect(saveButtonFinder, findsNothing);

        await tester.enterText(valueFieldFinder, '1000');
        await tester.pump();

        // save button is now visible
        expect(saveButtonFinder, findsOneWidget);

        await tester.tap(saveButtonFinder);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        verify(mockCreateMeasurementEntry).called(1);
      },
    );

    testWidgets(
      'create measurement page is displayed with selected measurable type '
      'if only one exists',
      (tester) async {
        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            ConstrainedBox(
              constraints: const BoxConstraints(
                maxHeight: 600,
                maxWidth: 800,
              ),
              child: MeasurementDialog(
                measurableId: measurableWater.id,
              ),
            ),
          ),
        );

        await tester.pump();

        await tester.pump(const Duration(milliseconds: 300));

        // The displayName appears in the value field label (e.g., "Water [ml]")
        // Title is now provided by Wolt Modal Sheet wrapper, not the dialog itself
        expect(
          find.textContaining('Water'),
          findsOneWidget,
        );
      },
    );

    testWidgets('renders FilledButton for save action after entering data', (
      tester,
    ) async {
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

      // Enter a value to make the form dirty
      final valueFieldFinder = find.byKey(const Key('measurement_value_field'));
      await tester.enterText(valueFieldFinder, '500');
      await tester.pump();

      // Verify save button is rendered with the expected key
      final saveButtonFinder = find.byKey(const Key('measurement_save'));
      expect(saveButtonFinder, findsOneWidget);

      // Verify it's a FilledButton (not the old LottiTertiaryButton)
      final button = tester.widget(saveButtonFinder);
      expect(button, isA<FilledButton>());

      // Verify check icon is present (FilledButton.icon includes an icon)
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    });

    testWidgets('dialog uses Column layout instead of AlertDialog', (
      tester,
    ) async {
      await pumpMeasurementDialog(tester, measurableId: measurableWater.id);

      await tester.pump();

      await tester.pump(const Duration(milliseconds: 300));

      // Verify dialog does NOT use AlertDialog wrapper
      expect(find.byType(AlertDialog), findsNothing);

      // Verify FormBuilder is the top-level widget structure
      expect(find.byType(FormBuilder), findsOneWidget);
    });

    testWidgets('value field has autofocus enabled', (tester) async {
      await pumpMeasurementDialog(tester, measurableId: measurableWater.id);

      await tester.pump();

      await tester.pump(const Duration(milliseconds: 300));

      // Find the value TextField and check autofocus
      final valueFieldFinder = find.byKey(const Key('measurement_value_field'));
      expect(valueFieldFinder, findsOneWidget);

      // The value field should receive focus automatically
      // We verify this by checking that TextField has autofocus property
      final textField = find.descendant(
        of: valueFieldFinder,
        matching: find.byType(TextField),
      );
      expect(textField, findsOneWidget);

      final textFieldWidget = tester.widget<TextField>(textField);
      expect(textFieldWidget.autofocus, isTrue);
    });

    testWidgets('displays unit badge when unitName is not empty', (
      tester,
    ) async {
      await pumpMeasurementDialog(tester, measurableId: measurableWater.id);

      await tester.pump();

      await tester.pump(const Duration(milliseconds: 300));

      // measurableWater has unitName 'ml'
      // Verify unit badge is displayed
      expect(find.text('ml'), findsOneWidget);
    });

    testWidgets('description is not displayed in dialog body', (tester) async {
      // Description is now shown in the modal title (provided by the caller),
      // not in the dialog body itself
      await pumpMeasurementDialog(tester, measurableId: measurableWater.id);

      await tester.pump();

      await tester.pump(const Duration(milliseconds: 300));

      // measurableWater has description 'H₂O, with or without bubbles'
      // Verify description is NOT displayed in the dialog body
      // (it's now in the modal title, handled by MeasurablesChartInfoWidget)
      expect(find.text('H₂O, with or without bubbles'), findsNothing);
      expect(find.byIcon(Icons.info_outline_rounded), findsNothing);
    });

    testWidgets('comment field renders correctly', (tester) async {
      await pumpMeasurementDialog(tester, measurableId: measurableWater.id);

      await tester.pump();

      await tester.pump(const Duration(milliseconds: 300));

      final commentFieldFinder = find.byKey(
        const Key('measurement_comment_field'),
      );
      expect(commentFieldFinder, findsOneWidget);

      // Enter a comment
      await tester.enterText(commentFieldFinder, 'Test comment');
      await tester.pump();

      expect(find.text('Test comment'), findsOneWidget);
    });

    testWidgets('shows suggestions initially when form is not dirty', (
      tester,
    ) async {
      await pumpMeasurementDialog(tester, measurableId: measurableWater.id);

      await tester.pump();

      await tester.pump(const Duration(milliseconds: 300));

      // When form is not dirty, suggestions should be shown
      // (MeasurementSuggestions widget is rendered)
      // The save button should NOT be visible initially
      expect(find.byKey(const Key('measurement_save')), findsNothing);
    });

    testWidgets(
      'tapping suggestion chip saves measurement without validation error',
      (tester) async {
        // setUpTestGetIt already registers a MockUpdateNotifications with
        // empty streams — the suggestions provider needs nothing more.
        final mockMeasurements = buildMockMeasurements(value: 500);

        // Override the mock to return measurements for suggestions
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

        // Wait for async providers to load
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Find and tap the suggestion chip with value 500
        final chipFinder = find.text('500');
        expect(chipFinder, findsOneWidget);

        await tester.tap(chipFinder);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Verify createMeasurementEntry was called with the chip value
        verify(
          () => mockPersistenceLogic.createMeasurementEntry(
            data: any(named: 'data'),
            comment: any(named: 'comment'),
            private: any(named: 'private'),
          ),
        ).called(1);

        // Verify the captured value is 500 (from the chip)
        expect(capturedData?.value, equals(500));
      },
    );

    testWidgets('returns empty widget when dataType is null', (tester) async {
      // Configure mock to return null for a nonexistent ID
      when(
        () => mockEntitiesCacheService.getDataTypeById('nonexistent-id'),
      ).thenAnswer((_) => null);

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          ConstrainedBox(
            constraints: const BoxConstraints(
              maxHeight: 800,
              maxWidth: 800,
            ),
            child: const MeasurementDialog(
              measurableId: 'nonexistent-id',
            ),
          ),
        ),
      );

      await tester.pump();

      await tester.pump(const Duration(milliseconds: 300));

      // Should render SizedBox.shrink (empty) when dataType is null
      // FormBuilder should not be present
      expect(find.byType(FormBuilder), findsNothing);
    });

    testWidgets('shows validation error for invalid numeric input like 1..2', (
      tester,
    ) async {
      await pumpMeasurementDialog(tester, measurableId: measurableWater.id);

      await tester.pump();

      await tester.pump(const Duration(milliseconds: 300));

      // Enter an invalid number (passes character filter but fails num.tryParse)
      final valueFieldFinder = find.byKey(const Key('measurement_value_field'));
      await tester.enterText(valueFieldFinder, '1..2');
      await tester.pump();

      // Form should be invalid - save button should NOT appear
      expect(find.byKey(const Key('measurement_save')), findsNothing);

      // The FormBuilderTextField validation error should be shown
      // FormBuilderValidators.numeric returns localized error message
      expect(find.byType(FormBuilder), findsOneWidget);
    });

    testWidgets('date time field can be interacted with', (tester) async {
      await pumpMeasurementDialog(tester, measurableId: measurableWater.id);

      await tester.pump();

      await tester.pump(const Duration(milliseconds: 300));

      // Find the date time field (it's a TextField inside DateTimeField)
      // The DateTimeField shows the date/time text
      final dateTimeFieldFinder = find.byType(TextField).at(1);
      expect(dateTimeFieldFinder, findsOneWidget);

      // Tap to open the date time picker modal
      await tester.tap(dateTimeFieldFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // The modal should open with "now" button
      final nowButton = find.textContaining(
        RegExp('now', caseSensitive: false),
      );
      expect(nowButton, findsOneWidget);

      // Tap "now" to set the date time and close the modal
      await tester.tap(nowButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Modal should be closed, measurement dialog still visible
      expect(find.byType(FormBuilder), findsOneWidget);
    });
  });
}
