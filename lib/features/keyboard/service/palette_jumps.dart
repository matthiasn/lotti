import 'package:lotti/database/database.dart';
import 'package:lotti/database/fts5_db.dart';
import 'package:lotti/features/keyboard/domain/palette_jump.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/utils/consts.dart';

/// The journal types the palette jumps to, by the kind each opens as.
const paletteJumpKinds = <String, PaletteJumpKind>{
  'Task': PaletteJumpKind.task,
  'Project': PaletteJumpKind.project,
  'JournalEvent': PaletteJumpKind.event,
  'Relationship': PaletteJumpKind.person,
  'JournalEntry': PaletteJumpKind.entry,
  'JournalAudio': PaletteJumpKind.entry,
  'JournalImage': PaletteJumpKind.entry,
};

/// The palette's title search over the search index ([Fts5Db.searchTitles]):
/// the kinds in [paletteJumpKinds], private ones only while private mode
/// shows them, and only in [categoryIds] when it gives any — lockdown's
/// categories, so a demo never surfaces a title outside them. Without an
/// index (a world that has none) it finds nothing.
PaletteJumpSearch paletteJumpSearch({
  required Fts5Db? Function() fts5Db,
  required JournalDb journalDb,
  required Set<String>? Function() categoryIds,
  int limit = 8,
}) => (query) async {
  final index = fts5Db();
  if (index == null) return const [];
  final matches = await index.searchTitles(
    query,
    types: paletteJumpKinds.keys.toSet(),
    categoryIds: categoryIds(),
    includePrivate: await journalDb.getConfigFlag(privateFlag),
    limit: limit,
  );
  return [
    for (final match in matches)
      if (paletteJumpKinds[match.type] case final kind?)
        PaletteJumpTarget(
          entityId: match.entityId,
          kind: kind,
          title: match.title,
          fuzzy: match.fuzzy,
        ),
  ];
};

/// Opens [target] where its kind lives. A task opens by its id
/// ([NavService.openTask]), so it is the task in view whatever the desktop
/// detail stack held before.
void openPaletteJump(NavService navService, PaletteJumpTarget target) {
  final id = target.entityId;
  switch (target.kind) {
    case PaletteJumpKind.task:
      navService.openTask(id);
    case PaletteJumpKind.entry:
      navService.beamToNamed('/journal/$id');
    case PaletteJumpKind.project:
      navService.beamToNamed('/projects/$id');
    case PaletteJumpKind.event:
      navService.beamToNamed('/events/$id');
    case PaletteJumpKind.person:
      navService.beamToNamed('/people/$id');
  }
}
