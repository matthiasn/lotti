import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/get_it.dart';

/// SettingsDb key for the tasks-list density preference ('true' = compact).
const taskListCompactModeSettingsKey = 'TASK_LIST_COMPACT_MODE';

/// Single writer for the tasks-list density mode: `true` renders the list as
/// terse title-only rows, `false` keeps the full cards (time, category,
/// status).
///
/// Deliberately its own [SettingsDb] key rather than a `TasksFilter` field:
/// density is how the list is displayed, not which tasks it shows, so
/// applying a saved filter must never flip it. Loads once from [SettingsDb],
/// holds state in memory, and persists on every change; SettingsDb writes
/// emit no `UpdateNotifications` token, so dependents must watch this
/// provider — never re-read the database.
class TaskListDensityController extends Notifier<bool> {
  bool _edited = false;

  @override
  bool build() {
    unawaited(_load());
    return false;
  }

  Future<void> _load() async {
    if (!getIt.isRegistered<SettingsDb>()) return;
    final raw = await getIt<SettingsDb>().itemByKey(
      taskListCompactModeSettingsKey,
    );
    if (!ref.mounted || _edited) return;
    state = raw == 'true';
  }

  /// Flips between compact and expanded and persists the new mode. Sets the
  /// `_edited` flag so a still-in-flight initial [_load] never clobbers this
  /// user edit.
  void toggle() {
    _edited = true;
    state = !state;
    if (!getIt.isRegistered<SettingsDb>()) return;
    unawaited(
      getIt<SettingsDb>().saveSettingsItem(
        taskListCompactModeSettingsKey,
        state.toString(),
      ),
    );
  }
}

/// Whether the tasks list renders in compact (title-only) mode.
final taskListDensityControllerProvider =
    NotifierProvider<TaskListDensityController, bool>(
      TaskListDensityController.new,
      name: 'taskListDensityControllerProvider',
    );
