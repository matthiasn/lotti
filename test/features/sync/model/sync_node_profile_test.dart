import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/sync/model/sync_node_profile.dart';

// ---------------------------------------------------------------------------
// Glados helpers — generated value classes are private and carry a toString()
// so shrunk counterexamples print readably.
// ---------------------------------------------------------------------------

/// A generated [SyncNodeProfile] shape. Holds primitive inputs only; the test
/// reconstructs the real freezed object and round-trips it through JSON.
class _GeneratedNodeProfile {
  const _GeneratedNodeProfile({
    required this.hostId,
    required this.displayName,
    required this.platform,
    required this.capabilities,
    required this.updatedAtMs,
    required this.osVersion,
    required this.cpuModel,
    required this.gpuModel,
    required this.ramMb,
    required this.appVersion,
  });

  final String hostId;
  final String displayName;
  final String platform;
  final List<NodeCapability> capabilities;

  /// Milliseconds-since-epoch offset; turned into a deterministic UTC
  /// [DateTime] in the test (never [DateTime.now]).
  final int updatedAtMs;

  final String? osVersion;
  final String? cpuModel;
  final String? gpuModel;
  final int? ramMb;
  final String? appVersion;

  @override
  String toString() =>
      '_GeneratedNodeProfile('
      'hostId: $hostId, '
      'displayName: $displayName, '
      'platform: $platform, '
      'capabilities: $capabilities, '
      'updatedAtMs: $updatedAtMs, '
      'osVersion: $osVersion, '
      'cpuModel: $cpuModel, '
      'gpuModel: $gpuModel, '
      'ramMb: $ramMb, '
      'appVersion: $appVersion'
      ')';
}

extension _AnyNodeProfileGlados on glados.Any {
  glados.Generator<NodeCapability> get _nodeCapability =>
      glados.AnyUtils(this).choose(NodeCapability.values);

  /// A nullable letter-or-digit string: `null` ~half the time, otherwise an
  /// arbitrary (possibly empty) token.
  glados.Generator<String?> get _optionalString =>
      glados.CombinableAny(this).combine2(
        glados.BoolAny(this).bool,
        glados.StringAnys(this).letterOrDigits,
        (bool include, String s) => include ? s : null,
      );

  glados.Generator<int?> get _optionalInt =>
      glados.CombinableAny(this).combine2(
        glados.BoolAny(this).bool,
        glados.IntAnys(this).intInRange(0, 1048576),
        (bool include, int n) => include ? n : null,
      );

  glados.Generator<_GeneratedNodeProfile> get generatedNodeProfile =>
      glados.CombinableAny(this).combine10(
        glados.StringAnys(this).letterOrDigits,
        glados.StringAnys(this).letterOrDigits,
        glados.StringAnys(this).letterOrDigits,
        glados.ListAnys(this).listWithLengthInRange(0, 4, _nodeCapability),
        glados.IntAnys(this).intInRange(0, 4102444800000),
        _optionalString,
        _optionalString,
        _optionalString,
        _optionalInt,
        _optionalString,
        (
          String hostId,
          String displayName,
          String platform,
          List<NodeCapability> capabilities,
          int updatedAtMs,
          String? osVersion,
          String? cpuModel,
          String? gpuModel,
          int? ramMb,
          String? appVersion,
        ) => _GeneratedNodeProfile(
          hostId: hostId,
          displayName: displayName,
          platform: platform,
          capabilities: capabilities,
          updatedAtMs: updatedAtMs,
          osVersion: osVersion,
          cpuModel: cpuModel,
          gpuModel: gpuModel,
          ramMb: ramMb,
          appVersion: appVersion,
        ),
      );
}

SyncNodeProfile _buildProfile(_GeneratedNodeProfile gen) => SyncNodeProfile(
  hostId: gen.hostId,
  displayName: gen.displayName,
  platform: gen.platform,
  capabilities: gen.capabilities,
  // Deterministic UTC instant derived from the generated offset.
  updatedAt: DateTime.fromMillisecondsSinceEpoch(gen.updatedAtMs, isUtc: true),
  osVersion: gen.osVersion,
  cpuModel: gen.cpuModel,
  gpuModel: gen.gpuModel,
  ramMb: gen.ramMb,
  appVersion: gen.appVersion,
);

SyncNodeProfile _roundTripProfile(SyncNodeProfile profile) =>
    SyncNodeProfile.fromJson(
      jsonDecode(jsonEncode(profile.toJson())) as Map<String, dynamic>,
    );

void main() {
  group('SyncNodeProfile JSON round-trip', () {
    final updatedAt = DateTime.utc(2026, 3, 15, 12, 30);

    test('serializes and deserializes a fully-populated profile', () {
      final profile = SyncNodeProfile(
        hostId: 'host-uuid-1',
        displayName: 'Studio Mac',
        platform: 'macos',
        osVersion: '15.2',
        cpuModel: 'Apple M4 Max',
        ramMb: 65536,
        gpuModel: 'Apple M4 Max GPU',
        appVersion: '1.0.0+1',
        capabilities: const [
          NodeCapability.mlxAudio,
          NodeCapability.ollamaLlm,
        ],
        updatedAt: updatedAt,
      );

      final encoded = jsonEncode(profile.toJson());
      final decoded = SyncNodeProfile.fromJson(
        jsonDecode(encoded) as Map<String, dynamic>,
      );

      expect(decoded.hostId, 'host-uuid-1');
      expect(decoded.displayName, 'Studio Mac');
      expect(decoded.platform, 'macos');
      expect(decoded.osVersion, '15.2');
      expect(decoded.cpuModel, 'Apple M4 Max');
      expect(decoded.ramMb, 65536);
      expect(decoded.gpuModel, 'Apple M4 Max GPU');
      expect(decoded.appVersion, '1.0.0+1');
      expect(decoded.capabilities, [
        NodeCapability.mlxAudio,
        NodeCapability.ollamaLlm,
      ]);
      expect(decoded.updatedAt, updatedAt);
    });

    test('preserves capability list order across serialization', () {
      final original = SyncNodeProfile(
        hostId: 'host-uuid-2',
        displayName: 'Linux Box',
        platform: 'linux',
        capabilities: const [
          NodeCapability.whisper,
          NodeCapability.ollamaLlm,
          NodeCapability.voxtral,
        ],
        updatedAt: updatedAt,
      );

      final decoded = SyncNodeProfile.fromJson(
        jsonDecode(jsonEncode(original.toJson())) as Map<String, dynamic>,
      );

      expect(decoded.capabilities, [
        NodeCapability.whisper,
        NodeCapability.ollamaLlm,
        NodeCapability.voxtral,
      ]);
    });

    test('defaults optional hardware fields to null when omitted', () {
      final profile = SyncNodeProfile(
        hostId: 'host-uuid-3',
        displayName: 'Bare Mac',
        platform: 'macos',
        capabilities: const [NodeCapability.mlxAudio],
        updatedAt: updatedAt,
      );

      final decoded = SyncNodeProfile.fromJson(
        jsonDecode(jsonEncode(profile.toJson())) as Map<String, dynamic>,
      );

      expect(decoded.osVersion, isNull);
      expect(decoded.cpuModel, isNull);
      expect(decoded.ramMb, isNull);
      expect(decoded.gpuModel, isNull);
      expect(decoded.appVersion, isNull);
    });

    test('ignores unknown JSON fields (forward compatibility)', () {
      final json = {
        'hostId': 'host-uuid-4',
        'displayName': 'Future Mac',
        'platform': 'macos',
        'capabilities': <String>[],
        'updatedAt': updatedAt.toIso8601String(),
        'unknownFutureField': 'should be ignored',
      };

      final decoded = SyncNodeProfile.fromJson(json);

      expect(decoded.hostId, 'host-uuid-4');
      expect(decoded.capabilities, isEmpty);
    });
  });

  group('SyncNodeProfile value equality', () {
    final updatedAt = DateTime.utc(2026, 3, 15, 12, 30);

    test('equal profiles compare equal', () {
      final a = SyncNodeProfile(
        hostId: 'h',
        displayName: 'A',
        platform: 'macos',
        capabilities: const [NodeCapability.mlxAudio],
        updatedAt: updatedAt,
      );
      final b = SyncNodeProfile(
        hostId: 'h',
        displayName: 'A',
        platform: 'macos',
        capabilities: const [NodeCapability.mlxAudio],
        updatedAt: updatedAt,
      );

      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('differing displayName compares unequal', () {
      final a = SyncNodeProfile(
        hostId: 'h',
        displayName: 'A',
        platform: 'macos',
        capabilities: const [NodeCapability.mlxAudio],
        updatedAt: updatedAt,
      );
      final b = SyncNodeProfile(
        hostId: 'h',
        displayName: 'B',
        platform: 'macos',
        capabilities: const [NodeCapability.mlxAudio],
        updatedAt: updatedAt,
      );

      expect(a, isNot(b));
    });

    test('differing capability list compares unequal', () {
      final a = SyncNodeProfile(
        hostId: 'h',
        displayName: 'A',
        platform: 'macos',
        capabilities: const [NodeCapability.mlxAudio],
        updatedAt: updatedAt,
      );
      final b = SyncNodeProfile(
        hostId: 'h',
        displayName: 'A',
        platform: 'macos',
        capabilities: const [
          NodeCapability.mlxAudio,
          NodeCapability.ollamaLlm,
        ],
        updatedAt: updatedAt,
      );

      expect(a, isNot(b));
    });

    test('differing hostId compares unequal', () {
      // hostId is the per-device identity key (the VectorClockService host
      // UUID); receivers store the latest snapshot per hostId, so equality
      // must distinguish two profiles that differ only by host.
      final a = SyncNodeProfile(
        hostId: 'host-a',
        displayName: 'A',
        platform: 'macos',
        capabilities: const [NodeCapability.mlxAudio],
        updatedAt: updatedAt,
      );
      final b = SyncNodeProfile(
        hostId: 'host-b',
        displayName: 'A',
        platform: 'macos',
        capabilities: const [NodeCapability.mlxAudio],
        updatedAt: updatedAt,
      );

      expect(a, isNot(b));
    });

    test('differing updatedAt compares unequal', () {
      // updatedAt is the broadcast timestamp used to decide which snapshot
      // wins on upsert; two otherwise-identical profiles with different
      // timestamps must not collapse to equal or the newer one could be
      // dropped as a duplicate.
      final a = SyncNodeProfile(
        hostId: 'h',
        displayName: 'A',
        platform: 'macos',
        capabilities: const [NodeCapability.mlxAudio],
        updatedAt: updatedAt,
      );
      final b = SyncNodeProfile(
        hostId: 'h',
        displayName: 'A',
        platform: 'macos',
        capabilities: const [NodeCapability.mlxAudio],
        updatedAt: updatedAt.add(const Duration(seconds: 1)),
      );

      expect(a, isNot(b));
    });
  });

  group('SyncNodeProfile — Glados JSON round-trip', () {
    glados.Glados(
      glados.any.generatedNodeProfile,
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'decode(encode(profile)) preserves every field for any generated shape',
      (gen) {
        final original = _buildProfile(gen);
        final decoded = _roundTripProfile(original);

        // Whole-object value equality is the strongest invariant: it covers
        // the freezed-generated == across all scalars, the capability list,
        // the DateTime, and every optional field at once. Any future field
        // that fails to (de)serialize breaks this without a new static test.
        expect(decoded, original, reason: '$gen');

        // Spell out a few fields so a failure points at the culprit instead
        // of just "objects differ".
        expect(decoded.hostId, gen.hostId, reason: '$gen');
        expect(decoded.capabilities, gen.capabilities, reason: '$gen');
        expect(decoded.updatedAt, original.updatedAt, reason: '$gen');
        expect(decoded.updatedAt.isUtc, isTrue, reason: '$gen');
        expect(decoded.ramMb, gen.ramMb, reason: '$gen');
      },
      tags: 'glados',
    );

    glados.Glados(
      glados.any.generatedNodeProfile,
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'capability list order is preserved across serialization',
      (gen) {
        final decoded = _roundTripProfile(_buildProfile(gen));
        // Equality alone would pass on a reordering only if NodeCapability
        // lists compared order-insensitively; assert positional order to lock
        // the wire contract independently of list-equality semantics.
        expect(
          decoded.capabilities,
          orderedEquals(gen.capabilities),
          reason: '$gen',
        );
      },
      tags: 'glados',
    );
  });
}
