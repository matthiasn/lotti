import 'dart:async';
import 'dart:convert';

import 'package:lotti/blocs/journal/journal_page_state.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/dev_logger.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'calendar_category_visibility_controller.g.dart';

/// Key used by JournalPageCubit to store task category filters.
/// We read from the same key to share visibility state with the Tasks page.
const _tasksCategoryFiltersKey = 'TASKS_CATEGORY_FILTERS';

/// Controller that provides category visibility state for the Calendar view.
///
/// This controller reads from the same persistence layer as the Tasks page
/// (JournalPageCubit), allowing the Calendar to respect the category
/// visibility settings configured on the Tasks page.
///
/// Visibility semantics:
/// - Empty set = all categories visible (show all text)
/// - Non-empty set = only those categories visible, others have text hidden
@Riverpod(keepAlive: true)
class CalendarCategoryVisibilityController
    extends _$CalendarCategoryVisibilityController {
  StreamSubscription<List<SettingsItem>>? _subscription;
  final SettingsDb _settingsDb = getIt<SettingsDb>();

  @override
  Set<String> build() {
    _startListening();
    ref.onDispose(_stopListening);
    return {}; // Default: empty set means all visible
  }

  void _startListening() {
    _subscription = _settingsDb
        .watchSettingsItemByKey(_tasksCategoryFiltersKey)
        .listen(_onSettingsChanged);
  }

  void _stopListening() {
    _subscription?.cancel();
    _subscription = null;
  }

  void _onSettingsChanged(List<SettingsItem> items) {
    if (items.isEmpty) {
      state = {};
      return;
    }

    try {
      final value = items.first.value;
      final json = jsonDecode(value) as Map<String, dynamic>;
      final tasksFilter = TasksFilter.fromJson(json);
      state = tasksFilter.selectedCategoryIds;
    } catch (e) {
      DevLogger.warning(
        name: 'CalendarCategoryVisibilityController',
        message: 'Error parsing category visibility settings: $e',
      );
      state = {};
    }
  }

  /// Checks if a category is visible based on current filter settings.
  ///
  /// - If the filter is empty (show all), returns true for all categories.
  /// - If the filter is non-empty, returns true only if the category ID
  ///   is in the selected set.
  /// - For entries without a category (null/empty), returns true if
  ///   the unassigned marker ('') is in the set or if showing all.
  bool isCategoryVisible(String? categoryId) {
    if (state.isEmpty) {
      // Empty set means "show all" - all categories are visible
      return true;
    }

    // Handle unassigned entries (null or empty categoryId)
    if (categoryId == null || categoryId.isEmpty) {
      return state.contains('');
    }

    return state.contains(categoryId);
  }
}
