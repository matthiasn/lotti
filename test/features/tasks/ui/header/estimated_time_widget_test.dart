import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/design_system/components/chips/ds_pill.dart';
import 'package:lotti/features/tasks/state/task_estimate_suggestions_controller.dart';
import 'package:lotti/features/tasks/ui/header/estimate_quick_pick_chips.dart';
import 'package:lotti/features/tasks/ui/header/estimated_time_widget.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/time_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';
import '../../../../test_helper.dart';
import '../../../../widget_test_utils.dart';

/// A fixed quick-pick row, so the picker's tests state the chips they act on
/// rather than depending on what a database would rank.
class _FixedSuggestions extends TaskEstimateSuggestionsController {
  @override
  Future<List<Duration>> build() async => const [
    Duration(minutes: 30),
    Duration(hours: 1),
    Duration(hours: 2),
    Duration(hours: 4),
  ];
}

void main() {
  late MockTimeService mockTimeService;

  List<Override> quickPickOverrides() => [
    taskEstimateSuggestionsControllerProvider.overrideWith(
      _FixedSuggestions.new,
    ),
  ];

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

  group('quick-pick chips', () {
    Future<Duration?> openAndTap(
      WidgetTester tester, {
      required Duration initialDuration,
      required String chipLabel,
    }) async {
      Duration? saved;
      await tester.pumpWidget(
        WidgetTestBench(
          overrides: quickPickOverrides(),
          child: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => showEstimatePicker(
                    context: context,
                    initialDuration: initialDuration,
                    onEstimateChanged: (duration) async => saved = duration,
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
      await tester.tap(find.text(chipLabel));
      await tester.pumpAndSettle();
      return saved;
    }

    testWidgets('a chip tap writes the estimate and closes the modal', (
      tester,
    ) async {
      final saved = await openAndTap(
        tester,
        initialDuration: const Duration(hours: 1),
        chipLabel: '2h',
      );

      expect(saved, const Duration(hours: 2));
      expect(find.byType(CupertinoTimerPicker), findsNothing);
      expect(find.text('Done'), findsNothing);
    });

    testWidgets(
      'the chip already holding the estimate closes without a write',
      (tester) async {
        // Re-writing the value the task already has would push an unnecessary
        // update — and a sync message — for a tap that changed nothing.
        final saved = await openAndTap(
          tester,
          initialDuration: const Duration(hours: 1),
          chipLabel: '1h',
        );

        expect(saved, isNull);
        expect(find.byType(CupertinoTimerPicker), findsNothing);
      },
    );

    testWidgets('a chip sets an estimate on a task that had none', (
      tester,
    ) async {
      final saved = await openAndTap(
        tester,
        initialDuration: Duration.zero,
        chipLabel: '30m',
      );

      expect(saved, const Duration(minutes: 30));
    });

    testWidgets('the chip row sits above the wheel, not beside the actions', (
      tester,
    ) async {
      await tester.pumpWidget(
        WidgetTestBench(
          overrides: quickPickOverrides(),
          child: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => showEstimatePicker(
                    context: context,
                    initialDuration: const Duration(hours: 1),
                    onEstimateChanged: (_) async {},
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

      expect(find.byType(EstimateQuickPickChips), findsOneWidget);
      expect(find.byType(DsPill), findsNWidgets(4));
      expect(
        tester.getRect(find.byType(EstimateQuickPickChips)).bottom,
        lessThan(tester.getRect(find.byType(CupertinoTimerPicker)).top),
        reason: 'the cheap path is met before the fallback',
      );
    });

    testWidgets('spinning the wheel moves the selected chip with it', (
      tester,
    ) async {
      // The row and the wheel must never state two different estimates: the
      // chips track the wheel's draft, not the value the modal opened on.
      await tester.pumpWidget(
        WidgetTestBench(
          overrides: quickPickOverrides(),
          child: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => showEstimatePicker(
                    context: context,
                    initialDuration: const Duration(hours: 1),
                    onEstimateChanged: (_) async {},
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

      DsPill pillOf(String label) => tester.widget<DsPill>(
        find.ancestor(of: find.text(label), matching: find.byType(DsPill)),
      );
      expect(pillOf('1h').selected, isTrue);

      tester
          .widget<CupertinoTimerPicker>(find.byType(CupertinoTimerPicker))
          .onTimerDurationChanged(const Duration(hours: 4));
      await tester.pumpAndSettle();

      expect(pillOf('4h').selected, isTrue);
      expect(pillOf('1h').selected, isFalse);
    });

    testWidgets('the wheel path still commits through Done', (tester) async {
      // The chips do not replace the wheel; an off-ladder value still works.
      Duration? saved;
      await tester.pumpWidget(
        WidgetTestBench(
          overrides: quickPickOverrides(),
          child: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => showEstimatePicker(
                    context: context,
                    initialDuration: const Duration(hours: 1),
                    onEstimateChanged: (duration) async => saved = duration,
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

      tester
          .widget<CupertinoTimerPicker>(find.byType(CupertinoTimerPicker))
          .onTimerDurationChanged(const Duration(minutes: 47));
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      expect(saved, const Duration(minutes: 47));
    });
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
