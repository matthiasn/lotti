import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/profiles/profile_paths.dart';
import 'package:path/path.dart' as p;

void main() {
  group('guestProfileRoot', () {
    test('nests the guest world under guest_profiles/<id>', () {
      final root = guestProfileRoot(Directory('/data/lotti'), 'abc');

      expect(
        p.split(root.path).sublist(p.split(root.path).length - 3),
        ['lotti', guestProfilesDirName, 'abc'],
      );
    });
  });

  group('assertIsGuestRoot', () {
    test('accepts a child of guest_profiles', () {
      expect(
        () => assertIsGuestRoot(
          guestProfileRoot(Directory('/data/lotti'), 'abc'),
        ),
        returnsNormally,
      );
    });

    test('rejects the real root — the delete guard must hold', () {
      expect(
        () => assertIsGuestRoot(Directory('/data/lotti')),
        throwsArgumentError,
      );
    });

    test('rejects the guest_profiles container itself', () {
      expect(
        () => assertIsGuestRoot(
          Directory(p.join('/data/lotti', guestProfilesDirName)),
        ),
        throwsArgumentError,
      );
    });

    test('rejects traversal that escapes guest_profiles', () {
      expect(
        () => assertIsGuestRoot(
          Directory('/data/lotti/guest_profiles/abc/../..'),
        ),
        throwsArgumentError,
      );
    });
  });
}
