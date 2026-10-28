import 'package:flutter/foundation.dart';
import 'package:lotti/database/history_db.dart';

/// What kind of entity a visit opened, which decides where its current title
/// is read from and which section of the app it belongs to.
///
/// Stored by [name], so a value is renamed only together with a migration.
enum HistoryEntityKind {
  task,
  entry,
  project,
  event,
  person,
  dashboard,
  habit;

  static HistoryEntityKind? tryParse(String name) {
    for (final kind in values) {
      if (kind.name == name) return kind;
    }
    return null;
  }
}

/// An entity the user is looking at, and the route that shows it: the unit
/// the history records.
@immutable
class HistoryTarget {
  const HistoryTarget({
    required this.kind,
    required this.entityId,
    required this.route,
  });

  final HistoryEntityKind kind;
  final String entityId;
  final String route;

  /// Whether [other] opens the same entity, whatever route it came through.
  bool sameEntityAs(HistoryTarget other) =>
      kind == other.kind && entityId == other.entityId;

  @override
  bool operator ==(Object other) =>
      other is HistoryTarget &&
      other.kind == kind &&
      other.entityId == entityId &&
      other.route == route;

  @override
  int get hashCode => Object.hash(kind, entityId, route);

  @override
  String toString() => 'HistoryTarget($kind, $entityId, $route)';
}

/// The entity a route shows, or null for a route that shows none — a tab's
/// list, a create form, a settings page.
///
/// A sub-page of an entity (a person's chat, a project's edit form) counts as
/// a visit to the entity itself, recorded at the entity's main route, so
/// returning from history lands on the entity rather than on a form.
HistoryTarget? historyTargetForRoute(String route) {
  final segments = Uri.tryParse(route)?.pathSegments ?? const <String>[];
  if (segments.length < 2 || segments[1].isEmpty) return null;
  final id = segments[1];

  HistoryTarget target(HistoryEntityKind kind, String path) =>
      HistoryTarget(kind: kind, entityId: id, route: path);

  return switch (segments.first) {
    'tasks' when segments.length == 2 => target(
      HistoryEntityKind.task,
      '/tasks/$id',
    ),
    'journal' when segments.length == 2 => target(
      HistoryEntityKind.entry,
      '/journal/$id',
    ),
    'projects' => target(HistoryEntityKind.project, '/projects/$id'),
    'events' when segments.length == 2 => target(
      HistoryEntityKind.event,
      '/events/$id',
    ),
    'people' => target(HistoryEntityKind.person, '/people/$id'),
    'dashboards' when segments.length == 2 && id != 'impact' => target(
      HistoryEntityKind.dashboard,
      '/dashboards/$id',
    ),
    'habits' when segments.length == 3 && id == 'edit' => HistoryTarget(
      kind: HistoryEntityKind.habit,
      entityId: segments[2],
      route: '/habits/edit/${segments[2]}',
    ),
    _ => null,
  };
}

/// One stored visit.
@immutable
class HistoryEntry {
  const HistoryEntry({
    required this.id,
    required this.target,
    required this.visitedAt,
  });

  /// The row id: grows with every append, so it orders the log.
  final int id;
  final HistoryTarget target;
  final DateTime visitedAt;

  /// The entry a stored row describes, or null for a row whose kind this
  /// build does not know (written by a newer build, then downgraded).
  static HistoryEntry? fromRow(HistoryEntryRow row) {
    final kind = HistoryEntityKind.tryParse(row.kind);
    if (kind == null) return null;
    return HistoryEntry(
      id: row.id,
      target: HistoryTarget(
        kind: kind,
        entityId: row.entityId,
        route: row.route,
      ),
      visitedAt: row.visitedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is HistoryEntry &&
      other.id == id &&
      other.target == target &&
      other.visitedAt == visitedAt;

  @override
  int get hashCode => Object.hash(id, target, visitedAt);
}

/// A stored visit with the entity's title as it reads now.
@immutable
class ResolvedHistoryEntry {
  const ResolvedHistoryEntry({required this.entry, required this.title});

  final HistoryEntry entry;

  /// The entity's current title — possibly empty, for an untitled task — or
  /// null when the entity no longer exists (deleted, or hidden as private).
  final String? title;

  bool get isGone => title == null;
}
