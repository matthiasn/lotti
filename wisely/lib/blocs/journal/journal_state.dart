import 'package:freezed_annotation/freezed_annotation.dart';

part 'journal_state.freezed.dart';

@freezed
class JournalState with _$JournalState {
  factory JournalState() = _Initial;
}
