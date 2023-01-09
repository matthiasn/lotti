import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:lotti/blocs/journal/journal_page_state.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/fts5_db.dart';
import 'package:lotti/get_it.dart';

class JournalPageCubit extends Cubit<JournalPageState> {
  JournalPageCubit()
      : super(
          JournalPageState(
            match: '',
            tagIds: <String>{},
            starredEntriesOnly: false,
            flaggedEntriesOnly: false,
            privateEntriesOnly: false,
            showPrivateEntries: false,
            selectedEntryTypes: entryTypes,
            fullTextMatches: {},
            pagingController: PagingController(firstPageKey: 0),
          ),
        ) {
    getIt<JournalDb>().watchConfigFlag('private').listen((showPrivate) {
      _showPrivateEntries = showPrivate;
      emitState();
    });

    state.pagingController.addPageRequestListener(_fetchPage);
  }

  final JournalDb _db = getIt<JournalDb>();
  static const _pageSize = 50;
  List<FilterBy?> _selectedEntryTypes = entryTypes;

  String _query = '';
  bool _starredEntriesOnly = false;
  bool _flaggedEntriesOnly = false;
  bool _privateEntriesOnly = false;
  bool _showPrivateEntries = false;

  Set<String> _fullTextMatches = {};

  void emitState() {
    emit(
      JournalPageState(
        match: _query,
        tagIds: <String>{},
        starredEntriesOnly: _starredEntriesOnly,
        flaggedEntriesOnly: _flaggedEntriesOnly,
        privateEntriesOnly: _privateEntriesOnly,
        showPrivateEntries: _showPrivateEntries,
        selectedEntryTypes: _selectedEntryTypes,
        fullTextMatches: _fullTextMatches,
        pagingController: state.pagingController,
      ),
    );
  }

  void setSelectedTypes(List<FilterBy?> selected) {
    _selectedEntryTypes = selected;
    refreshQuery();
  }

  void toggleStarredEntriesOnly() {
    _starredEntriesOnly = !_starredEntriesOnly;
    refreshQuery();
  }

  void toggleFlaggedEntriesOnly() {
    _flaggedEntriesOnly = !_flaggedEntriesOnly;
    refreshQuery();
  }

  void togglePrivateEntriesOnly() {
    _privateEntriesOnly = !_privateEntriesOnly;
    refreshQuery();
  }

  Future<void> setSearchString(String query) async {
    _query = query;
    if (query.isEmpty) {
      _fullTextMatches = {};
    } else {
      final res = await getIt<Fts5Db>().watchFullTextMatches(query).first;
      _fullTextMatches = res.toSet();
    }

    refreshQuery();
  }

  void refreshQuery() {
    emitState();
    state.pagingController.refresh();
  }

  Future<void> _fetchPage(int pageKey) async {
    try {
      final types = state.selectedEntryTypes
          .map((e) => e?.typeName)
          .whereType<String>()
          .toList();

      final fullTextMatches = _fullTextMatches.toList();
      final ids = _query.isNotEmpty ? fullTextMatches : null;

      final newItems = await _db
          .watchJournalEntities(
            types: types,
            ids: ids,
            starredStatuses: _starredEntriesOnly ? [true] : [true, false],
            privateStatuses: _privateEntriesOnly ? [true] : [true, false],
            flaggedStatuses: _flaggedEntriesOnly ? [1] : [1, 0],
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

class FilterBy {
  FilterBy({
    required this.typeName,
    required this.name,
  });

  final String typeName;
  final String name;
}

final List<FilterBy> entryTypes = [
  FilterBy(typeName: 'Task', name: 'Task'),
  FilterBy(typeName: 'JournalEntry', name: 'Text'),
  FilterBy(typeName: 'JournalAudio', name: 'Audio'),
  FilterBy(typeName: 'JournalImage', name: 'Photo'),
  FilterBy(typeName: 'MeasurementEntry', name: 'Measured'),
  FilterBy(typeName: 'SurveyEntry', name: 'Survey'),
  FilterBy(typeName: 'WorkoutEntry', name: 'Workout'),
  FilterBy(typeName: 'HabitCompletionEntry', name: 'Habit'),
  FilterBy(typeName: 'QuantitativeEntry', name: 'Quant'),
];

final List<FilterBy> defaultTypes = [
  FilterBy(typeName: 'Task', name: 'Task'),
  FilterBy(typeName: 'JournalEntry', name: 'Text'),
  FilterBy(typeName: 'JournalAudio', name: 'Audio'),
  FilterBy(typeName: 'JournalImage', name: 'Photo'),
];
