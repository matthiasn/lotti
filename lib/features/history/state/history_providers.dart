import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/database/history_db.dart';
import 'package:lotti/features/history/state/history_recorder.dart';
import 'package:lotti/features/history/state/history_service.dart';
import 'package:lotti/features/history/state/history_title_resolver.dart';
import 'package:lotti/providers/service_providers.dart';

/// The active profile's history database, or null on a host that wires none
/// (a bare test). The composition root binds the generation's instance; with
/// null, nothing is recorded and the History command is unavailable.
final historyDbProvider = Provider<HistoryDb?>(
  (ref) => null,
  name: 'historyDbProvider',
);

/// The history service over [historyDbProvider]. Read only where the history
/// is available — [historyAvailableProvider] says so.
final historyServiceProvider = Provider<HistoryService>((ref) {
  final db = ref.watch(historyDbProvider);
  if (db == null) {
    throw StateError('historyServiceProvider read without a HistoryDb');
  }
  return HistoryService(
    db: db,
    titleResolver: HistoryTitleResolver(ref.watch(journalDbProvider)),
  );
}, name: 'historyServiceProvider');

/// Whether this host records and shows history.
final historyAvailableProvider = Provider<bool>(
  (ref) => ref.watch(historyDbProvider) != null,
  name: 'historyAvailableProvider',
);

/// The running [HistoryRecorder], or null where the history is unavailable.
/// Kept alive for the session: the app root listens to it from startup, so
/// navigation is recorded before the history page is ever opened.
final historyRecorderProvider = Provider<HistoryRecorder?>((ref) {
  if (!ref.watch(historyAvailableProvider)) return null;
  final recorder = HistoryRecorder(
    navService: ref.watch(navServiceProvider),
    service: ref.watch(historyServiceProvider),
    logger: ref.watch(domainLoggerProvider),
  )..start();
  ref.onDispose(recorder.dispose);
  return recorder;
}, name: 'historyRecorderProvider');
