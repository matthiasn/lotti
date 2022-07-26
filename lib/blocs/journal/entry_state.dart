import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:lotti/classes/journal_entities.dart';

part 'entry_state.freezed.dart';

@freezed
class EntryState with _$EntryState {
  factory EntryState({
    required String entryId,
    required JournalEntity? entry,
    required bool dirty,
  }) = _EntryState;
}
