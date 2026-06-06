import 'package:flutter/material.dart';
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
}
