import 'package:lotti/features/tasks/model/task_progress_state.dart';
import 'package:lotti/features/tasks/state/task_progress_controller.dart';

class TestTaskProgressController extends TaskProgressController {
  TestTaskProgressController({
    required this.progress,
    required this.estimate,
  });

  final Duration progress;
  final Duration estimate;

  @override
  Future<TaskProgressState?> build({required String id}) async {
    return TaskProgressState(
      progress: progress,
      estimate: estimate,
    );
  }
}
