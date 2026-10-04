import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/utils/document_path_guard.dart';
import 'package:path/path.dart' as p;

const _root = '/docs';

void main() {
  group('isInsideDocuments', () {
    for (final path in [
      '/docs',
      '/docs/images/2024-03-15/photo.jpg',
      '/docs/audio/2024-03-15/../2024-03-16/note.aac',
      // Dots inside a real name are not a parent reference.
      '/docs/images/a../..x/file...jpg',
    ]) {
      test('accepts $path', () {
        expect(isInsideDocuments(_root, path), isTrue);
      });
    }

    for (final (label, path) in <(String, String)>[
      ('a parent escape', '/docs/images/../../etc/passwd'),
      ('a sibling that shares the prefix', '/docs-other/x'),
      ('an unrelated absolute path', '/etc/passwd'),
      // Win32 trims trailing dots and spaces, so these act as `..` there.
      ('a trailing-space parent', '/docs/images/.. /.. /x'),
      ('an extra-dots parent', '/docs/.../x'),
      ('a dots-only file name', '/docs/images/...'),
    ]) {
      test('refuses $label', () {
        expect(isInsideDocuments(_root, path), isFalse, reason: path);
      });
    }

    glados.Glados2(
      glados.any.choose(
        const ['..', '.', 'images', 'a', '.. ', '...', 'x.jpg', '. .'],
      ),
      glados.any.choose(const ['..', 'x.jpg', '.. ', '...', 'z', 'a.b']),
      glados.ExploreConfig(numRuns: 200),
    ).test(
      'whatever it accepts, no segment escapes or reads as a parent on Windows',
      (first, second) {
        final path = '/docs/$first/$second';
        if (!isInsideDocuments(_root, path)) return;
        final normalized = p.normalize(path);
        if (normalized == _root) return;
        expect(p.isWithin(_root, normalized), isTrue, reason: path);
        expect(
          p.split(p.relative(normalized, from: _root)),
          everyElement(isNot(matches(r'^[. ]+$'))),
          reason: path,
        );
      },
      tags: 'glados',
    );
  });
}
