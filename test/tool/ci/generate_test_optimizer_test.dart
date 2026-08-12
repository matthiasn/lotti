import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;

import '../../../tool/ci/generate_test_optimizer.dart';

void main() {
  test(
    'generates a stable sorted bundle and excludes opted-out tests',
    () async {
      final root = Directory.systemTemp.createTempSync('test_optimizer_');
      addTearDown(() => root.deleteSync(recursive: true));
      final testDirectory = Directory(path.join(root.path, 'test'))
        ..createSync();
      final nestedDirectory = Directory(path.join(testDirectory.path, 'nested'))
        ..createSync();

      File(path.join(testDirectory.path, 'zeta_test.dart')).writeAsStringSync(
        'void main() {}',
      );
      File(
        path.join(nestedDirectory.path, 'alpha_test.dart'),
      ).writeAsStringSync(
        'void main() {}',
      );
      File(
        path.join(testDirectory.path, 'skipped_test.dart'),
      ).writeAsStringSync(
        "@Tags(['skip_very_good_optimization'])\nvoid main() {}",
      );
      File(
        path.join(testDirectory.path, 'tag_fixture_test.dart'),
      ).writeAsStringSync(
        'void main() {\n'
        '  const fixture = "@Tags([\'skip_very_good_optimization\'])";\n'
        '}',
      );
      File(path.join(testDirectory.path, 'helper.dart')).writeAsStringSync(
        'void helper() {}',
      );

      final output = await generateTestOptimizer(packageRoot: root.path);
      final firstContents = await output.readAsString();
      await generateTestOptimizer(packageRoot: root.path);
      final secondContents = await output.readAsString();

      expect(secondContents, firstContents);
      expect(firstContents, isNot(contains('skipped_test.dart')));
      expect(firstContents, contains('tag_fixture_test.dart'));
      expect(firstContents, isNot(contains('helper.dart')));
      expect(
        firstContents.indexOf("import 'nested/alpha_test.dart'"),
        lessThan(firstContents.indexOf("import 'tag_fixture_test.dart'")),
      );
      expect(
        firstContents.indexOf("import 'tag_fixture_test.dart'"),
        lessThan(firstContents.indexOf("import 'zeta_test.dart'")),
      );
      expect(
        firstContents,
        contains(
          "group('nested/alpha_test.dart', () { _test0.main(); });",
        ),
      );
      expect(
        firstContents,
        contains('class _TestOptimizationAwareGoldenFileComparator'),
      );
    },
  );

  test('fails clearly when the package has no test directory', () async {
    final root = Directory.systemTemp.createTempSync('test_optimizer_');
    addTearDown(() => root.deleteSync(recursive: true));

    await expectLater(
      generateTestOptimizer(packageRoot: root.path),
      throwsA(
        isA<FileSystemException>().having(
          (error) => error.message,
          'message',
          'Test directory does not exist',
        ),
      ),
    );
  });
}
