import 'package:get_it/get_it.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/sync/isolate/sync_isolate_host.dart';
import 'package:lotti/features/sync/isolate/sync_isolate_worker.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/utils/consts.dart';

/// Starts the sync isolate when `use_isolate_sync` is on (ADR 0142), for a
/// real profile's sync stack — guest worlds never reach this.
///
/// With the flag off — the default — nothing is constructed and production
/// sync is exactly what it was. With it on, the host is registered in
/// [getIt], so a profile switch disposes it with everything else, and
/// started; startup does not wait for the spawn, and the host logs the
/// handshake or retries a worker that will not start. Until later steps move
/// work behind it, the worker only proves it runs, while sync itself stays on
/// the UI isolate.
///
/// The flag is read once, here: toggling it takes effect at the next start.
/// Returns the host, or null when the flag is off.
Future<SyncIsolateHost?> registerSyncIsolateIfEnabled({
  required GetIt getIt,
  required JournalDb journalDb,
  required DomainLogger logger,
  SyncIsolateEntry entry = syncIsolateEntry,
}) async {
  if (!await journalDb.getConfigFlag(useIsolateSyncFlag)) return null;

  final host = SyncIsolateHost(logger: logger, entry: entry);
  getIt.registerSingleton<SyncIsolateHost>(
    host,
    dispose: (host) => host.dispose(),
  );
  host.start();
  return host;
}
