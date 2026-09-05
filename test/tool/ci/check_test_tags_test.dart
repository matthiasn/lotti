import 'package:flutter_test/flutter_test.dart';

import '../../../tool/ci/check_test_tags.dart';

void main() {
  test('detects generic, prefixed and seeded property tests', () {
    expect(
      untaggedPropertyTests('''
void main() {
  Glados<int>(any.int).test('missing', (value) {});
  glados.Glados2(any.int, any.int).test('missing', (a, b) {});
  Glados(any.int).testWithRandom('seeded', (random, value) {});
}
'''),
      [2, 3, 4],
    );
  });

  test(
    'accepts literal tags and ignores comments, strings and other tests',
    () {
      expect(
        untaggedPropertyTests('''
void main() {
  Glados(any.int).test('ok', (value) {}, tags: 'glados');
  Glados2(any.int, any.int).test('ok', (a, b) {}, tags: ['slow', 'glados']);
  // Glados(any.int).test('comment', (value) {});
  const fixture = "Glados(any.int).test('string', (value) {})";
  ordinary.test('unit', () {});
}
'''),
        isEmpty,
      );
    },
  );

  test('a glados string in the body does not satisfy the tag contract', () {
    expect(
      untaggedPropertyTests('''
void main() {
  Glados(any.int).test('glados', (value) { print('glados'); }, tags: 'slow');
}
'''),
      [2],
    );
  });
}
