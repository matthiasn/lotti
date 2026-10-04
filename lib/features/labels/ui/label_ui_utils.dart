import 'package:collection/collection.dart';
import 'package:lotti/classes/entity_definitions.dart';

/// Output of [buildSelectorLabelList]: the filtered/sorted [items] to render
/// plus [availableIds], the ids that belong to the task's category. The UI
/// uses [availableIds] to flag assigned-but-out-of-category labels.
class LabelListBuildResult {
  const LabelListBuildResult({
    required this.items,
    required this.availableIds,
  });

  final List<LabelDefinition> items;
  final Set<String> availableIds;
}

/// Merges the category's [available] labels with the already-[assignedDefs]
/// ones, de-duplicating by id. When both lists contain the same id the
/// assigned definition wins, so a renamed/edited assignment is preserved.
List<LabelDefinition> buildUnionLabels(
  List<LabelDefinition> available,
  List<LabelDefinition> assignedDefs,
) {
  final byId = <String, LabelDefinition>{
    for (final l in available) l.id: l,
    for (final l in assignedDefs) l.id: l,
  };
  return byId.values.toList();
}

/// Builds the subtitle line for a label row, combining an "Out of category"
/// note (when [outOfCategory]) with the label's description. Returns `null`
/// when neither is present, so the row can omit the subtitle entirely.
String? buildLabelSubtitleText(
  LabelDefinition label, {
  required bool outOfCategory,
}) {
  final desc = label.description?.trim();
  final note = outOfCategory ? 'Out of category' : null;
  if (note != null && (desc != null && desc.isNotEmpty)) return '$note • $desc';
  if (note != null) return note;
  if (desc != null && desc.isNotEmpty) return desc;
  return null;
}

/// Produces the label list for the label-selector UI: the union of [available]
/// and [assignedDefs], filtered by [searchLower] (matched against name and
/// description) and sorted A–Z by name regardless of selection state.
LabelListBuildResult buildSelectorLabelList({
  required List<LabelDefinition> available,
  required List<LabelDefinition> assignedDefs,
  required Set<String> selectedIds,
  required String searchLower,
}) {
  final availableIds = available.map((e) => e.id).toSet();
  final union = buildUnionLabels(available, assignedDefs);

  final filtered =
      union.where((label) {
        if (searchLower.isEmpty) return true;
        return label.name.toLowerCase().contains(searchLower) ||
            (label.description?.toLowerCase().contains(searchLower) ?? false);
      }).toList()..sort((a, b) {
        // Sort strictly A–Z by name, independent of selection state.
        // Use compareAsciiLowerCase to avoid allocating new strings.
        return compareAsciiLowerCase(a.name, b.name);
      });

  return LabelListBuildResult(items: filtered, availableIds: availableIds);
}
