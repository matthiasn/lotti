import 'package:freezed_annotation/freezed_annotation.dart';

part 'journal_image_state.freezed.dart';

@freezed
class JournalImageState with _$JournalImageState {
  factory JournalImageState() = _Initial;
}
