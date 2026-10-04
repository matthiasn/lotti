import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Reacts to a task's title being saved with a new value.
typedef TaskTitleChangedHook =
    Future<void> Function(String taskId, String title);

/// What else follows a task's title, called after each title save. Empty
/// until the composition root registers the features that mirror it (Daily
/// OS's planned blocks); journal does not depend on them.
final taskTitleChangedHooksProvider = Provider<List<TaskTitleChangedHook>>(
  (ref) => const [],
  name: 'taskTitleChangedHooksProvider',
);
