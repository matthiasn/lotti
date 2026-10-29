import 'dart:async';

import 'package:lotti/database/database.dart';
import 'package:lotti/database/fts5_db.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/domain_logging.dart';

/// Keeps the search index ([Fts5Db]) in step with the journal.
///
/// Every journal write announces its ids on [UpdateNotifications.updateStream]
/// — local edits, sync, agents and imports alike — so indexing from that one
/// stream is what makes an entry searchable on every device, however it got
/// there. [start] also resumes a rebuild the index still owes the journal
/// after it was created, upgraded or reset.
///
/// The index is resolved on every use: the maintenance rebuild replaces it.
class SearchIndexService {
  SearchIndexService({
    required this._journalDb,
    required this._fts5Db,
    required this._updateNotifications,
    required this._domainLogger,
  });

  final JournalDb _journalDb;
  final Fts5Db Function() _fts5Db;
  final UpdateNotifications _updateNotifications;
  final DomainLogger _domainLogger;

  StreamSubscription<Set<String>>? _subscription;
  bool _disposed = false;

  /// Starts indexing changes and catches up with the journal. The returned
  /// future completes once the index has caught up (or [dispose] stopped
  /// it); changes are indexed meanwhile either way.
  Future<void> start() async {
    _subscription ??= _updateNotifications.updateStream.listen(_index);
    try {
      final fts5Db = _fts5Db();
      if (!await fts5Db.needsCatchUp()) return;
      final indexed = await fts5Db.catchUp(
        _journalDb,
        shouldContinue: () => !_disposed,
      );
      _domainLogger.log(
        LogDomain.database,
        'search index caught up: $indexed entities',
        subDomain: 'SearchIndexService',
      );
    } catch (error, stackTrace) {
      _logError(error, stackTrace, 'catchUp');
    }
  }

  Future<void> _index(Set<String> ids) async {
    if (_disposed) return;
    try {
      await _fts5Db().indexByIds(_journalDb, ids);
    } catch (error, stackTrace) {
      _logError(error, stackTrace, 'indexByIds');
    }
  }

  void _logError(Object error, StackTrace stackTrace, String operation) =>
      _domainLogger.error(
        LogDomain.database,
        error,
        stackTrace: stackTrace,
        subDomain: 'SearchIndexService.$operation',
      );

  Future<void> dispose() async {
    _disposed = true;
    await _subscription?.cancel();
    _subscription = null;
  }
}
