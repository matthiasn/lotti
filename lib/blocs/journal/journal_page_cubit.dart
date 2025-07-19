import 'dart:async';
import 'dart:convert';

import 'package:bloc/bloc.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:lotti/blocs/journal/journal_page_state.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/fts5_db.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/utils/platform.dart';
import 'package:rxdart/rxdart.dart';
import 'package:visibility_detector/visibility_detector.dart';

class JournalPageCubit extends Cubit<JournalPageState> {
  JournalPageCubit({required this.showTasks})
      : _db = getIt<JournalDb>(),
        _updateNotifications = getIt<UpdateNotifications>(),
        super(
          JournalPageState(
            match: '',
            tagIds: <String>{},
            filters: {},
            showPrivateEntries: false,
            selectedEntryTypes: entryTypes,
            fullTextMatches: {},
            showTasks: showTasks,
            pagingController: null,
            taskStatuses: [
              'OPEN',
              'GROOMED',
              'IN PROGRESS',
              'BLOCKED',
              'ON HOLD',
              'DONE',
              'REJECTED',
            ],
            selectedTaskStatuses: {
              'OPEN',
              'GROOMED',
              'IN PROGRESS',
            },
            selectedCategoryIds: {},
          ),
        ) {
    // Check if we need to set default category selection for tasks
    if (showTasks) {
      final allCategoryIds = getIt<EntitiesCacheService>()
          .sortedCategories
          .map((e) => e.id)
          .toSet();

      // If no categories exist, default to showing unassigned tasks
      if (allCategoryIds.isEmpty) {
        _selectedCategoryIds = {''};
      }
    }

    // Create the controller right after initialization
    final controller = PagingController<int, JournalEntity>(
      getNextPageKey: (PagingState<int, JournalEntity> state) {
        final currentKeys = state.keys;
        if (currentKeys == null || currentKeys.isEmpty) {
          return 0; // First page key (offset)
        }
        if (!state.hasNextPage) {
          return null; // No next page if controller says so
        }
        final currentPages = state.pages;
        // If last page had fewer items than _pageSize, it's the last page
        if (currentPages != null &&
            currentPages.isNotEmpty &&
            currentPages.last.length < _pageSize) {
          return null; // No more pages
        }
        if (currentPages != null &&
            currentPages.isNotEmpty &&
            currentKeys.length == currentPages.length) {
          final lastFetchedItemsCount = currentPages.last.length;
          return currentKeys.last + lastFetchedItemsCount;
        }
        // Fallback: if keys exist but pages inconsistent or last page empty.
        // Controller handles hasNextPage based on fetchPage results.
        return currentKeys.last +
            ((currentPages != null &&
                    currentPages.isNotEmpty &&
                    currentKeys.length == currentPages.length)
                ? currentPages.last.length
                : 0);
      },
      fetchPage: _fetchPage, // Now we can directly use the method reference
    );

    // Set the controller and trigger initial load
    emit(
      JournalPageState(
        match: state.match,
        tagIds: state.tagIds,
        filters: state.filters,
        showPrivateEntries: state.showPrivateEntries,
        selectedEntryTypes: state.selectedEntryTypes,
        fullTextMatches: state.fullTextMatches,
        showTasks: state.showTasks,
        pagingController: controller,
        taskStatuses: state.taskStatuses,
        selectedTaskStatuses: state.selectedTaskStatuses,
        selectedCategoryIds: _selectedCategoryIds,
      ),
    );

    // Call fetchNextPage to trigger the initial load
    controller.fetchNextPage();

    getIt<JournalDb>().watchConfigFlag('private').listen((showPrivate) {
      _showPrivateEntries = showPrivate;
      emitState();
    });

    getIt<SettingsDb>().itemByKey(taskFiltersKey).then((value) {
      if (value == null) {
        return;
      }
      final json = jsonDecode(value) as Map<String, dynamic>;
      final tasksFilter = TasksFilter.fromJson(json);
      _selectedTaskStatuses = tasksFilter.selectedTaskStatuses;
      _selectedCategoryIds = tasksFilter.selectedCategoryIds;
      emitState();
      refreshQuery();
    });

    getIt<SettingsDb>().itemByKey(selectedEntryTypesKey).then((value) {
      if (value == null) {
        return;
      }
      final json = jsonDecode(value) as List<dynamic>;
      _selectedEntryTypes = List<String>.from(json).toSet();
      emitState();
      refreshQuery();
    });

    if (isDesktop) {
      hotKeyManager.register(
        HotKey(
          key: LogicalKeyboardKey.keyR,
          modifiers: [HotKeyModifier.meta],
          scope: HotKeyScope.inapp,
        ),
        keyDownHandler: (hotKey) => refreshQuery(),
      );
    }

    String idMapper(JournalEntity entity) => entity.meta.id;

    _updateNotifications.updateStream
        .throttleTime(
      const Duration(milliseconds: 500),
      leading: false,
      trailing: true,
    )
        .listen((affectedIds) async {
      if (_isVisible) {
        final displayedIds =
            state.pagingController?.value.items?.map(idMapper).toSet() ??
                <String>{};

        if (showTasks) {
          final newIds = (await _runQuery(0)).map(idMapper).toSet();
          if (!setEquals(_lastIds, newIds)) {
            _lastIds = newIds;
            await refreshQuery();
          } else if (displayedIds.intersection(affectedIds).isNotEmpty) {
            await refreshQuery();
          }
        } else {
          if (displayedIds.intersection(affectedIds).isNotEmpty) {
            await refreshQuery();
          }
        }
      }
    });
  }

  static const taskFiltersKey = 'TASK_FILTERS';
  static const selectedEntryTypesKey = 'SELECTED_ENTRY_TYPES';

  final JournalDb _db;
  final UpdateNotifications _updateNotifications;
  bool _isVisible = false;
  static const _pageSize = 50;
  Set<String> _selectedEntryTypes = entryTypes.toSet();
  Set<DisplayFilter> _filters = {};

  String _query = '';
  bool _showPrivateEntries = false;
  bool showTasks = false;
  Set<String> _selectedCategoryIds = {};

  Set<String> _fullTextMatches = {};
  Set<String> _lastIds = {};
  Set<String> _selectedTaskStatuses = {
    'OPEN',
    'GROOMED',
    'IN PROGRESS',
  };

  void emitState() {
    emit(
      JournalPageState(
        match: _query,
        tagIds: <String>{},
        filters: _filters,
        showPrivateEntries: _showPrivateEntries,
        showTasks: showTasks,
        selectedEntryTypes: _selectedEntryTypes.toList(),
        fullTextMatches: _fullTextMatches,
        pagingController: state.pagingController,
        taskStatuses: state.taskStatuses,
        selectedTaskStatuses: _selectedTaskStatuses,
        selectedCategoryIds: _selectedCategoryIds,
      ),
    );
  }

  void setFilters(Set<DisplayFilter> filters) {
    _filters = filters;
    refreshQuery();
  }

  void toggleSelectedTaskStatus(String status) {
    if (_selectedTaskStatuses.contains(status)) {
      _selectedTaskStatuses =
          _selectedTaskStatuses.difference(<String>{status});
    } else {
      _selectedTaskStatuses = _selectedTaskStatuses.union({status});
    }

    persistTasksFilter();
  }

  void toggleSelectedCategoryIds(String categoryId) {
    if (_selectedCategoryIds.contains(categoryId)) {
      _selectedCategoryIds = _selectedCategoryIds.difference({categoryId});
    } else {
      _selectedCategoryIds = _selectedCategoryIds.union({categoryId});
    }
    persistTasksFilter();
    refreshQuery();
    emitState();
  }

  void selectedAllCategories() {
    _selectedCategoryIds = {};
    persistTasksFilter();
    refreshQuery();
    emitState();
  }

  void toggleSelectedEntryTypes(String entryType) {
    if (_selectedEntryTypes.contains(entryType)) {
      _selectedEntryTypes = _selectedEntryTypes.difference(<String>{entryType});
    } else {
      _selectedEntryTypes = _selectedEntryTypes.union({entryType});
    }

    persistEntryTypes();
  }

  void selectSingleEntryType(String entryType) {
    _selectedEntryTypes = {entryType};
    persistEntryTypes();
  }

  void selectAllEntryTypes() {
    _selectedEntryTypes = entryTypes.toSet();
    persistEntryTypes();
  }

  void clearSelectedEntryTypes() {
    _selectedEntryTypes = {};
    persistEntryTypes();
  }

  void selectSingleTaskStatus(String taskStatus) {
    _selectedTaskStatuses = {taskStatus};
    persistTasksFilter();
    emitState();
  }

  void selectAllTaskStatuses() {
    _selectedTaskStatuses = state.taskStatuses.toSet();
    persistTasksFilter();
    emitState();
  }

  void clearSelectedTaskStatuses() {
    _selectedTaskStatuses = {};
    persistTasksFilter();
    emitState();
  }

  Future<void> persistTasksFilter() async {
    await refreshQuery();

    await getIt<SettingsDb>().saveSettingsItem(
      taskFiltersKey,
      jsonEncode(
        TasksFilter(
          selectedCategoryIds: _selectedCategoryIds,
          selectedTaskStatuses: _selectedTaskStatuses,
        ),
      ),
    );
  }

  Future<void> persistEntryTypes() async {
    await refreshQuery();

    await getIt<SettingsDb>().saveSettingsItem(
      selectedEntryTypesKey,
      jsonEncode(_selectedEntryTypes.toList()),
    );
  }

  Future<void> _fts5Search() async {
    if (_query.isEmpty) {
      _fullTextMatches = {};
    } else {
      final res = await getIt<Fts5Db>().watchFullTextMatches(_query).first;
      _fullTextMatches = res.toSet();
    }
  }

  Future<void> setSearchString(String query) async {
    _query = query;
    await refreshQuery();
  }

  Future<void> refreshQuery() async {
    emitState();

    if (state.pagingController == null) {
      debugPrint('Warning: refreshQuery called but pagingController is null');
      return;
    }

    debugPrint('Refreshing and fetching page');
    state.pagingController!.refresh();
    state.pagingController!.fetchNextPage();
  }

  void updateVisibility(VisibilityInfo visibilityInfo) {
    final isVisible = visibilityInfo.visibleBounds.size.width > 0;
    if (!_isVisible && isVisible) {
      refreshQuery();
    }
    _isVisible = isVisible;
  }

  Future<List<JournalEntity>> _fetchPage(int pageKey) async {
    try {
      final start = DateTime.now();
      final newItems = await _runQuery(pageKey);
      // The PagingController will use the returned list (newItems)
      // to update its state, including pages, keys, and hasNextPage.

      final duration2 = DateTime.now().difference(start).inMicroseconds / 1000;
      debugPrint(
        '_fetchPage ${showTasks ? 'TASK' : 'JOURNAL'} duration $duration2 ms, found ${newItems.length} items',
      );
      return newItems;
    } catch (error, stackTrace) {
      if (kDebugMode) {
        print('Error in _fetchPage: $error\n$stackTrace');
      }
      // Rethrow the error. The PagingController will catch it
      // and update its state.error field.
      rethrow;
    }
  }

  Future<List<JournalEntity>> _runQuery(int pageKey) async {
    final types = state.selectedEntryTypes.toList();
    await _fts5Search();
    final fullTextMatches = _fullTextMatches.toList();
    final ids = _query.isNotEmpty ? fullTextMatches : null;

    final starredEntriesOnly =
        _filters.contains(DisplayFilter.starredEntriesOnly);
    final privateEntriesOnly =
        _filters.contains(DisplayFilter.privateEntriesOnly);
    final flaggedEntriesOnly =
        _filters.contains(DisplayFilter.flaggedEntriesOnly);

    if (showTasks) {
      final allCategoryIds = getIt<EntitiesCacheService>()
          .sortedCategories
          .map((e) => e.id)
          .toSet();

      Set<String> categoryIds;
      if (_selectedCategoryIds.isEmpty) {
        // If no categories are selected and no categories exist,
        // default to showing unassigned tasks for better onboarding
        categoryIds = allCategoryIds.isEmpty ? {''} : allCategoryIds;
      } else {
        categoryIds = _selectedCategoryIds;
      }

      final res = await _db.getTasks(
        ids: ids,
        starredStatuses: starredEntriesOnly ? [true] : [true, false],
        taskStatuses: _selectedTaskStatuses.toList(),
        categoryIds: categoryIds.toList(),
        limit: _pageSize,
        offset: pageKey,
      );

      return res;
    } else {
      return _db.getJournalEntities(
        types: types,
        ids: ids,
        starredStatuses: starredEntriesOnly ? [true] : [true, false],
        privateStatuses: privateEntriesOnly ? [true] : [true, false],
        flaggedStatuses: flaggedEntriesOnly ? [1] : [1, 0],
        categoryIds:
            _selectedCategoryIds.isNotEmpty ? _selectedCategoryIds : null,
        limit: _pageSize,
        offset: pageKey,
      );
    }
  }

  @override
  Future<void> close() async {
    state.pagingController?.dispose();
    await super.close();
  }
}

const List<String> entryTypes = [
  'Task',
  'JournalEntry',
  'JournalEvent',
  'JournalAudio',
  'JournalImage',
  'MeasurementEntry',
  'SurveyEntry',
  'WorkoutEntry',
  'HabitCompletionEntry',
  'QuantitativeEntry',
  'Checklist',
  'ChecklistItem',
  'AiResponse',
];
