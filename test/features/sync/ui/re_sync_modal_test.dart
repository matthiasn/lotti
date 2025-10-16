import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/maintenance.dart';
import 'package:lotti/features/sync/ui/re_sync_modal.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/widgets/buttons/lotti_secondary_button.dart';
import 'package:lotti/widgets/date_time/datetime_field.dart';
import 'package:mocktail/mocktail.dart';

import '../../../widget_test_utils.dart';

// ignore_for_file: avoid_redundant_argument_values

class MockMaintenance extends Mock implements Maintenance {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockMaintenance mockMaintenance;

  setUp(() {
    mockMaintenance = MockMaintenance();
    when(
      () => mockMaintenance.reSyncInterval(
        start: any(named: 'start'),
        end: any(named: 'end'),
      ),
    ).thenAnswer((_) async {});
  });

  testWidgets('starts re-sync with selected interval', (tester) async {
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        const ReSyncModalContent(),
        overrides: [
          maintenanceProvider.overrideWithValue(mockMaintenance),
        ],
      ),
    );

    await tester.pumpAndSettle();

    final dateFieldFinder = find.byType(DateTimeField);
    final fields = dateFieldFinder
        .evaluate()
        .map((element) => element.widget as DateTimeField);
    final start = DateTime(2024, 1, 1, 8, 0);
    final end = DateTime(2024, 1, 2, 18, 30);

    fields.first.setDateTime(start);
    fields.last.setDateTime(end);

    await tester.pump();

    final startButtonFinder =
        find.widgetWithText(LottiSecondaryButton, 'Start');
    expect(startButtonFinder, findsOneWidget);

    await tester.tap(startButtonFinder);
    await tester.pumpAndSettle();

    verify(
      () => mockMaintenance.reSyncInterval(
        start: start,
        end: end,
      ),
    ).called(1);
  });

  testWidgets('start button enabled with default dates', (tester) async {
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        const ReSyncModalContent(),
        overrides: [
          maintenanceProvider.overrideWithValue(mockMaintenance),
        ],
      ),
    );

    await tester.pumpAndSettle();

    final startButtonFinder =
        find.widgetWithText(LottiSecondaryButton, 'Start');
    expect(startButtonFinder, findsOneWidget);

    final startButton = tester.widget<LottiSecondaryButton>(startButtonFinder);
    expect(startButton.onPressed, isNotNull);
  });

  testWidgets('default dates set to last 24 hours', (tester) async {
    final testStartTime = DateTime.now();

    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        const ReSyncModalContent(),
        overrides: [
          maintenanceProvider.overrideWithValue(mockMaintenance),
        ],
      ),
    );

    await tester.pumpAndSettle();

    final dateFieldFinder = find.byType(DateTimeField);
    final fields = dateFieldFinder
        .evaluate()
        .map((element) => element.widget as DateTimeField)
        .toList();

    expect(fields.length, 2);

    final dateFrom = fields.first.dateTime;
    final dateTo = fields.last.dateTime;

    expect(dateFrom, isNotNull);
    expect(dateTo, isNotNull);

    // Verify dateFrom is approximately 24 hours before dateTo
    final difference = dateTo!.difference(dateFrom!);
    expect(difference.inHours, 24);
    expect(difference.inMinutes, closeTo(24 * 60, 1));

    // Verify dateTo is approximately now
    final timeDifferenceFromNow = testStartTime.difference(dateTo).abs();
    expect(
      timeDifferenceFromNow.inSeconds,
      lessThan(5),
      reason: 'dateTo should be very close to current time',
    );
  });
}
