import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/recent_searches/domain/recent_search.dart';
import 'package:lotti/get_it.dart';

/// Settings row holding the Recents snapshot.
const recentSearchesSettingsKey = 'RECENT_SEARCHES';

final recentSearchesRepositoryProvider = Provider<RecentSearchesRepository>(
  (ref) => RecentSearchesRepository(getIt<SettingsDb>()),
);

/// Reads and writes the Recents list as one JSON row in [SettingsDb].
///
/// Device-local on purpose: `SettingsDb` is never synced, and a search
/// history is about what was looked for on *this* phone. Nothing here
/// enqueues an outbox message.
class RecentSearchesRepository {
  RecentSearchesRepository(this._settingsDb);

  final SettingsDb _settingsDb;

  /// The stored list, newest first; empty when nothing readable is stored.
  Future<List<RecentSearch>> load() async => decodeRecentSearches(
    await _settingsDb.itemByKey(recentSearchesSettingsKey),
  );

  /// Replaces the stored list with [searches].
  Future<void> save(List<RecentSearch> searches) =>
      _settingsDb.saveSettingsItem(
        recentSearchesSettingsKey,
        encodeRecentSearches(searches),
      );
}
