import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/tasks/model/task_progress_state.dart';
import 'package:lotti/features/tasks/state/task_progress_controller.dart';
import 'package:lotti/features/tasks/ui/compact_task_progress.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/time_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    if (!getIt.isRegistered<TimeService>()) {
      getIt.registerSingleton<TimeService>(TimeService());
    }
  });

  testWidgets('CompactTaskProgress text width is stable', (tester) async {
    const taskId = 'task-1';

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
              body: Center(
                child: CompactTaskProgress(taskId: taskId),
              ),
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
    expect(find.byType(CompactTaskProgress), findsOneWidget);
    final textFinder = find.descendant(
      of: find.byType(CompactTaskProgress),
      matching: find.byType(Text),
    );
    expect(textFinder, findsOneWidget);
    final width1 = tester.getSize(textFinder).width;

    await pumpWith(const Duration(minutes: 48), estimate);
    final width2 = tester.getSize(textFinder).width;

    expect(width1, equals(width2));
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
