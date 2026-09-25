import 'dart:typed_data';

import 'package:lotti/features/provenance/crypto/canonical_json.dart';
import 'package:lotti/features/provenance/crypto/domain_hash.dart';
import 'package:lotti/features/provenance/crypto/ed25519.dart';
import 'package:lotti/features/provenance/crypto/hex.dart';
import 'package:lotti/features/provenance/model/envelope.dart';

/// A device's id: the fingerprint of its Ed25519 public key.
String deviceIdFor(List<int> publicKey) {
  if (publicKey.length != ed25519PublicKeyLength) {
    throw ArgumentError.value(
      publicKey.length,
      'publicKey',
      'must be $ed25519PublicKeyLength bytes',
    );
  }
  return toHex(domainHash(ProvenanceDomain.deviceId, publicKey));
}

/// The bytes an envelope's signature covers: the signing domain tag framing
/// the canonical encoding of every member but the signature.
Uint8List envelopeSigningBytes(Envelope envelope) => domainFrame(
  ProvenanceDomain.envelopeSignature,
  canonicalJsonBytes(envelope.toSigningJson()),
);

/// Signs [envelope] with [signer]. The envelope's device id must be the
/// signer's, so an envelope can never claim a device that did not sign it.
Envelope signEnvelope(Envelope envelope, Ed25519Signer signer) {
  if (envelope.isSigned) {
    throw ArgumentError.value(envelope, 'envelope', 'is already signed');
  }
  if (envelope.deviceId != deviceIdFor(signer.publicKey)) {
    throw ArgumentError.value(
      envelope.deviceId,
      'envelope.deviceId',
      "is not the signer's device id",
    );
  }
  return envelope.withSignature(
    toHex(signer.sign(envelopeSigningBytes(envelope))),
  );
}

/// Whether [envelope] is signed by the key [publicKey], and [publicKey] is
/// the key its device id names (spec invariant I1).
bool verifyEnvelopeSignature(
  Envelope envelope,
  List<int> publicKey,
  Ed25519 ed25519,
) {
  final signature = envelope.signature;
  if (signature == null ||
      publicKey.length != ed25519PublicKeyLength ||
      envelope.deviceId != deviceIdFor(publicKey)) {
    return false;
  }
  return ed25519.verify(
    message: envelopeSigningBytes(envelope),
    signature: fromHex(signature),
    publicKey: publicKey,
  );
}

/// The wire bytes of a signed envelope: its canonical JSON.
Uint8List encodeEnvelope(Envelope envelope) =>
    canonicalJsonBytes(envelope.toJson());

/// Decodes wire bytes into a signed envelope, accepting only the canonical
/// encoding. Throws [CanonicalJsonException] or [EnvelopeFormatException].
Envelope decodeEnvelope(List<int> bytes) =>
    Envelope.fromJson(parseCanonicalJson(bytes));

/// An envelope's identity: the hash of its wire bytes, signature included.
/// This is what `prev`, `causal_refs` and other envelopes' refs point at.
String envelopeHash(Envelope envelope) =>
    toHex(domainHash(ProvenanceDomain.envelopeHash, encodeEnvelope(envelope)));
