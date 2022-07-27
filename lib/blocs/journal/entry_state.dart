import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:lotti/classes/journal_entities.dart';

part 'entry_state.freezed.dart';

@freezed
class EntryState with _$EntryState {
  factory EntryState.saved({
    required String entryId,
    required JournalEntity? entry,
  }) = _EntryStateSaved;

  factory EntryState.dirty({
    required String entryId,
    required JournalEntity? entry,
  }) = EntryStateDirty;
}
