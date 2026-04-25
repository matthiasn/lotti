import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:lotti/features/journal/state/journal_page_state.dart';

part 'saved_task_filter.freezed.dart';
part 'saved_task_filter.g.dart';

/// A user-saved Tasks filter pinned to the sidebar under Tasks.
///
/// Position in the persisted list is the sort order. The ephemeral
/// search query is intentionally NOT part of [filter] — it stays on
/// the live page state and is preserved across saved-filter activations.
@Freezed(toJson: true, fromJson: true)
abstract class SavedTaskFilter with _$SavedTaskFilter {
  @JsonSerializable(explicitToJson: true)
  const factory SavedTaskFilter({
    required String id,
    required String name,
    required TasksFilter filter,
  }) = _SavedTaskFilter;

  factory SavedTaskFilter.fromJson(Map<String, dynamic> json) =>
      _$SavedTaskFilterFromJson(json);
}
