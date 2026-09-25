import 'package:collection/collection.dart';
import 'package:lotti/features/provenance/crypto/canonical_json.dart';
import 'package:lotti/features/provenance/crypto/ed25519.dart';
import 'package:lotti/features/provenance/crypto/hex.dart';
import 'package:meta/meta.dart';

/// The envelope format this code writes and accepts.
const int envelopeVersion = 1;

/// Length of every hash an envelope carries (SHA-256), in bytes.
const int envelopeHashLength = 32;

/// Thrown for an envelope that breaks the structural rules of v1.
class EnvelopeFormatException implements Exception {
  const EnvelopeFormatException(this.message);

  final String message;

  @override
  String toString() => 'EnvelopeFormatException: $message';
}

/// What an envelope records.
enum EnvelopeKind {
  record('record'),
  edit('edit'),
  proposal('proposal'),
  approval('approval'),
  rejection('rejection'),
  tombstone('tombstone'),
  derivation('derivation'),
  deviceCert('device_cert'),
  deviceRevocation('device_revocation'),
  migrationAttestation('migration_attestation');

  const EnvelopeKind(this.wireName);

  final String wireName;

  static EnvelopeKind fromWire(Object? value) => EnvelopeKind.values.firstWhere(
    (kind) => kind.wireName == value,
    orElse: () => throw EnvelopeFormatException('unknown kind $value'),
  );
}

/// Who authored an envelope's content — never the device that signed it.
enum AuthorType {
  user('user'),
  agent('agent'),
  system('system');

  const AuthorType(this.wireName);

  final String wireName;

  static AuthorType fromWire(Object? value) => AuthorType.values.firstWhere(
    (type) => type.wireName == value,
    orElse: () => throw EnvelopeFormatException('unknown author type $value'),
  );
}

/// The author of an envelope. For an agent, [id] is the agent id, [model] the
/// model it ran on, and [contextHash] the hash of the input it was given.
@immutable
class EnvelopeAuthor {
  const EnvelopeAuthor({
    required this.type,
    required this.id,
    this.model,
    this.contextHash,
  });

  factory EnvelopeAuthor.fromJson(Object? json) {
    final map = _requireMap(json, 'author');
    _requireOnlyKeys(map, const {
      'type',
      'id',
      'model',
      'context_hash',
    }, 'author');
    for (final optional in const ['model', 'context_hash']) {
      if (map.containsKey(optional) && map[optional] == null) {
        throw EnvelopeFormatException('author.$optional is null, not omitted');
      }
    }
    return EnvelopeAuthor(
      type: AuthorType.fromWire(map['type']),
      id: _requireString(map['id'], 'author.id'),
      model: map['model'] == null
          ? null
          : _requireString(map['model'], 'author.model'),
      contextHash: map['context_hash'] == null
          ? null
          : _requireString(map['context_hash'], 'author.context_hash'),
    )..validate();
  }

  final AuthorType type;
  final String id;
  final String? model;

  /// Lower-case hex of a 32-byte hash.
  final String? contextHash;

  /// Optional members are omitted when absent, never written as `null`, so
  /// the author has one encoding.
  Map<String, Object?> toJson() => {
    'type': type.wireName,
    'id': id,
    'model': ?model,
    'context_hash': ?contextHash,
  };

  void validate() {
    if (id.isEmpty) {
      throw const EnvelopeFormatException('author.id is empty');
    }
    if (model case final model? when model.isEmpty) {
      throw const EnvelopeFormatException('author.model is empty');
    }
    if (contextHash case final hash?
        when !isHexOfLength(hash, envelopeHashLength)) {
      throw const EnvelopeFormatException(
        'author.context_hash is not a 32-byte lower-case hex hash',
      );
    }
  }

  @override
  bool operator ==(Object other) =>
      other is EnvelopeAuthor &&
      other.type == type &&
      other.id == id &&
      other.model == model &&
      other.contextHash == contextHash;

  @override
  int get hashCode => Object.hash(type, id, model, contextHash);
}

/// The signed metadata wrapper around every provenance entry (spec §6).
///
/// Structural rules checked by [validate], so a decoded envelope re-encodes
/// to the same bytes:
/// - hashes, the device id and the signature are lower-case hex;
/// - `seq` is non-negative, and `prev` is null exactly when `seq` is 0;
/// - `causal_refs` is sorted and has no duplicates;
/// - `claimed_time` is UTC at millisecond precision;
/// - `refs` holds only values [canonicalJson] accepts.
///
/// What the fields mean for the chain — that `prev` really is the previous
/// envelope's hash, that the device is certified — is for verification on
/// ingest, not for this class.
@immutable
class Envelope {
  Envelope({
    required this.kind,
    required this.deviceId,
    required this.seq,
    required this.prev,
    required this.causalRefs,
    required this.vectorClock,
    required this.author,
    required this.claimedTime,
    required this.contentCommitment,
    required this.refs,
    this.signature,
    this.version = envelopeVersion,
  }) {
    validate();
  }

  /// Decodes a signed envelope. Every member must be present, and nothing
  /// else may be.
  factory Envelope.fromJson(Object? json) {
    final map = _requireMap(json, 'envelope');
    _requireOnlyKeys(map, _keys, 'envelope');
    for (final key in _keys) {
      if (!map.containsKey(key)) {
        throw EnvelopeFormatException('envelope is missing $key');
      }
    }
    final clock = _requireMap(map['vector_clock'], 'vector_clock');
    return Envelope(
      version: _requireInt(map['version'], 'version'),
      kind: EnvelopeKind.fromWire(map['kind']),
      deviceId: _requireString(map['device_id'], 'device_id'),
      seq: _requireInt(map['seq'], 'seq'),
      prev: map['prev'] == null ? null : _requireString(map['prev'], 'prev'),
      causalRefs: _requireList(
        map['causal_refs'],
        'causal_refs',
      ).map((ref) => _requireString(ref, 'causal_refs')).toList(),
      vectorClock: {
        for (final entry in clock.entries)
          entry.key: _requireInt(entry.value, 'vector_clock.${entry.key}'),
      },
      author: EnvelopeAuthor.fromJson(map['author']),
      claimedTime: parseClaimedTime(
        _requireString(map['claimed_time'], 'claimed_time'),
      ),
      contentCommitment: map['content_commitment'] == null
          ? null
          : _requireString(map['content_commitment'], 'content_commitment'),
      refs: _requireMap(map['refs'], 'refs'),
      signature: _requireString(map['signature'], 'signature'),
    );
  }

  static const Set<String> _keys = {
    'version',
    'kind',
    'device_id',
    'seq',
    'prev',
    'causal_refs',
    'vector_clock',
    'author',
    'claimed_time',
    'content_commitment',
    'refs',
    'signature',
  };

  final int version;
  final EnvelopeKind kind;

  /// The fingerprint of the signing device's public key, lower-case hex.
  final String deviceId;

  /// This device's envelope counter, starting at 0 and gap-free.
  final int seq;

  /// Hash of this device's previous envelope; null for `seq` 0.
  final String? prev;

  /// Hashes of other devices' heads known when this was written.
  final List<String> causalRefs;

  /// The entry's vector clock, carried as data.
  final Map<String, int> vectorClock;

  final EnvelopeAuthor author;

  /// The device's wall-clock time. Informational: a signature proves who and
  /// in what order, not when.
  final DateTime claimedTime;

  /// Salted commitment to the plaintext content, or null.
  final String? contentCommitment;

  /// Kind-specific references (targets, sources, the proposal approved...).
  final Map<String, Object?> refs;

  /// Ed25519 signature over the signing bytes, lower-case hex; null until
  /// signed.
  final String? signature;

  bool get isSigned => signature != null;

  /// Every member except the signature: what the signature covers.
  Map<String, Object?> toSigningJson() => {
    'version': version,
    'kind': kind.wireName,
    'device_id': deviceId,
    'seq': seq,
    'prev': prev,
    'causal_refs': causalRefs,
    'vector_clock': vectorClock,
    'author': author.toJson(),
    'claimed_time': formatClaimedTime(claimedTime),
    'content_commitment': contentCommitment,
    'refs': refs,
  };

  /// The full envelope. Requires a signature: an unsigned envelope has no
  /// wire form.
  Map<String, Object?> toJson() {
    final signature = this.signature;
    if (signature == null) {
      throw const EnvelopeFormatException(
        'an unsigned envelope has no wire form',
      );
    }
    return {...toSigningJson(), 'signature': signature};
  }

  Envelope withSignature(String signature) => Envelope(
    version: version,
    kind: kind,
    deviceId: deviceId,
    seq: seq,
    prev: prev,
    causalRefs: causalRefs,
    vectorClock: vectorClock,
    author: author,
    claimedTime: claimedTime,
    contentCommitment: contentCommitment,
    refs: refs,
    signature: signature,
  );

  void validate() {
    if (version != envelopeVersion) {
      throw EnvelopeFormatException('unsupported version $version');
    }
    if (!isHexOfLength(deviceId, envelopeHashLength)) {
      throw const EnvelopeFormatException('device_id is not a 32-byte hex id');
    }
    if (seq < 0) {
      throw EnvelopeFormatException('seq $seq is negative');
    }
    final prev = this.prev;
    if (seq == 0 && prev != null) {
      throw const EnvelopeFormatException('seq 0 has a prev');
    }
    if (seq > 0 && prev == null) {
      throw EnvelopeFormatException('seq $seq has no prev');
    }
    if (prev != null && !isHexOfLength(prev, envelopeHashLength)) {
      throw const EnvelopeFormatException('prev is not a 32-byte hex hash');
    }
    for (var i = 0; i < causalRefs.length; i++) {
      if (!isHexOfLength(causalRefs[i], envelopeHashLength)) {
        throw const EnvelopeFormatException('causal_refs holds a non-hash');
      }
      if (i > 0 && causalRefs[i - 1].compareTo(causalRefs[i]) >= 0) {
        throw const EnvelopeFormatException(
          'causal_refs is not sorted and unique',
        );
      }
    }
    for (final entry in vectorClock.entries) {
      if (entry.key.isEmpty || entry.value < 0) {
        throw const EnvelopeFormatException(
          'vector_clock has an invalid entry',
        );
      }
    }
    author.validate();
    if (!claimedTime.isUtc || claimedTime.microsecond != 0) {
      throw const EnvelopeFormatException(
        'claimed_time must be UTC at millisecond precision',
      );
    }
    final commitment = contentCommitment;
    if (commitment != null && !isHexOfLength(commitment, envelopeHashLength)) {
      throw const EnvelopeFormatException(
        'content_commitment is not a 32-byte hex hash',
      );
    }
    try {
      canonicalJson(refs);
    } on CanonicalJsonException catch (e) {
      throw EnvelopeFormatException('refs: ${e.message}');
    }
    final signature = this.signature;
    if (signature != null &&
        !isHexOfLength(signature, ed25519SignatureLength)) {
      throw const EnvelopeFormatException(
        'signature is not a 64-byte hex signature',
      );
    }
  }

  static const _deepEquality = DeepCollectionEquality();

  @override
  bool operator ==(Object other) =>
      other is Envelope &&
      other.version == version &&
      other.kind == kind &&
      other.deviceId == deviceId &&
      other.seq == seq &&
      other.prev == prev &&
      _deepEquality.equals(other.causalRefs, causalRefs) &&
      _deepEquality.equals(other.vectorClock, vectorClock) &&
      other.author == author &&
      other.claimedTime == claimedTime &&
      other.contentCommitment == contentCommitment &&
      _deepEquality.equals(other.refs, refs) &&
      other.signature == signature;

  @override
  int get hashCode => Object.hash(
    version,
    kind,
    deviceId,
    seq,
    prev,
    _deepEquality.hash(causalRefs),
    _deepEquality.hash(vectorClock),
    author,
    claimedTime,
    contentCommitment,
    _deepEquality.hash(refs),
    signature,
  );
}

final RegExp _claimedTimePattern = RegExp(
  r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$',
);

/// `YYYY-MM-DDTHH:MM:SS.mmmZ`, the only accepted spelling of a claimed time.
String formatClaimedTime(DateTime time) {
  final utc = time.toUtc();
  String two(int v) => v.toString().padLeft(2, '0');
  return '${utc.year.toString().padLeft(4, '0')}-${two(utc.month)}-'
      '${two(utc.day)}T${two(utc.hour)}:${two(utc.minute)}:'
      '${two(utc.second)}.${utc.millisecond.toString().padLeft(3, '0')}Z';
}

/// Parses [formatClaimedTime]'s output, and nothing else.
DateTime parseClaimedTime(String value) {
  if (!_claimedTimePattern.hasMatch(value)) {
    throw EnvelopeFormatException('claimed_time $value is not canonical');
  }
  final parsed = DateTime.parse(value);
  if (formatClaimedTime(parsed) != value) {
    throw EnvelopeFormatException('claimed_time $value is not a real time');
  }
  return parsed;
}

Map<String, Object?> _requireMap(Object? value, String field) {
  if (value is! Map) {
    throw EnvelopeFormatException('$field is not an object');
  }
  return value.map((key, v) {
    if (key is! String) {
      throw EnvelopeFormatException('$field has a non-string key');
    }
    return MapEntry(key, v);
  });
}

List<Object?> _requireList(Object? value, String field) {
  if (value is! List) {
    throw EnvelopeFormatException('$field is not a list');
  }
  return value;
}

String _requireString(Object? value, String field) {
  if (value is! String) {
    throw EnvelopeFormatException('$field is not a string');
  }
  return value;
}

int _requireInt(Object? value, String field) {
  if (value is! int) {
    throw EnvelopeFormatException('$field is not an integer');
  }
  return value;
}

void _requireOnlyKeys(
  Map<String, Object?> map,
  Set<String> allowed,
  String field,
) {
  for (final key in map.keys) {
    if (!allowed.contains(key)) {
      throw EnvelopeFormatException('$field has unknown member $key');
    }
  }
}
