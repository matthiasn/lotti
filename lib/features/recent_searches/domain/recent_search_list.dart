import 'package:lotti/features/recent_searches/domain/recent_search.dart';

/// How many searches the Recents list keeps. The oldest falls off the end.
const maxRecentSearches = 12;

/// The shortest query worth remembering. A single character filters a list
/// but names nothing the user would want to find again.
const minRecentSearchLength = 2;

final _whitespaceRun = RegExp(r'\s+');

/// The form a query is remembered in: trimmed, with inner whitespace runs
/// collapsed to one space. Casing is kept — it is what the user typed and
/// what the field shows again when the search is reapplied.
String normalizeRecentSearchQuery(String raw) =>
    raw.trim().replaceAll(_whitespaceRun, ' ');

/// Whether [raw] is long enough, once normalized, to be remembered.
bool isRecordableRecentSearchQuery(String raw) =>
    normalizeRecentSearchQuery(raw).length >= minRecentSearchLength;

/// [current] (newest first) with a search for [rawQuery] on [surface]
/// recorded at the top.
///
/// Returns [current] itself — the identical list — when nothing is
/// recordable, so a caller can skip the state change and the write.
///
/// The app's searches filter as the user types, so there is no submit to
/// mark a query as finished; three rules keep the list to searches rather
/// than keystrokes:
///
/// - **A repeat moves up instead of doubling.** Any entry that
///   [RecentSearch.matches] the new one is dropped; the new casing wins.
/// - **A continuation replaces its own beginning.** When the surface's
///   newest entry is a case-insensitive prefix of the new query, the user
///   kept typing the same search after a pause, and the fragment goes.
///   Only that one newest entry is considered: an older, shorter search on
///   the same surface was a search of its own.
/// - **The list is capped** at [maxRecentSearches], oldest dropped first.
List<RecentSearch> recordRecentSearch(
  List<RecentSearch> current,
  RecentSearchSurface surface,
  String rawQuery,
) {
  if (!isRecordableRecentSearchQuery(rawQuery)) return current;
  final recorded = RecentSearch(
    surface: surface,
    query: normalizeRecentSearchQuery(rawQuery),
  );
  final loweredQuery = recorded.query.toLowerCase();

  var surfaceSeen = false;
  final kept = <RecentSearch>[];
  for (final entry in current) {
    final isNewestOnSurface = entry.surface == surface && !surfaceSeen;
    surfaceSeen = surfaceSeen || entry.surface == surface;
    if (entry.matches(recorded)) continue;
    if (isNewestOnSurface &&
        loweredQuery.startsWith(entry.query.toLowerCase())) {
      continue;
    }
    kept.add(entry);
  }
  return List.unmodifiable([recorded, ...kept.take(maxRecentSearches - 1)]);
}

/// The entries of [searches] whose surface is in [surfaces], order kept.
///
/// The sidebar passes the surfaces of the destinations enabled right now, so
/// a search remembered on a section the user has since switched off is not
/// offered as a row that could lead nowhere.
List<RecentSearch> recentSearchesOn(
  List<RecentSearch> searches,
  Set<RecentSearchSurface> surfaces,
) => [
  for (final search in searches)
    if (surfaces.contains(search.surface)) search,
];
