import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/tasks/ui/header/estimated_time_widget.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/time_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';
import '../../../../test_helper.dart';
import '../../../../widget_test_utils.dart';

void main() {
  late MockTimeService mockTimeService;

  setUp(() async {
    mockTimeService = MockTimeService();

    when(
      () => mockTimeService.getStream(),
    ).thenAnswer((_) => Stream<JournalEntity?>.fromIterable([]));
    when(() => mockTimeService.linkedFrom).thenReturn(null);

    await setUpTestGetIt(
      additionalSetup: () {
        getIt.registerSingleton<TimeService>(mockTimeService);
      },
    );
  });

  tearDown(tearDownTestGetIt);

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

      expect(find.text('Estimate'), findsOneWidget);
      expect(find.text('Estimate:'), findsNothing);
      expect(find.text('Clear'), findsOneWidget);
      final picker = tester.widget<CupertinoTimerPicker>(
        find.byType(CupertinoTimerPicker),
      );
      expect(picker.itemExtent, 48);
      expect(picker.selectionOverlayBuilder, isNotNull);

      // Without changing the picker value, tapping Done should not call callback.
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      expect(callbackCalled, isFalse);
    },
  );

  testWidgets(
    'zero initial estimate: picker opens at zero and Done without a change '
    'does not invoke the callback',
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
                        initialDuration: Duration.zero,
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

      final picker = tester.widget<CupertinoTimerPicker>(
        find.byType(CupertinoTimerPicker),
      );
      expect(picker.initialTimerDuration, Duration.zero);
      expect(find.text('Clear'), findsNothing);

      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      expect(callbackCalled, isFalse);
    },
  );

  testWidgets('showEstimatePicker calls callback when duration changes', (
    tester,
  ) async {
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

  testWidgets('Clear resets a non-zero estimate without wheel manipulation', (
    tester,
  ) async {
    Duration? selected;

    await tester.pumpWidget(
      WidgetTestBench(
        child: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showEstimatePicker(
                  context: context,
                  initialDuration: const Duration(minutes: 30),
                  onEstimateChanged: (duration) async => selected = duration,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clear'));
    await tester.pumpAndSettle();

    expect(selected, Duration.zero);
    expect(find.text('Estimate'), findsNothing);
  });
}
