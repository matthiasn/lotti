import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// The purposes provenance bytes are hashed or signed for. Each has its own
/// tag, so a hash or signature made for one can never be passed off as
/// another (a signed envelope as a device id, say).
enum ProvenanceDomain {
  /// The bytes an envelope's signature covers.
  envelopeSignature('lotti/envelope-signature/v1'),

  /// An envelope's identity: its hash, signature included.
  envelopeHash('lotti/envelope/v1'),

  /// A salted commitment to an entry's plaintext.
  content('lotti/content/v1'),

  /// A device's id: the fingerprint of its public signing key.
  deviceId('lotti/device-id/v1');

  const ProvenanceDomain(this.tag);

  /// ASCII, and never contains a NUL, so the framing below is unambiguous.
  final String tag;
}

/// `tag ‖ 0x00 ‖ payload`: the framing every provenance hash and signature is
/// computed over.
Uint8List domainFrame(ProvenanceDomain domain, List<int> payload) {
  final tag = ascii.encode(domain.tag);
  return Uint8List(tag.length + 1 + payload.length)
    ..setRange(0, tag.length, tag)
    ..[tag.length] = 0
    ..setRange(tag.length + 1, tag.length + 1 + payload.length, payload);
}

/// SHA-256 over [domainFrame]. Always 32 bytes.
Uint8List domainHash(ProvenanceDomain domain, List<int> payload) =>
    Uint8List.fromList(sha256.convert(domainFrame(domain, payload)).bytes);
