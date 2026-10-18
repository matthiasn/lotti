import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/sync/subscription/sync_subscription_api.dart';
import 'package:lotti/features/sync/subscription/sync_subscription_store.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

const _record = SyncSubscriptionRecord(
  entitlement: SyncEntitlement(id: 'ent-1', authSecret: 'auth'),
  claimSecret: 'claim',
);
const _proof = PendingRotationProof(
  bundleId: 'b-1',
  roomId: '!room:example.com',
  challenge: 'challenge',
);

void main() {
  late MockSecureStorage storage;
  late SyncSubscriptionStore store;
  String? stored;

  setUp(() {
    stored = null;
    storage = MockSecureStorage();
    when(
      () => storage.read(key: syncSubscriptionKey),
    ).thenAnswer((_) async => stored);
    when(
      () => storage.write(
        key: syncSubscriptionKey,
        value: any(named: 'value'),
      ),
    ).thenAnswer((invocation) async {
      stored = invocation.namedArguments[#value] as String;
    });
    store = SyncSubscriptionStore(storage);
  });

  test('nothing stored reads as no subscription', () async {
    expect(await store.load(), isNull);
  });

  test(
    'a record with session and pending proof survives the keystore',
    () async {
      await store.save(_record.withSession('sess-1').withPendingProof(_proof));

      final loaded = await store.load();

      expect(loaded!.entitlement.id, 'ent-1');
      expect(loaded.entitlement.authSecret, 'auth');
      expect(loaded.claimSecret, 'claim');
      expect(loaded.sessionId, 'sess-1');
      expect(loaded.pendingProof!.bundleId, 'b-1');
      expect(loaded.pendingProof!.roomId, '!room:example.com');
      expect(loaded.pendingProof!.challenge, 'challenge');
    },
  );

  test('clearing session and proof leaves only the credentials', () async {
    await store.save(
      _record
          .withSession('sess-1')
          .withPendingProof(_proof)
          .withSession(null)
          .withPendingProof(null),
    );

    expect(jsonDecode(stored!), {
      'entitlementId': 'ent-1',
      'authSecret': 'auth',
      'claimSecret': 'claim',
    });
  });

  test('a record this build cannot read is treated as absent', () async {
    stored = '{"entitlementId": 7}';

    expect(await store.load(), isNull);
  });
}
