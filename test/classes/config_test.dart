import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/config.dart';

void main() {
  group('SyncProvisioningBundle', () {
    const bundle = SyncProvisioningBundle(
      v: 2,
      kind: SyncBundleKind.provisioned,
      homeServer: 'https://matrix.example.com',
      user: '@alice:example.com',
      password: 'super-secret-pw',
      roomId: '!room123:example.com',
    );

    test('toString redacts the password', () {
      final str = bundle.toString();

      expect(str, contains('homeServer: https://matrix.example.com'));
      expect(str, contains('user: @alice:example.com'));
      expect(str, contains('roomId: !room123:example.com'));
      expect(str, contains('kind: provisioned'));
      expect(str, contains('password: <redacted>'));
      expect(str, isNot(contains('super-secret-pw')));
    });

    test('fromJson round-trips correctly', () {
      final json = bundle.toJson();
      final decoded = SyncProvisioningBundle.fromJson(json);

      expect(decoded.v, 2);
      expect(decoded.kind, SyncBundleKind.provisioned);
      expect(decoded.homeServer, 'https://matrix.example.com');
      expect(decoded.user, '@alice:example.com');
      expect(decoded.password, 'super-secret-pw');
      expect(decoded.roomId, '!room123:example.com');
    });

    test('fromJson handles JSON string round-trip', () {
      final jsonString = jsonEncode(bundle.toJson());
      final decoded = SyncProvisioningBundle.fromJson(
        jsonDecode(jsonString) as Map<String, dynamic>,
      );

      expect(decoded, bundle);
    });

    test('handover kind serialises as "handover"', () {
      const handover = SyncProvisioningBundle(
        v: 2,
        kind: SyncBundleKind.handover,
        homeServer: 'https://matrix.example.com',
        user: '@alice:example.com',
        password: 'rotated',
        roomId: '!room123:example.com',
      );

      final json = handover.toJson();
      expect(json['kind'], 'handover');

      final decoded = SyncProvisioningBundle.fromJson(json);
      expect(decoded.kind, SyncBundleKind.handover);
    });
  });
}
