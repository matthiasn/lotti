import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/utils/confined_path.dart';
import 'package:path/path.dart' as p;

const _root = '/docs';

void main() {
  group('confinedDocumentPath', () {
    test('a well-formed entry resolves exactly as a plain join would', () {
      expect(
        confinedDocumentPath(_root, '/images/2024-03-15/', 'photo.jpg'),
        p.join(_root, 'images', '2024-03-15', 'photo.jpg'),
      );
      expect(
        confinedDocumentPath(_root, '/audio/2024-03-15/', 'note.aac'),
        '/docs/audio/2024-03-15/note.aac',
      );
    });

    test('accepts Windows separators from another device', () {
      expect(
        confinedDocumentPath(_root, r'\images\2024-03-15\', 'photo.jpg'),
        '/docs/images/2024-03-15/photo.jpg',
      );
    });

    for (final (label, directory, file) in <(String, String, String)>[
      ('in the directory', '/../../etc/', 'passwd'),
      ('in the file name', '/images/', '../../../etc/passwd'),
      ('with Windows separators', r'\..\..\', r'..\secrets.txt'),
      ('behind a dot segment', '/./../', 'x'),
    ]) {
      test('a parent segment $label stays under the root', () {
        final path = confinedDocumentPath(_root, directory, file);
        expect(p.isWithin(_root, path), isTrue, reason: path);
      });
    }

    glados.Glados2(
      glados.any.choose(const ['..', '.', '', 'images', 'a', r'..\..', '/']),
      glados.any.choose(const ['..', 'x.jpg', '../../x', r'..\y', '.', 'z']),
      glados.ExploreConfig(numRuns: 200),
    ).test(
      'never resolves outside the root, whatever the segments',
      (directory, file) {
        final path = confinedDocumentPath(_root, '/$directory/', file);
        expect(path == _root || p.isWithin(_root, path), isTrue, reason: path);
      },
      tags: 'glados',
    );
  });
}
