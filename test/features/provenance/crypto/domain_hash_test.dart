import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/provenance/crypto/domain_hash.dart';
import 'package:lotti/features/provenance/crypto/hex.dart';

void main() {
  // SHA-256(tag || 0x00 || "abc"), computed independently with Python's
  // hashlib, so these pin the framing as well as the tags.
  const expected = {
    ProvenanceDomain.envelopeSignature:
        'ffc47e33063637647be073fc4e709ed497ac6c1ba90a30ef24797cdc1f2cd350',
    ProvenanceDomain.envelopeHash:
        'b3d69804c1442313695aa80ef68676b10005cde5ba59740479ef761b6c74eff2',
    ProvenanceDomain.content:
        '233137cb4f6249c94fa9ab34ac5a33d421d65755f887c99aac518d9b6e01e6ac',
    ProvenanceDomain.deviceId:
        'e9ed4bf32f3891892a02975ce48d4a586bd8c8974402b77febf57c7aa63b31aa',
  };

  for (final MapEntry(key: domain, value: hash) in expected.entries) {
    test('${domain.tag} hashes match the independent reference', () {
      expect(toHex(domainHash(domain, utf8.encode('abc'))), hash);
    });
  }

  test('every domain has its own tag', () {
    final tags = ProvenanceDomain.values.map((d) => d.tag).toSet();
    expect(tags, hasLength(ProvenanceDomain.values.length));
  });

  test('the frame is the tag, one NUL, then the payload', () {
    expect(
      domainFrame(ProvenanceDomain.content, [1, 2]),
      [...ascii.encode('lotti/content/v1'), 0, 1, 2],
    );
  });

  test('the same payload hashes differently under different domains', () {
    final payload = utf8.encode('same bytes');
    expect(
      toHex(domainHash(ProvenanceDomain.envelopeHash, payload)),
      isNot(toHex(domainHash(ProvenanceDomain.deviceId, payload))),
    );
  });
}
