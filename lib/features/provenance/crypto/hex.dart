import 'dart:typed_data';

/// Lower-case hex, the one spelling provenance structures accept for bytes.
String toHex(List<int> bytes) {
  final buffer = StringBuffer();
  for (final byte in bytes) {
    buffer.write(byte.toRadixString(16).padLeft(2, '0'));
  }
  return buffer.toString();
}

final RegExp _lowerHex = RegExp(r'^(?:[0-9a-f]{2})*$');

/// Decodes lower-case hex. Upper case, odd length or any other character is
/// a [FormatException]: a second spelling of the same bytes would give one
/// envelope two canonical encodings.
Uint8List fromHex(String hex) {
  if (!_lowerHex.hasMatch(hex)) {
    throw FormatException('not lower-case hex', hex);
  }
  final bytes = Uint8List(hex.length ~/ 2);
  for (var i = 0; i < bytes.length; i++) {
    bytes[i] = int.parse(hex.substring(2 * i, 2 * i + 2), radix: 16);
  }
  return bytes;
}

/// Whether [value] is lower-case hex encoding exactly [byteLength] bytes.
bool isHexOfLength(String value, int byteLength) =>
    value.length == 2 * byteLength && _lowerHex.hasMatch(value);
