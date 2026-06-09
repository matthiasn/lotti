import 'package:glados/glados.dart'
    show Any, AnyUtils, CombinableAny, Generator, IntAnys, ListAnys;
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/tasks/util/due_date_utils.dart';

class GeneratedTaskProgressSpec {
  const GeneratedTaskProgressSpec({
    required this.priority,
    required this.urgency,
    required this.timeSpentMinutes,
    required this.titleSeed,
  });

  final TaskPriority priority;
  final DueDateUrgency urgency;
  final int timeSpentMinutes;
  final int titleSeed;

  String titleFor(int index) {
    final bucket = switch (titleSeed % 5) {
      0 => 'Alpha',
      1 => 'bravo',
      2 => 'Charlie',
      3 => 'delta',
      _ => 'Echo',
    };
    return '$bucket ${index.toString().padLeft(2, '0')}';
  }

  @override
  String toString() {
    return 'GeneratedTaskProgressSpec('
        'priority: $priority, '
        'urgency: $urgency, '
        'timeSpentMinutes: $timeSpentMinutes, '
        'titleSeed: $titleSeed)';
  }
}

extension AnyTaskProgressSpecs on Any {
  Generator<TaskPriority> get taskPriority =>
      choose(TaskPriority.values.toList());

  Generator<DueDateUrgency> get dueDateUrgency =>
      choose(DueDateUrgency.values.toList());

  Generator<GeneratedTaskProgressSpec> get taskProgressSpec => combine4(
    taskPriority,
    dueDateUrgency,
    intInRange(0, 240),
    intInRange(0, 1000),
    (
      TaskPriority priority,
      DueDateUrgency urgency,
      int timeSpentMinutes,
      int titleSeed,
    ) => GeneratedTaskProgressSpec(
      priority: priority,
      urgency: urgency,
      timeSpentMinutes: timeSpentMinutes,
      titleSeed: titleSeed,
    ),
  );

  Generator<List<GeneratedTaskProgressSpec>> get taskProgressSpecs =>
      listWithLengthInRange(0, 18, taskProgressSpec);
}
