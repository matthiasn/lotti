import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:lotti/blocs/journal/journal_page_state.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';

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
            selectedEntryTypes: defaultTypes,
          ),
        ) {
    getIt<JournalDb>().watchConfigFlag('private').listen((showPrivate) {
      _showPrivateEntries = showPrivate;
      emitState();
    });
  }

  List<FilterBy?> _selectedEntryTypes = <FilterBy?>[];

  String _match = '';
  bool _starredEntriesOnly = false;
  bool _flaggedEntriesOnly = false;
  bool _privateEntriesOnly = false;
  bool _showPrivateEntries = false;

  void emitState() {
    emit(
      JournalPageState(
        match: _match,
        tagIds: <String>{},
        starredEntriesOnly: _starredEntriesOnly,
        flaggedEntriesOnly: _flaggedEntriesOnly,
        privateEntriesOnly: _privateEntriesOnly,
        showPrivateEntries: _showPrivateEntries,
        selectedEntryTypes: _selectedEntryTypes,
      ),
    );
  }

  void setSelectedTypes(List<FilterBy?> selected) {
    _selectedEntryTypes = selected;
    emitState();
  }

  void toggleStarredEntriesOnly() {
    _starredEntriesOnly = !_starredEntriesOnly;
    emitState();
  }

  void toggleFlaggedEntriesOnly() {
    _flaggedEntriesOnly = !_flaggedEntriesOnly;
    emitState();
  }

  void togglePrivateEntriesOnly() {
    _privateEntriesOnly = !_privateEntriesOnly;
    emitState();
  }

  void setSearchString(String match) {
    _match = match;
    emitState();
  }

  @override
  Future<void> close() async {
    await super.close();
  }
}
