import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/tasks/model/task_progress_state.dart';
import 'package:lotti/features/tasks/state/task_progress_controller.dart';
import 'package:lotti/features/tasks/ui/linked_duration.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/time_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    if (!getIt.isRegistered<TimeService>()) {
      getIt.registerSingleton<TimeService>(TimeService());
    }
  });

  testWidgets('LinkedDuration text widths are stable', (tester) async {
    const taskId = 'task-ld-1';

    TaskProgressController makeController(
        Duration progress, Duration estimate) {
      return _FixedProgressController(progress: progress, estimate: estimate);
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

class _FixedProgressController extends TaskProgressController {
  _FixedProgressController({required this.progress, required this.estimate});

  final Duration progress;
  final Duration estimate;

  @override
  Future<TaskProgressState?> build({required String id}) async {
    return TaskProgressState(progress: progress, estimate: estimate);
  }
}
