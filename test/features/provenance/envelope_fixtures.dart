import 'package:lotti/features/provenance/model/envelope.dart';

/// Values from an independent Python reference (hashlib and `cryptography`),
/// signed with the key of RFC 8032 test 1. The provenance tests check the
/// Dart code reproduces them byte for byte.
abstract final class EnvelopeReference {
  /// RFC 8032 test 1 seed.
  static const seed =
      '9d61b19deffd5a60ba844af492ec2cc44449c5697b326919703bac031cae7f60';

  /// RFC 8032 test 1 public key.
  static const publicKey =
      'd75a980182b10ab7d54bfed3c964073a0ee172f3daa62325af021a68f707511a';

  /// deviceIdFor(publicKey).
  static const deviceId =
      '5dc0caffa98f3f38bfa85ad78cb4d78a382a83fbc76c5e1e2ea613fcad0fc886';

  /// SHA-256("prev").
  static const prev =
      '84fd9bac333ad79154348296204fa7f8c537a96e08983e5f73b3f5aca8e8edf7';

  /// SHA-256("head-a") and SHA-256("head-b"), sorted.
  static const causalRefs = [
    '50b0d24a8cc4b056fc2511411216b52fcfb6fcc515bdbdaed0b2e2c1befa959e',
    'd3a3d7295bcf00bda335a69b6bdc103071045844f70dff6716c823206d60fba7',
  ];

  /// The commitment to "call mum" under salt 00..1f.
  static const contentCommitment =
      'fbc440ce535ca1fff8f24ab84c7e951cbe4f9ab7e1e56d4ef8e8ba32b78db970';

  static const signature =
      'b862c72f839204b9d76f859a0362a594f5e4bed27202725bb09470eb26d93b43'
      '7cf6f0e8221f835abac6bb9fddb69683a6e4d1f8956c4e986cf5bef9b8b57f0e';

  static const hash =
      '4cb268df2f3b20636ac7cfb8ddda4498e2cc8c20d3fc5ed544bc4d3edd27b8fa';

  static const signingJson =
      '{"author":{"id":"user","type":"user"},'
      '"causal_refs":["$_refA","$_refB"],'
      '"claimed_time":"2026-09-26T08:30:00.000Z",'
      '"content_commitment":"$contentCommitment",'
      '"device_id":"$deviceId","kind":"record","prev":"$prev",'
      '"refs":{"supersedes":"$prev"},"seq":1,'
      '"vector_clock":{"host-a":3,"host-b":1},"version":1}';

  static const wireJson =
      '{"author":{"id":"user","type":"user"},'
      '"causal_refs":["$_refA","$_refB"],'
      '"claimed_time":"2026-09-26T08:30:00.000Z",'
      '"content_commitment":"$contentCommitment",'
      '"device_id":"$deviceId","kind":"record","prev":"$prev",'
      '"refs":{"supersedes":"$prev"},"seq":1,'
      '"signature":"$signature",'
      '"vector_clock":{"host-a":3,"host-b":1},"version":1}';

  static const _refA =
      '50b0d24a8cc4b056fc2511411216b52fcfb6fcc515bdbdaed0b2e2c1befa959e';
  static const _refB =
      'd3a3d7295bcf00bda335a69b6bdc103071045844f70dff6716c823206d60fba7';
}

/// The reference envelope, unsigned. Overrides build variants of it.
Envelope referenceEnvelope({
  EnvelopeKind kind = EnvelopeKind.record,
  String deviceId = EnvelopeReference.deviceId,
  int seq = 1,
  String? prev = EnvelopeReference.prev,
  List<String> causalRefs = EnvelopeReference.causalRefs,
  Map<String, int> vectorClock = const {'host-a': 3, 'host-b': 1},
  EnvelopeAuthor author = const EnvelopeAuthor(
    type: AuthorType.user,
    id: 'user',
  ),
  DateTime? claimedTime,
  String? contentCommitment = EnvelopeReference.contentCommitment,
  Map<String, Object?> refs = const {'supersedes': EnvelopeReference.prev},
  String? signature,
}) => Envelope(
  kind: kind,
  deviceId: deviceId,
  seq: seq,
  prev: prev,
  causalRefs: causalRefs,
  vectorClock: vectorClock,
  author: author,
  claimedTime: claimedTime ?? DateTime.utc(2026, 9, 26, 8, 30),
  contentCommitment: contentCommitment,
  refs: refs,
  signature: signature,
);
