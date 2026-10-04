import 'dart:convert';
import 'dart:typed_data';

/// Thrown when a value cannot be canonicalized, or when bytes are not the
/// canonical encoding of what they decode to.
class CanonicalJsonException implements Exception {
  const CanonicalJsonException(this.message);

  final String message;

  @override
  String toString() => 'CanonicalJsonException: $message';
}

/// The largest integer JCS serializes exactly (2^53 - 1).
const int maxCanonicalInt = 9007199254740991;

/// RFC 8785 (JCS) canonical JSON for the values provenance structures use.
///
/// Accepts `null`, `bool`, `int`, `String`, `List` and `Map` with `String`
/// keys, nested freely. Floating-point numbers are rejected rather than
/// formatted: provenance structures carry none, and leaving them out is what
/// makes this subset byte-identical to a full JCS implementation without
/// reproducing ECMAScript number formatting. Integers must lie within
/// ±[maxCanonicalInt], and strings must be well-formed UTF-16 (no lone
/// surrogates).
///
/// Object members are sorted by the UTF-16 code units of their names, which is
/// what [String.compareTo] compares.
Uint8List canonicalJsonBytes(Object? value) =>
    Uint8List.fromList(utf8.encode(canonicalJson(value)));

/// The canonical encoding of [value] as a string. See [canonicalJsonBytes].
String canonicalJson(Object? value) {
  final buffer = StringBuffer();
  _write(value, buffer);
  return buffer.toString();
}

/// Decodes [bytes], accepting them only if they are exactly the canonical
/// encoding of the decoded value.
///
/// Anything that decodes to the same value but is spelled differently — other
/// member order, whitespace, escapes, a float such as `1.0` — is rejected, so
/// one value has exactly one accepted byte form.
Object? parseCanonicalJson(List<int> bytes) {
  final Object? decoded;
  try {
    decoded = jsonDecode(utf8.decode(bytes));
  } on FormatException catch (e) {
    throw CanonicalJsonException('not JSON: ${e.message}');
  }
  final canonical = canonicalJsonBytes(decoded);
  if (!_sameBytes(canonical, bytes)) {
    throw const CanonicalJsonException('not in canonical form');
  }
  return decoded;
}

void _write(Object? value, StringBuffer out) {
  switch (value) {
    case null:
      out.write('null');
    case final bool b:
      out.write(b ? 'true' : 'false');
    case final int i:
      if (i > maxCanonicalInt || i < -maxCanonicalInt) {
        throw CanonicalJsonException('integer $i is outside ±2^53-1');
      }
      out.write(i);
    case final String s:
      _writeString(s, out);
    case final List<Object?> list:
      out.write('[');
      for (var i = 0; i < list.length; i++) {
        if (i > 0) out.write(',');
        _write(list[i], out);
      }
      out.write(']');
    case final Map<Object?, Object?> map:
      final keys = <String>[];
      for (final key in map.keys) {
        if (key is! String) {
          throw CanonicalJsonException('object key $key is not a string');
        }
        keys.add(key);
      }
      keys.sort();
      out.write('{');
      for (var i = 0; i < keys.length; i++) {
        if (i > 0) out.write(',');
        _writeString(keys[i], out);
        out.write(':');
        _write(map[keys[i]], out);
      }
      out.write('}');
    default:
      throw CanonicalJsonException(
        'unsupported value of type ${value.runtimeType}',
      );
  }
}

/// JSON string escaping as RFC 8785 prescribes: the two mandatory escapes,
/// the five short control escapes, `\u00xx` in lower case for the remaining
/// control characters, and every other code point written as itself.
void _writeString(String s, StringBuffer out) {
  out.write('"');
  for (var i = 0; i < s.length; i++) {
    final unit = s.codeUnitAt(i);
    if (unit >= 0xD800 && unit <= 0xDBFF) {
      final hasLow =
          i + 1 < s.length &&
          s.codeUnitAt(i + 1) >= 0xDC00 &&
          s.codeUnitAt(i + 1) <= 0xDFFF;
      if (!hasLow) {
        throw const CanonicalJsonException('lone high surrogate');
      }
      out
        ..writeCharCode(unit)
        ..writeCharCode(s.codeUnitAt(i + 1));
      i++;
      continue;
    }
    if (unit >= 0xDC00 && unit <= 0xDFFF) {
      throw const CanonicalJsonException('lone low surrogate');
    }
    switch (unit) {
      case 0x22:
        out.write(r'\"');
      case 0x5C:
        out.write(r'\\');
      case 0x08:
        out.write(r'\b');
      case 0x09:
        out.write(r'\t');
      case 0x0A:
        out.write(r'\n');
      case 0x0C:
        out.write(r'\f');
      case 0x0D:
        out.write(r'\r');
      default:
        if (unit < 0x20) {
          out
            ..write(r'\u00')
            ..write(unit.toRadixString(16).padLeft(2, '0'));
        } else {
          out.writeCharCode(unit);
        }
    }
  }
  out.write('"');
}

bool _sameBytes(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
