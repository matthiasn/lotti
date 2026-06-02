import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health/health.dart';
import 'package:lotti/features/settings/ui/pages/health_import_page.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/health_import.dart';
import 'package:lotti/widgets/date_time/datetime_field.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final mockHealthImport = MockHealthImport();

  Future<void> pumpPage(WidgetTester tester) async {
    await tester.pumpWidget(
      makeTestableWidget2(
        ConstrainedBox(
          constraints: const BoxConstraints(
            maxHeight: 1200,
            maxWidth: 1000,
          ),
          child: const HealthImportPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Returns the `setDateTime` callback of the [DateTimeField] whose label
  /// matches [labelText]. Driving this callback exercises the page's
  /// `setState` handlers (the uncovered lines) deterministically without
  /// relying on the Cupertino picker wheels.
  void Function(DateTime) setDateTimeFor(
    WidgetTester tester,
    String labelText,
  ) {
    final field = tester.widget<DateTimeField>(
      find.byWidgetPredicate(
        (w) => w is DateTimeField && w.labelText == labelText,
      ),
    );
    return field.setDateTime;
  }

  group('HealthImportPage Widget Tests - ', () {
    setUp(() {
      getIt
        ..registerSingleton<HealthImport>(mockHealthImport)
        ..registerSingleton<UserActivityService>(UserActivityService());

      when(
        () => mockHealthImport.getActivityHealthData(
          dateFrom: any(named: 'dateFrom'),
          dateTo: any(named: 'dateTo'),
        ),
      ).thenAnswer((invocation) async {});

      when(
        () => mockHealthImport.fetchHealthData(
          dateFrom: any(named: 'dateFrom'),
          dateTo: any(named: 'dateTo'),
          types: any(named: 'types'),
        ),
      ).thenAnswer((invocation) async {});

      when(
        () => mockHealthImport.getWorkoutsHealthData(
          dateFrom: any(named: 'dateFrom'),
          dateTo: any(named: 'dateTo'),
        ),
      ).thenAnswer((invocation) async {});
    });
    tearDown(() async {
      reset(mockHealthImport);
      await getIt.reset();
    });

    testWidgets('import buttons delegate to HealthImport with the date range', (
      tester,
    ) async {
      await pumpPage(tester);

      // Pin both date fields to deterministic, distinct values so the
      // delegated calls can be asserted exactly.
      final dateFrom = DateTime(2024, 3, 15);
      final dateTo = DateTime(2024, 3, 22);
      setDateTimeFor(tester, 'Start')(dateFrom);
      setDateTimeFor(tester, 'End')(dateTo);
      await tester.pumpAndSettle();

      // Activity import -> getActivityHealthData with the exact range.
      await tester.tap(find.text('Import Activity Data'));
      verify(
        () => mockHealthImport.getActivityHealthData(
          dateFrom: dateFrom,
          dateTo: dateTo,
        ),
      ).called(1);

      // Each typed import -> fetchHealthData with the matching type list.
      final typedImports = <String, List<HealthDataType>>{
        'Import Sleep Data': sleepTypes,
        'Import Heart Rate Data': heartRateTypes,
        'Import Blood Pressure Data': bpTypes,
        'Import Body Measurement Data': bodyMeasurementTypes,
      };

      for (final entry in typedImports.entries) {
        final finder = find.text(entry.key);
        await tester.ensureVisible(finder);
        await tester.pumpAndSettle();
        await tester.tap(finder);
        verify(
          () => mockHealthImport.fetchHealthData(
            dateFrom: dateFrom,
            dateTo: dateTo,
            types: entry.value,
          ),
        ).called(1);
      }

      // Workout import -> getWorkoutsHealthData with the exact range.
      final workoutFinder = find.text('Import Workout Data');
      await tester.ensureVisible(workoutFinder);
      await tester.pumpAndSettle();
      await tester.tap(workoutFinder);
      verify(
        () => mockHealthImport.getWorkoutsHealthData(
          dateFrom: dateFrom,
          dateTo: dateTo,
        ),
      ).called(1);
    });

    testWidgets(
      'setting the start date updates the displayed value and range',
      (
        tester,
      ) async {
        await pumpPage(tester);

        const newStart = '2024-03-15';
        expect(find.text(newStart), findsNothing);

        setDateTimeFor(tester, 'Start')(DateTime(2024, 3, 15));
        await tester.pumpAndSettle();

        // The start field now renders the new date...
        expect(find.text(newStart), findsOneWidget);

        // ...and the new start date flows through to the delegated import call.
        await tester.tap(find.text('Import Activity Data'));
        verify(
          () => mockHealthImport.getActivityHealthData(
            dateFrom: DateTime(2024, 3, 15),
            dateTo: any(named: 'dateTo'),
          ),
        ).called(1);
      },
    );

    testWidgets('setting the end date updates the displayed value and range', (
      tester,
    ) async {
      await pumpPage(tester);

      const newEnd = '2024-03-20';
      expect(find.text(newEnd), findsNothing);

      setDateTimeFor(tester, 'End')(DateTime(2024, 3, 20));
      await tester.pumpAndSettle();

      // The end field now renders the new date...
      expect(find.text(newEnd), findsOneWidget);

      // ...and the new end date flows through to the delegated import call.
      await tester.tap(find.text('Import Activity Data'));
      verify(
        () => mockHealthImport.getActivityHealthData(
          dateFrom: any(named: 'dateFrom'),
          dateTo: DateTime(2024, 3, 20),
        ),
      ).called(1);
    });
  });
}
