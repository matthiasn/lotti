import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/manual/task/application/provider/task_provider.dart';
import 'package:lotti/features/manual/task/domain/models/tasks_model.dart';

class TaskManualController {
  TaskManualController(this.ref);
  final WidgetRef ref;

  String get manualNote => '''
Lotti is a behavioral monitoring and journaling app that lets you keep track of anything you can measure. 
Measurements could, for example, include tracking exercises, plus imported data from Apple Health or the equivalent on Android. 
In terms of behavior, you can monitor habits, e.g. such that are related to measurables. This could be the intake of medication, numbers of repetitions of an exercise, 
the amount of water you drink, the amount of fiber you ingest, you name it. 
Anything you can imagine. 
If you create a habit, you can assign any dashboard you want,and then by the time you want to complete a habit, look
at the data and determine at a quick glance of the conditions are indeed met for successful completion.
              ''';
  String get taskHeader =>
      'The task interface helps you maintain control over your task entries while providing flexibility in how you organize and manage your personal information.';

  List<TaskManual> getManualContent() {
    return ref.read(taskManualProvider);
  }
}
