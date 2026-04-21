import 'package:lotti/database/database.dart';
import 'package:lotti/utils/consts.dart';

/// Reads the Phase-2 queue feature flag from [JournalDb]'s
/// `config_flags` table under [useInboundEventQueueFlag]. Defaults to
/// `false` when the row is missing, so a fresh install keeps the
/// legacy pipeline until the user flips the switch on the Flags page.
/// `MatrixService.init()` reads this once at startup and latches the
/// result via `_suppressLegacyPipeline` in the ctor — flips require a
/// restart to take effect.
Future<bool> readUseInboundEventQueueFlag(JournalDb journalDb) {
  return journalDb.getConfigFlag(useInboundEventQueueFlag);
}

/// Writes the Phase-2 queue feature flag. Exposed so tests and the
/// Flags page can toggle it; the change takes effect on the next
/// `MatrixService` init.
Future<void> writeUseInboundEventQueueFlag(
  JournalDb journalDb, {
  required bool enabled,
}) async {
  await journalDb.upsertConfigFlag(
    ConfigFlag(
      name: useInboundEventQueueFlag,
      description:
          'Use the queue pipeline for inbound sync (requires restart).',
      status: enabled,
    ),
  );
}
