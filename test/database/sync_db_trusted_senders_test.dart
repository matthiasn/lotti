import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/sync_db.dart';

const _me = '@me:example.org';
const _other = '@other:example.org';

void main() {
  late SyncDatabase db;

  setUp(() => db = SyncDatabase(inMemoryDatabase: true));
  tearDown(() => db.close());

  test('a remembered sender is trusted only for its own user', () async {
    await db.rememberTrustedSyncSender(
      userId: _me,
      curve25519Key: 'curve-a',
      deviceId: 'A',
    );

    expect(
      await db.isTrustedSyncSender(userId: _me, curve25519Key: 'curve-a'),
      isTrue,
    );
    expect(
      await db.isTrustedSyncSender(userId: _other, curve25519Key: 'curve-a'),
      isFalse,
    );
    expect(
      await db.isTrustedSyncSender(userId: _me, curve25519Key: 'curve-b'),
      isFalse,
    );
  });

  test('remembering again keeps the first sighting', () async {
    await withClock(Clock.fixed(DateTime(2026, 9)), () async {
      await db.rememberTrustedSyncSender(
        userId: _me,
        curve25519Key: 'curve-a',
        deviceId: 'A',
      );
    });
    await withClock(Clock.fixed(DateTime(2026, 10)), () async {
      await db.rememberTrustedSyncSender(
        userId: _me,
        curve25519Key: 'curve-a',
        deviceId: 'A-renamed',
      );
    });

    final rows = await db.select(db.trustedSyncSenders).get();
    expect(rows, hasLength(1));
    expect(rows.single.deviceId, 'A');
    expect(rows.single.trustedAt, DateTime(2026, 9));
  });

  test('forgetting removes only that sender', () async {
    await db.rememberTrustedSyncSender(
      userId: _me,
      curve25519Key: 'curve-a',
      deviceId: 'A',
    );
    await db.rememberTrustedSyncSender(
      userId: _me,
      curve25519Key: 'curve-b',
      deviceId: 'B',
    );

    await db.forgetTrustedSyncSender(userId: _me, curve25519Key: 'curve-a');

    expect(
      await db.isTrustedSyncSender(userId: _me, curve25519Key: 'curve-a'),
      isFalse,
    );
    expect(
      await db.isTrustedSyncSender(userId: _me, curve25519Key: 'curve-b'),
      isTrue,
    );
  });
}
