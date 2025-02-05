import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:lotti/classes/checklist_item_data.dart';

part 'summary_checklist_state.freezed.dart';
part 'summary_checklist_state.g.dart';

@freezed
class SummaryChecklistState with _$SummaryChecklistState {
  const factory SummaryChecklistState({
    String? summary,
    List<ChecklistItemData>? checklistItems,
  }) = _SummaryChecklistState;

  factory SummaryChecklistState.fromJson(Map<String, dynamic> json) =>
      _$SummaryChecklistStateFromJson(json);
}
