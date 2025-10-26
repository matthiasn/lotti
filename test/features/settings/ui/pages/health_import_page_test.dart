import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/settings/ui/pages/health_import_page.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/health_import.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final mockHealthImport = MockHealthImport();

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
    tearDown(getIt.reset);

    testWidgets('page is displayed', (tester) async {
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

      final activityButtonFinder = find.text('Import Activity Data');
      expect(activityButtonFinder, findsOneWidget);

      final sleepButtonFinder = find.text('Import Sleep Data');
      expect(sleepButtonFinder, findsOneWidget);

      final heartRateButtonFinder = find.text('Import Heart Rate Data');
      expect(heartRateButtonFinder, findsOneWidget);

      final bpButtonFinder = find.text('Import Blood Pressure Data');
      expect(bpButtonFinder, findsOneWidget);

      final bodyButtonFinder = find.text('Import Body Measurement Data');
      expect(bodyButtonFinder, findsOneWidget);

      final workoutButtonFinder = find.text('Import Workout Data');
      expect(workoutButtonFinder, findsOneWidget);

      await tester.tap(activityButtonFinder);

      verify(
        () => mockHealthImport.getActivityHealthData(
          dateFrom: any(named: 'dateFrom'),
          dateTo: any(named: 'dateTo'),
        ),
      ).called(1);

      await tester.tap(sleepButtonFinder);
      verify(
        () => mockHealthImport.fetchHealthData(
          dateFrom: any(named: 'dateFrom'),
          dateTo: any(named: 'dateTo'),
          types: any(named: 'types'),
        ),
      ).called(1);

      await tester.tap(heartRateButtonFinder);
      await tester.tap(bpButtonFinder);

      await tester.ensureVisible(bodyButtonFinder);
      await tester.pumpAndSettle();
      await tester.tap(bodyButtonFinder);

      await tester.ensureVisible(workoutButtonFinder);
      await tester.pumpAndSettle();
      await tester.tap(workoutButtonFinder);
    });
  });
}
