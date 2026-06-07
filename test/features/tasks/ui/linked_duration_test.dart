import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/tasks/model/task_progress_state.dart';
import 'package:lotti/features/tasks/state/task_progress_controller.dart';
import 'package:lotti/features/tasks/ui/linked_duration.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/time_service.dart';
import 'package:lotti/themes/colors.dart';

import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';

class _FixedProgressController extends TaskProgressController {
  _FixedProgressController({required this.fixedState});

  final TaskProgressState? fixedState;

  @override
  Future<TaskProgressState?> build({required String id}) async => fixedState;
}

void main() {
  const taskId = 'task-1';

  setUp(() {
    // TaskProgressController resolves TimeService in a field initializer,
    // even with build() overridden.
    getIt
      ..pushNewScope()
      ..registerSingleton<TimeService>(MockTimeService());
  });

  tearDown(() async {
    await getIt.popScope();
  });

  Future<void> pumpWith(WidgetTester tester, TaskProgressState? state) async {
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        const Scaffold(body: LinkedDuration(taskId: taskId)),
        overrides: [
          taskProgressControllerProvider(id: taskId).overrideWith(
            () => _FixedProgressController(fixedState: state),
          ),
        ],
      ),
    );
    // Async controller resolution + rebuild.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump();
  }

  LinearProgressIndicator bar(WidgetTester tester) =>
      tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );

  group('LinkedDuration', () {
    testWidgets('renders nothing when the state is null', (tester) async {
      await pumpWith(tester, null);

      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(find.byType(Text), findsNothing);
    });

    testWidgets('renders nothing for a zero estimate', (tester) async {
      await pumpWith(
        tester,
        const TaskProgressState(
          progress: Duration(minutes: 30),
          estimate: Duration.zero,
        ),
      );

      expect(find.byType(LinearProgressIndicator), findsNothing);
    });

    testWidgets('within estimate: green bar with proportional value', (
      tester,
    ) async {
      await pumpWith(
        tester,
        const TaskProgressState(
          progress: Duration(minutes: 30),
          estimate: Duration(hours: 1),
        ),
      );

      expect(bar(tester).value, closeTo(0.5, 1e-9));
      expect(bar(tester).color, successColor);
      // Progress and estimate render as formatted durations.
      expect(find.text('00:30:00'), findsOneWidget);
      expect(find.text('01:00:00'), findsOneWidget);
    });

    testWidgets('over estimate: bar clamps to 1.0 and switches to fail color', (
      tester,
    ) async {
      await pumpWith(
        tester,
        const TaskProgressState(
          progress: Duration(hours: 2),
          estimate: Duration(hours: 1),
        ),
      );

      expect(bar(tester).value, 1.0);
      expect(bar(tester).color, failColor);
    });
  });

  // Merged from the former *_timer_text_test.dart orphan (one
  // test file per source file).
  testWidgets('LinkedDuration text widths are stable', (tester) async {
    const taskId = 'task-ld-1';

    TaskProgressController makeController(
      Duration progress,
      Duration estimate,
    ) {
      return _FixedTimerTextProgressController(
        progress: progress,
        estimate: estimate,
      );
    }

    Future<void> pumpWith(
      Duration progress,
      Duration estimate,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            taskProgressControllerProvider(id: taskId).overrideWith(
              () => makeController(progress, estimate),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: LinkedDuration(taskId: taskId),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      // Ensure AsyncNotifier completes and rebuilds
      await tester.pump();
    }

    const estimate = Duration(hours: 1, minutes: 50);

    await pumpWith(const Duration(minutes: 41), estimate);
    final descFinder = find.descendant(
      of: find.byType(LinkedDuration),
      matching: find.byType(Text),
    );
    expect(descFinder, findsNWidgets(2));
    final w1a = tester.getSize(descFinder.at(0)).width;
    final w1b = tester.getSize(descFinder.at(1)).width;

    await pumpWith(const Duration(minutes: 48), estimate);
    expect(descFinder, findsNWidgets(2));
    final w2a = tester.getSize(descFinder.at(0)).width;
    final w2b = tester.getSize(descFinder.at(1)).width;

    expect(w1a, equals(w2a));
    expect(w1b, equals(w2b));
  });
}

class _FixedTimerTextProgressController extends TaskProgressController {
  _FixedTimerTextProgressController({
    required this.progress,
    required this.estimate,
  });

  final Duration progress;
  final Duration estimate;

  @override
  Future<TaskProgressState?> build({required String id}) async {
    return TaskProgressState(progress: progress, estimate: estimate);
  }
}
