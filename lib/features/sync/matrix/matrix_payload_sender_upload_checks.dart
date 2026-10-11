part of 'matrix_payload_sender.dart';

// The checks [MatrixPayloadSender] runs on an upload's response before it
// acknowledges the upload.

/// Requires a server name and one media ID, without URI normalization hiding
/// malformed paths. Uri parsing also rejects invalid bracketed IPv6 hosts.
bool _hasValidMxcUri(String value) =>
    RegExp(
      r'^mxc://(?:[A-Za-z0-9.-]+|\[[0-9A-Fa-f:.]+\])'
      r'(?::[0-9]+)?/[A-Za-z0-9_-]+$',
    ).hasMatch(value) &&
    Uri.tryParse(value) != null;

/// Checks the v2 encryption metadata emitted by our SDK before acknowledging
/// its upload. The ciphertext bytes and their hash are not downloaded here.
bool _hasValidEncryptedFileMetadata(Object? value) {
  if (value is! Map || value['v'] != 'v2') return false;
  final key = value['key'];
  final hashes = value['hashes'];
  if (key is! Map || hashes is! Map) return false;
  final operations = key['key_ops'];
  return key['alg'] == 'A256CTR' &&
      key['kty'] == 'oct' &&
      key['ext'] == true &&
      operations is List &&
      operations.every((operation) => operation is String) &&
      operations.contains('encrypt') &&
      operations.contains('decrypt') &&
      _hasBase64ByteLength(key['k'], 32) &&
      _hasBase64ByteLength(value['iv'], 16) &&
      _hasBase64ByteLength(hashes['sha256'], 32);
}

bool _hasBase64ByteLength(Object? value, int expectedLength) {
  if (value is! String) return false;
  try {
    // normalize accepts the SDK's unpadded base64 and base64url forms.
    return base64.decode(base64.normalize(value)).length == expectedLength;
  } on FormatException {
    // Do not propagate a decoding error containing key/IV material to logs.
    return false;
  }
}
