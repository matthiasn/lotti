import 'dart:convert';

import 'package:flutter/foundation.dart';

/// A place in the app whose search field feeds the Recents list.
///
/// One value per top-level destination that owns a content search. Adding a
/// surface is this enum value plus one recording call at the new field; the
/// list, its storage and the sidebar section need no change.
enum RecentSearchSurface {
  tasks('tasks'),
  logbook('logbook'),
  projects('projects'),
  habits('habits');

  const RecentSearchSurface(this.wireName);

  /// The name persisted in the settings row. Decoupled from [name] so a Dart
  /// rename cannot orphan stored history.
  final String wireName;

  /// The surface stored as [wireName], or null for a name this build does
  /// not know — an entry written by a newer build is skipped, not an error.
  static RecentSearchSurface? fromWireName(String wireName) {
    for (final surface in values) {
      if (surface.wireName == wireName) return surface;
    }
    return null;
  }
}

/// One remembered search: what was typed, and where.
@immutable
class RecentSearch {
  const RecentSearch({required this.surface, required this.query});

  final RecentSearchSurface surface;

  /// The query as the user typed it, already normalized by
  /// `normalizeRecentSearchQuery` — casing preserved.
  final String query;

  /// Whether [other] is the same search for list purposes: same surface and
  /// the same query ignoring case, so "Penguin" and "penguin" are one entry.
  bool matches(RecentSearch other) =>
      surface == other.surface &&
      query.toLowerCase() == other.query.toLowerCase();

  @override
  bool operator ==(Object other) =>
      other is RecentSearch && other.surface == surface && other.query == query;

  @override
  int get hashCode => Object.hash(surface, query);

  @override
  String toString() => 'RecentSearch(${surface.wireName}: "$query")';
}

/// Version of the persisted snapshot. A row with any other version decodes
/// to an empty list rather than being misread.
const recentSearchesSnapshotVersion = 1;

/// Encodes [searches], newest first, as the settings-row JSON:
/// `{"v":1,"items":[{"s":"tasks","q":"penguin"}]}`.
String encodeRecentSearches(List<RecentSearch> searches) => jsonEncode({
  'v': recentSearchesSnapshotVersion,
  'items': [
    for (final search in searches)
      {'s': search.surface.wireName, 'q': search.query},
  ],
});

/// Decodes a settings row written by [encodeRecentSearches].
///
/// Never throws: a missing, corrupt or unknown-version row is "nothing
/// remembered", and a single malformed or unknown-surface item is skipped
/// while the rest of the list survives.
List<RecentSearch> decodeRecentSearches(String? raw) {
  if (raw == null || raw.isEmpty) return const [];
  final Object? decoded;
  try {
    decoded = jsonDecode(raw);
  } on FormatException {
    return const [];
  }
  if (decoded is! Map<String, dynamic> ||
      decoded['v'] != recentSearchesSnapshotVersion) {
    return const [];
  }
  final items = decoded['items'];
  if (items is! List) return const [];
  return [for (final item in items) ?_decodeItem(item)];
}

RecentSearch? _decodeItem(Object? item) {
  if (item is! Map<String, dynamic>) return null;
  final wireName = item['s'];
  final query = item['q'];
  if (wireName is! String || query is! String || query.isEmpty) return null;
  final surface = RecentSearchSurface.fromWireName(wireName);
  if (surface == null) return null;
  return RecentSearch(surface: surface, query: query);
}
