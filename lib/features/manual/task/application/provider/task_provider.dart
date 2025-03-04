import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/manual/task/data/repository/task_repository.dart';
import 'package:lotti/features/manual/task/domain/models/tasks_model.dart';

final taskManualProvider = Provider<List<TaskManual>>((ref) {
  return TaskManualRepository().getManualContent();
});
