import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/provenance/crypto/hex.dart';

void main() {
  test('encodes lower case, two digits per byte', () {
    expect(toHex([0, 1, 15, 16, 171, 255]), '00010f10abff');
  });

  for (final (label, input) in <(String, String)>[
    ('upper case', 'AB'),
    ('odd length', 'abc'),
    ('a non-hex character', 'zz'),
    ('a prefix', '0x00'),
  ]) {
    test('rejects $label', () {
      expect(() => fromHex(input), throwsFormatException);
    });
  }

  test('isHexOfLength checks both spelling and length', () {
    expect(isHexOfLength('00' * 32, 32), isTrue);
    expect(isHexOfLength('00' * 31, 32), isFalse);
    expect(isHexOfLength('AA' * 32, 32), isFalse);
  });

  glados.Glados<List<int>>(
    glados.any.list(glados.any.intInRange(0, 256)),
    glados.ExploreConfig(numRuns: 200),
  ).test(
    'fromHex inverts toHex',
    (bytes) => expect(fromHex(toHex(bytes)), bytes),
    tags: 'glados',
  );
}
