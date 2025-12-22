import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/tasks/ui/header/estimated_time_widget.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/time_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../test_helper.dart';

class MockTimeService extends Mock implements TimeService {}

void main() {
  late MockTimeService mockTimeService;

  setUp(() {
    mockTimeService = MockTimeService();
    getIt.registerSingleton<TimeService>(mockTimeService);

    when(() => mockTimeService.getStream())
        .thenAnswer((_) => Stream<JournalEntity?>.fromIterable([]));
    when(() => mockTimeService.linkedFrom).thenReturn(null);
  });

  tearDown(getIt.reset);

  testWidgets(
      'showEstimatePicker does not call callback when duration unchanged',
      (tester) async {
    var callbackCalled = false;

    await tester.pumpWidget(
      WidgetTestBench(
        child: Builder(
          builder: (context) {
            return Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () {
                    showEstimatePicker(
                      context: context,
                      initialDuration: const Duration(hours: 2),
                      onEstimateChanged: (newDuration) async {
                        callbackCalled = true;
                      },
                    );
                  },
                  child: const Text('open'),
                ),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // Without changing the picker value, tapping Done should not call callback.
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(callbackCalled, isFalse);
  });

  testWidgets('showEstimatePicker calls callback when duration changes',
      (tester) async {
    Duration? selected;

    await tester.pumpWidget(
      WidgetTestBench(
        child: Builder(
          builder: (context) {
            return Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () {
                    showEstimatePicker(
                      context: context,
                      initialDuration: const Duration(hours: 2),
                      onEstimateChanged: (newDuration) async {
                        selected = newDuration;
                      },
                    );
                  },
                  child: const Text('open'),
                ),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // Simulate the user changing the duration in the picker.
    final picker = tester.widget<CupertinoTimerPicker>(
      find.byType(CupertinoTimerPicker),
    );
    picker.onTimerDurationChanged(const Duration(hours: 3));

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(selected, equals(const Duration(hours: 3)));
  });
}
