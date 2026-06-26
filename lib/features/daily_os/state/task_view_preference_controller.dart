import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/get_it.dart';

/// View modes for task display in time budget cards.
enum TaskViewMode { list, grid }

/// Settings key pattern for category view preferences.
String _settingsKey(String categoryId) => 'time_budget_view_$categoryId';

/// Controller for persisting task view mode preferences per category.
final AsyncNotifierProviderFamily<TaskViewPreference, TaskViewMode, String>
taskViewPreferenceProvider = AsyncNotifierProvider.autoDispose
    .family<TaskViewPreference, TaskViewMode, String>(
      TaskViewPreference.new,
      name: 'taskViewPreferenceProvider',
    );

class TaskViewPreference extends AsyncNotifier<TaskViewMode> {
  TaskViewPreference([this.categoryId = '']);

  final String categoryId;

  late SettingsDb _settingsDb;
  late String _categoryId;

  @override
  Future<TaskViewMode> build() async {
    _settingsDb = getIt<SettingsDb>();
    _categoryId = categoryId;
    final stored = await _settingsDb.itemByKey(_settingsKey(categoryId));
    // Default to list view
    return stored == 'grid' ? TaskViewMode.grid : TaskViewMode.list;
  }

  Future<void> toggle() async {
    final current = state.value ?? TaskViewMode.list;
    final newMode = current == TaskViewMode.list
        ? TaskViewMode.grid
        : TaskViewMode.list;

    await _settingsDb.saveSettingsItem(
      _settingsKey(_categoryId),
      newMode == TaskViewMode.grid ? 'grid' : 'list',
    );
    state = AsyncData(newMode);
  }
}
