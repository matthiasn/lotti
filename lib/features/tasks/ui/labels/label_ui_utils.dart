import 'package:lotti/classes/entity_definitions.dart';

class LabelListBuildResult {
  const LabelListBuildResult({
    required this.items,
    required this.availableIds,
  });

  final List<LabelDefinition> items;
  final Set<String> availableIds;
}

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

String? buildLabelSubtitleText(LabelDefinition label,
    {required bool outOfCategory}) {
  final desc = label.description?.trim();
  final note = outOfCategory ? 'Out of category' : null;
  if (note != null && (desc != null && desc.isNotEmpty)) return '$note • $desc';
  if (note != null) return note;
  if (desc != null && desc.isNotEmpty) return desc;
  return null;
}

LabelListBuildResult buildSelectorLabelList({
  required List<LabelDefinition> available,
  required List<LabelDefinition> assignedDefs,
  required Set<String> selectedIds,
  required String searchLower,
}) {
  final availableIds = available.map((e) => e.id).toSet();
  final union = buildUnionLabels(available, assignedDefs);

  final filtered = union.where((label) {
    if (searchLower.isEmpty) return true;
    return label.name.toLowerCase().contains(searchLower) ||
        (label.description?.toLowerCase().contains(searchLower) ?? false);
  }).toList()
    ..sort((a, b) {
      final aAssigned = selectedIds.contains(a.id) ? 0 : 1;
      final bAssigned = selectedIds.contains(b.id) ? 0 : 1;
      final byAssigned = aAssigned.compareTo(bAssigned);
      if (byAssigned != 0) return byAssigned;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

  return LabelListBuildResult(items: filtered, availableIds: availableIds);
}
