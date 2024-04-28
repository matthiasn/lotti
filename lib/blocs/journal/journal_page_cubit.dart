import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:lotti/blocs/journal/journal_page_state.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/fts5_db.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/utils/platform.dart';
import 'package:rxdart/rxdart.dart';
import 'package:visibility_detector/visibility_detector.dart';

class JournalPageCubit extends Cubit<JournalPageState> {
  JournalPageCubit({required this.showTasks})
      : super(
          JournalPageState(
            match: '',
            tagIds: <String>{},
            filters: {},
            showPrivateEntries: false,
            selectedEntryTypes: entryTypes,
            fullTextMatches: {},
            showTasks: showTasks,
            taskAsListView: true,
            pagingController: PagingController(firstPageKey: 0),
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
          ),
        ) {
    getIt<JournalDb>().watchConfigFlag('private').listen((showPrivate) {
      _showPrivateEntries = showPrivate;
      emitState();
    });

    state.pagingController.addPageRequestListener(_fetchPage);

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

    if (showTasks) {
      _db
          .watchTasks(
            starredStatuses: [true, false],
            taskStatuses: state.taskStatuses,
          )
          .throttleTime(
            const Duration(seconds: 1),
            leading: false,
            trailing: true,
          )
          .where(makeDuplicateFilter())
          .listen((_) {
            if (_isVisible) {
              refreshQuery();
            }
          });
    } else {
      _db
          .watchJournalCount()
          .throttleTime(
            const Duration(seconds: 2),
            leading: false,
            trailing: true,
          )
          .where(makeDuplicateFilter())
          .listen((_) {
        if (_isVisible) {
          refreshQuery();
        }
      });
    }
  }

  final JournalDb _db = getIt<JournalDb>();
  bool _isVisible = false;
  static const _pageSize = 50;
  Set<String> _selectedEntryTypes = entryTypes.toSet();
  Set<DisplayFilter> _filters = {};

  String _query = '';
  bool _showPrivateEntries = false;
  bool showTasks = false;
  bool taskAsListView = true;

  Set<String> _fullTextMatches = {};

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
        taskAsListView: taskAsListView,
        showPrivateEntries: _showPrivateEntries,
        showTasks: showTasks,
        selectedEntryTypes: _selectedEntryTypes.toList(),
        fullTextMatches: _fullTextMatches,
        pagingController: state.pagingController,
        taskStatuses: state.taskStatuses,
        selectedTaskStatuses: _selectedTaskStatuses,
      ),
    );
  }

  void setShowTasks({required bool show}) {
    showTasks = show;
    refreshQuery();
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

    refreshQuery();
  }

  void toggleTaskAsListView() {
    taskAsListView = !taskAsListView;
    emitState();
  }

  void toggleSelectedEntryTypes(String entryType) {
    if (_selectedEntryTypes.contains(entryType)) {
      _selectedEntryTypes = _selectedEntryTypes.difference(<String>{entryType});
    } else {
      _selectedEntryTypes = _selectedEntryTypes.union({entryType});
    }

    refreshQuery();
  }

  void selectSingleEntryType(String entryType) {
    _selectedEntryTypes = {entryType};
    refreshQuery();
  }

  void selectAllEntryTypes() {
    _selectedEntryTypes = entryTypes.toSet();
    refreshQuery();
  }

  void clearSelectedEntryTypes() {
    _selectedEntryTypes = {};
    refreshQuery();
  }

  void selectSingleTaskStatus(String taskStatus) {
    _selectedTaskStatuses = {taskStatus};
    refreshQuery();
  }

  void selectAllTaskStatuses() {
    _selectedTaskStatuses = state.taskStatuses.toSet();
    refreshQuery();
  }

  void clearSelectedTaskStatuses() {
    _selectedTaskStatuses = {};
    refreshQuery();
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
    refreshQuery();
  }

  void refreshQuery() {
    emitState();
    state.pagingController.refresh();
  }

  void updateVisibility(VisibilityInfo visibilityInfo) {
    final isVisible = visibilityInfo.visibleBounds.size.width > 0;
    if (!_isVisible && isVisible) {
      refreshQuery();
    }
    _isVisible = isVisible;
  }

  Future<void> _fetchPage(int pageKey) async {
    try {
      final start = DateTime.now();
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

      final newItems = showTasks
          ? await _db
              .watchTasks(
                ids: ids,
                starredStatuses: starredEntriesOnly ? [true] : [true, false],
                taskStatuses: _selectedTaskStatuses.toList(),
                limit: _pageSize,
                offset: pageKey,
              )
              .first
          : await _db
              .watchJournalEntities(
                types: types,
                ids: ids,
                starredStatuses: starredEntriesOnly ? [true] : [true, false],
                privateStatuses: privateEntriesOnly ? [true] : [true, false],
                flaggedStatuses: flaggedEntriesOnly ? [1] : [1, 0],
                limit: _pageSize,
                offset: pageKey,
              )
              .first;

      final isLastPage = newItems.length < _pageSize;
      if (isLastPage) {
        state.pagingController.appendLastPage(newItems);
      } else {
        final nextPageKey = pageKey + newItems.length;
        state.pagingController.appendPage(newItems, nextPageKey);
      }
      final finished = DateTime.now();
      final duration = finished.difference(start);
      debugPrint('_fetchPage $showTasks duration $duration');
    } catch (error) {
      state.pagingController.error = error;
    }
  }

  @override
  Future<void> close() async {
    state.pagingController.dispose();
    await super.close();
  }
}

final List<String> entryTypes = [
  'Task',
  'JournalEntry',
  'JournalAudio',
  'JournalImage',
  'MeasurementEntry',
  'SurveyEntry',
  'WorkoutEntry',
  'HabitCompletionEntry',
  'QuantitativeEntry',
];

// This function returns a stateful stream filter
// function that compares the previous event on
// the stream with the latest, and filters those
// that are found equal using deep collection
// equality. This allows exactly once deliver on
// a stream instead of at least once previously,
// which lead to plenty of costly re-renders.
bool Function(T next) makeDuplicateFilter<T>() {
  final deepEq = const DeepCollectionEquality().equals;
  T? prev;

  bool duplicateFilter(T next) {
    if (deepEq(prev, next)) {
      return false;
    } else {
      prev = next;
      return true;
    }
  }

  return duplicateFilter;
}
