import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:wisely/classes/journal_entities.dart';

part 'persistence_state.freezed.dart';

@freezed
class PersistenceState with _$PersistenceState {
  factory PersistenceState.initial() = _Initial;
  factory PersistenceState.loading() = _Loading;
  factory PersistenceState.online({required List<JournalEntity> entries}) =
      _Online;
  factory PersistenceState.failed() = _Failed;
}
