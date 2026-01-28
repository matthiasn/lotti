import 'package:lotti/database/settings_db.dart';
import 'package:lotti/get_it.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'task_view_preference_controller.g.dart';

/// View modes for task display in time budget cards.
enum TaskViewMode { list, grid }

/// Settings key pattern for category view preferences.
String _settingsKey(String categoryId) => 'time_budget_view_$categoryId';

/// Controller for persisting task view mode preferences per category.
@riverpod
class TaskViewPreference extends _$TaskViewPreference {
  late SettingsDb _settingsDb;
  late String _categoryId;

  @override
  Future<TaskViewMode> build({required String categoryId}) async {
    _settingsDb = getIt<SettingsDb>();
    _categoryId = categoryId;
    final stored = await _settingsDb.itemByKey(_settingsKey(categoryId));
    // Default to list view
    return stored == 'grid' ? TaskViewMode.grid : TaskViewMode.list;
  }

  Future<void> toggle() async {
    final current = state.value ?? TaskViewMode.list;
    final newMode =
        current == TaskViewMode.list ? TaskViewMode.grid : TaskViewMode.list;

    await _settingsDb.saveSettingsItem(
      _settingsKey(_categoryId),
      newMode == TaskViewMode.grid ? 'grid' : 'list',
    );
    state = AsyncData(newMode);
  }
}
