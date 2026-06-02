import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Versioned, content-addressed digest over a **canonical** serialization of
/// JSON-able content (ADR 0017 §6 / ADR 0020 rule 2).
///
/// The digest is what makes a captured input or a compaction artifact
/// content-addressed: logically-equal content always yields the same digest,
/// regardless of how the value was constructed, so identical content dedupes to
/// a single row across wakes *and* agents, and two devices computing a digest
/// over the same content agree without coordination.
///
/// Canonicalization rules:
/// - map keys are sorted (by their string form), recursively — insertion order
///   never affects the digest;
/// - `DateTime`s are normalized to RFC 3339 in UTC;
/// - integral doubles (`1.0`) collapse to their integer form (`1`), so a JSON
///   round-trip (which may turn `1` into `1.0` or back) does not change the
///   digest;
/// - strings are JSON-escaped; lists preserve order (list order is significant).
///
/// The result is `'<version>:<base64url>'` with `=` padding stripped, e.g.
/// `sha256-v1:Ut0c...`. The [version] tag lets a future algorithm change
/// coexist with already-stored digests instead of silently colliding.
class ContentDigest {
  const ContentDigest._(); // coverage:ignore-line — static-only utility

  /// Algorithm/version tag prefixing every digest.
  static const String version = 'sha256-v1';

  /// The content-addressed digest of [content].
  ///
  /// Throws [ArgumentError] if [content] holds a value that is not JSON-able
  /// (the agent log only ever stores JSON content, so a non-JSON value signals
  /// an upstream bug rather than something to silently hash).
  static String of(Object? content) {
    final canonical = _canonical(content);
    final hash = sha256.convert(utf8.encode(canonical));
    final encoded = base64Url.encode(hash.bytes).replaceAll('=', '');
    return '$version:$encoded';
  }

  static String _canonical(Object? value) {
    final buffer = StringBuffer();
    _write(buffer, value);
    return buffer.toString();
  }

  static void _write(StringBuffer out, Object? value) {
    switch (value) {
      case null:
        out.write('null');
      case final String s:
        out.write(jsonEncode(s));
      case final bool b:
        out.write(b ? 'true' : 'false');
      case final int i:
        out.write(i.toString());
      case final double d:
        _writeDouble(out, d);
      case final DateTime t:
        out.write(jsonEncode(t.toUtc().toIso8601String()));
      case final List<Object?> list:
        out.write('[');
        for (var i = 0; i < list.length; i++) {
          if (i > 0) out.write(',');
          _write(out, list[i]);
        }
        out.write(']');
      case final Map<Object?, Object?> map:
        // JSON objects have string keys only — reject non-string keys rather
        // than coercing them (which would let `{1: 'x'}` collide with
        // `{'1': 'x'}`). Sort by key so insertion order is irrelevant.
        final entries = <MapEntry<String, Object?>>[];
        for (final entry in map.entries) {
          final key = entry.key;
          if (key is! String) {
            throw ArgumentError(
              'ContentDigest only supports maps with String keys, got '
              '${key.runtimeType}',
            );
          }
          // `key` is promoted to String here, so no cast/`!` is needed.
          entries.add(MapEntry(key, entry.value));
        }
        entries.sort((a, b) => a.key.compareTo(b.key));
        out.write('{');
        for (var i = 0; i < entries.length; i++) {
          if (i > 0) out.write(',');
          out
            ..write(jsonEncode(entries[i].key))
            ..write(':');
          _write(out, entries[i].value);
        }
        out.write('}');
      default:
        throw ArgumentError(
          'ContentDigest cannot canonicalize a ${value.runtimeType}',
        );
    }
  }

  static void _writeDouble(StringBuffer out, double d) {
    // NaN/Infinity are not JSON numbers — fail fast rather than hash them.
    if (!d.isFinite) {
      throw ArgumentError('ContentDigest cannot canonicalize $d');
    }
    // Collapse integral doubles to their integer form across the whole IEEE-754
    // safe-integer range (2^53), so `1.0`/`1` and `1e16`/`10000000000000000`
    // agree as the "integral doubles collapse to integers" contract promises.
    if (d == d.roundToDouble() && d.abs() <= 9007199254740992.0) {
      out.write(d.toInt().toString());
    } else {
      out.write(d.toString());
    }
  }
}
