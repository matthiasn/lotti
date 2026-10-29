import 'package:meta/meta.dart';

/// What kind of thing a palette result opens, which decides its route, icon
/// and label.
enum PaletteJumpKind { task, entry, project, event, person }

/// One thing the command palette can jump to by its title.
@immutable
class PaletteJumpTarget {
  const PaletteJumpTarget({
    required this.entityId,
    required this.kind,
    required this.title,
    this.fuzzy = false,
  });

  final String entityId;
  final PaletteJumpKind kind;
  final String title;

  /// A near match for a misspelt query rather than a title holding every
  /// word of it.
  final bool fuzzy;

  @override
  bool operator ==(Object other) =>
      other is PaletteJumpTarget &&
      other.entityId == entityId &&
      other.kind == kind &&
      other.title == title &&
      other.fuzzy == fuzzy;

  @override
  int get hashCode => Object.hash(entityId, kind, title, fuzzy);
}

/// Finds what the palette can jump to for what was typed, best first.
typedef PaletteJumpSearch =
    Future<List<PaletteJumpTarget>> Function(String query);
