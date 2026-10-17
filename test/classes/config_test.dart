import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/classes/config.dart';

void main() {
  group('MatrixConfig', () {
    glados.Glados(
      glados.any.generatedMatrixConfig,
      glados.ExploreConfig(numRuns: 120),
    ).test('round-trips generated Matrix configs through JSON', (scenario) {
      final config = scenario.config;

      final decoded = MatrixConfig.fromJson(
        jsonDecode(jsonEncode(config.toJson())) as Map<String, dynamic>,
      );

      expect(decoded, equals(config), reason: '$scenario');
      expect(decoded.password, config.password, reason: '$scenario');
    }, tags: 'glados');

    test(
      'an attestation survives the keystore round-trip; none adds no key',
      () {
        const attestation = BundleAttestation(
          kid: 'op-2026-10',
          iat: 1792238400,
          exp: 1792324800,
          sig: 'c2ln',
        );
        const plain = MatrixConfig(
          homeServer: 'https://matrix.example.com',
          user: '@alice:example.com',
          password: 'pw',
        );
        const signed = MatrixConfig(
          homeServer: 'https://matrix.example.com',
          user: '@alice:example.com',
          password: 'pw',
          attestation: attestation,
        );

        Map<String, dynamic> wire(MatrixConfig config) =>
            jsonDecode(jsonEncode(config.toJson())) as Map<String, dynamic>;

        expect(wire(plain).containsKey('attestation'), isFalse);
        expect(MatrixConfig.fromJson(wire(signed)), signed);
        // Configs written before attestations existed still load.
        expect(MatrixConfig.fromJson(wire(plain)).attestation, isNull);
      },
    );
  });

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
      expect(str, contains('signed: false'));
    });

    test('a v2 bundle has no att key; a v3 one round-trips it', () {
      const att = BundleAttestation(
        kid: 'op-2026-10',
        iat: 1792238400,
        exp: 1792324800,
        sig: 'c2ln',
      );
      final signed = bundle.copyWith(v: 3, att: att);

      final unsignedWire =
          jsonDecode(jsonEncode(bundle.toJson())) as Map<String, dynamic>;
      final signedWire =
          jsonDecode(jsonEncode(signed.toJson())) as Map<String, dynamic>;

      // Released clients parse v2 bundles; they never see an `att: null`.
      expect(unsignedWire.containsKey('att'), isFalse);
      expect(signedWire['att'], {
        'kid': 'op-2026-10',
        'iat': 1792238400,
        'exp': 1792324800,
        'sig': 'c2ln',
      });
      expect(SyncProvisioningBundle.fromJson(signedWire), signed);
      expect(signed.toString(), contains('signed: true'));
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

    glados.Glados(
      glados.any.generatedSyncProvisioningBundle,
      glados.ExploreConfig(numRuns: 160),
    ).test(
      'round-trips generated provisioning bundles and redacts secrets',
      (
        scenario,
      ) {
        final bundle = scenario.bundle;

        final decoded = SyncProvisioningBundle.fromJson(
          jsonDecode(jsonEncode(bundle.toJson())) as Map<String, dynamic>,
        );
        final string = bundle.toString();

        expect(decoded, equals(bundle), reason: '$scenario');
        expect(decoded.kind, bundle.kind, reason: '$scenario');
        expect(string, contains('password: <redacted>'), reason: '$scenario');
        expect(string, isNot(contains(bundle.password)), reason: '$scenario');
      },
      tags: 'glados',
    );
  });
}

class _GeneratedMatrixConfig {
  const _GeneratedMatrixConfig({
    required this.homeServerSlot,
    required this.userSlot,
    required this.passwordSlot,
  });

  final int homeServerSlot;
  final int userSlot;
  final int passwordSlot;

  MatrixConfig get config => MatrixConfig(
    homeServer: 'https://matrix-$homeServerSlot.example.com',
    user: '@user$userSlot:example.com',
    password: 'matrix-secret-$passwordSlot',
  );

  @override
  String toString() {
    return '_GeneratedMatrixConfig('
        'homeServerSlot: $homeServerSlot, '
        'userSlot: $userSlot, '
        'passwordSlot: $passwordSlot)';
  }
}

class _GeneratedSyncProvisioningBundle {
  const _GeneratedSyncProvisioningBundle({
    required this.version,
    required this.kind,
    required this.homeServerSlot,
    required this.userSlot,
    required this.passwordSlot,
    required this.roomSlot,
  });

  final int version;
  final SyncBundleKind kind;
  final int homeServerSlot;
  final int userSlot;
  final int passwordSlot;
  final int roomSlot;

  SyncProvisioningBundle get bundle => SyncProvisioningBundle(
    v: version,
    kind: kind,
    homeServer: 'https://server-$homeServerSlot.example.com',
    user: '@generated$userSlot:example.com',
    password: 'bundle-secret-$passwordSlot',
    roomId: '!room$roomSlot:example.com',
  );

  @override
  String toString() {
    return '_GeneratedSyncProvisioningBundle('
        'version: $version, '
        'kind: $kind, '
        'homeServerSlot: $homeServerSlot, '
        'userSlot: $userSlot, '
        'passwordSlot: $passwordSlot, '
        'roomSlot: $roomSlot)';
  }
}

extension _AnyConfig on glados.Any {
  glados.Generator<_GeneratedMatrixConfig> get generatedMatrixConfig =>
      glados.CombinableAny(this).combine3(
        glados.IntAnys(this).intInRange(0, 100),
        glados.IntAnys(this).intInRange(0, 100),
        glados.IntAnys(this).intInRange(0, 100),
        (
          int homeServerSlot,
          int userSlot,
          int passwordSlot,
        ) => _GeneratedMatrixConfig(
          homeServerSlot: homeServerSlot,
          userSlot: userSlot,
          passwordSlot: passwordSlot,
        ),
      );

  glados.Generator<_GeneratedSyncProvisioningBundle>
  get generatedSyncProvisioningBundle => glados.CombinableAny(this).combine6(
    glados.IntAnys(this).intInRange(1, 5),
    glados.AnyUtils(this).choose(SyncBundleKind.values),
    glados.IntAnys(this).intInRange(0, 100),
    glados.IntAnys(this).intInRange(0, 100),
    glados.IntAnys(this).intInRange(0, 100),
    glados.IntAnys(this).intInRange(0, 100),
    (
      int version,
      SyncBundleKind kind,
      int homeServerSlot,
      int userSlot,
      int passwordSlot,
      int roomSlot,
    ) => _GeneratedSyncProvisioningBundle(
      version: version,
      kind: kind,
      homeServerSlot: homeServerSlot,
      userSlot: userSlot,
      passwordSlot: passwordSlot,
      roomSlot: roomSlot,
    ),
  );
}
