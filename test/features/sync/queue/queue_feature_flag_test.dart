import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/journal_db/config_flags.dart';
import 'package:lotti/features/sync/queue/queue_feature_flag.dart';

void main() {
  late JournalDb journalDb;

  setUp(() async {
    journalDb = JournalDb(inMemoryDatabase: true);
    await initConfigFlags(journalDb, inMemoryDatabase: true);
  });

  tearDown(() async {
    await journalDb.close();
  });

  test(
    'missing / default row reads as false — fresh installs keep the '
    'legacy pipeline until the user flips the Flags-page switch',
    () async {
      final enabled = await readUseInboundEventQueueFlag(journalDb);
      expect(enabled, isFalse);
    },
  );

  test(
    'writeUseInboundEventQueueFlag(enabled: true) flips the flag to '
    'true and subsequent reads observe it',
    () async {
      await writeUseInboundEventQueueFlag(journalDb, enabled: true);
      expect(await readUseInboundEventQueueFlag(journalDb), isTrue);
    },
  );

  test(
    'writeUseInboundEventQueueFlag(enabled: false) is idempotent and '
    'restores the default',
    () async {
      await writeUseInboundEventQueueFlag(journalDb, enabled: true);
      await writeUseInboundEventQueueFlag(journalDb, enabled: false);
      expect(await readUseInboundEventQueueFlag(journalDb), isFalse);
    },
  );
}
