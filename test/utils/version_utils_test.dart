import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/utils/version_utils.dart';

void main() {
  group('isNewerVersion', () {
    test('compares patch versions', () {
      expect(isNewerVersion('0.9.804', '0.9.802'), isTrue);
      expect(isNewerVersion('0.9.802', '0.9.804'), isFalse);
    });

    test('equal versions are not newer', () {
      expect(isNewerVersion('0.9.802', '0.9.802'), isFalse);
      expect(isNewerVersion('1.0.0', '1.0.0'), isFalse);
    });

    test('compares minor versions', () {
      expect(isNewerVersion('0.10.0', '0.9.999'), isTrue);
      expect(isNewerVersion('0.9.999', '0.10.0'), isFalse);
    });

    test('compares major versions', () {
      expect(isNewerVersion('1.0.0', '0.9.999'), isTrue);
      expect(isNewerVersion('0.9.999', '1.0.0'), isFalse);
      expect(isNewerVersion('100.0.0', '0.9.980'), isTrue);
    });

    test('more parts on an equal prefix counts as newer', () {
      expect(isNewerVersion('1.0.0.1', '1.0.0'), isTrue);
      expect(isNewerVersion('1.0.0', '1.0.0.1'), isFalse);
    });

    test('unparseable parts are treated as zero', () {
      expect(isNewerVersion('1.x.0', '1.0.0'), isFalse);
      expect(isNewerVersion('1.1.0', '1.x.0'), isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // Property: irreflexive (no version is newer than itself), asymmetric, and
  // sensitive to bumping any single major/minor/patch component.
  // ---------------------------------------------------------------------------
  group('isNewerVersion — properties', () {
    glados.Glados3<int, int, int>(
      glados.IntAnys(glados.any).intInRange(0, 100),
      glados.IntAnys(glados.any).intInRange(0, 100),
      glados.IntAnys(glados.any).intInRange(0, 100),
      glados.ExploreConfig(numRuns: 160),
    ).test('irreflexive, asymmetric, and bump-sensitive', (
      major,
      minor,
      patch,
    ) {
      final version = '$major.$minor.$patch';

      // A version is never newer than itself.
      expect(isNewerVersion(version, version), isFalse);

      // Bumping any single part makes it newer — and the comparison is
      // asymmetric.
      final bumps = [
        '${major + 1}.$minor.$patch',
        '$major.${minor + 1}.$patch',
        '$major.$minor.${patch + 1}',
      ];
      for (final bumped in bumps) {
        expect(
          isNewerVersion(bumped, version),
          isTrue,
          reason: '$bumped vs $version',
        );
        expect(
          isNewerVersion(version, bumped),
          isFalse,
          reason: '$version vs $bumped',
        );
      }
    }, tags: 'glados');
  });
}
