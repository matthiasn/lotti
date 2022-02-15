import 'package:flutter/material.dart';
import 'package:lotti/classes/task.dart';

Color? taskColor(TaskStatus taskStatus) {
  return taskStatus.map(
    open: (_) => Colors.orange,
    started: (_) => Colors.blue,
    inProgress: (_) => Colors.blue,
    blocked: (_) => Colors.red,
    onHold: (_) => Colors.red,
    done: (_) => Colors.green,
    rejected: (_) => Colors.red,
  );
}
