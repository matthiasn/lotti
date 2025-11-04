import 'package:lotti/database/database.dart';

/// Build a list of label maps [{id, name}] for the given label IDs.
///
/// Performs a batch lookup via `getAllLabelDefinitions` and resolves names,
/// falling back to the ID if a definition is missing.
Future<List<Map<String, String>>> buildAssignedLabelTuples({
  required JournalDb db,
  required List<String> ids,
}) async {
  if (ids.isEmpty) return <Map<String, String>>[];
  final defs = await db.getAllLabelDefinitions();
  final byId = {for (final d in defs) d.id: d};
  final labels = <Map<String, String>>[];
  for (final lid in ids) {
    final def = byId[lid];
    final name = def?.name ?? lid;
    labels.add({'id': lid, 'name': name});
  }
  return labels;
}
