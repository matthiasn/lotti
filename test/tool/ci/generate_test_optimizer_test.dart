import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;

import '../../../tool/ci/generate_test_optimizer.dart';

void main() {
  test(
    'routes annotated suites intact and bundles other tests in stable order',
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
        "@Tags(['skip_very_good_optimization'])\nlibrary;\nvoid main() {}",
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

      for (final annotation in [
        'Timeout(Duration(seconds: 7))',
        "Tags(['performance'])",
        "TestOn('linux')",
        "Skip('manual')",
        'Retry(2)',
        "OnPlatform({'windows': Skip('unsupported')})",
      ]) {
        final name = annotation.split('(').first.toLowerCase();
        File(
          path.join(testDirectory.path, '${name}_test.dart'),
        ).writeAsStringSync(
          '@$annotation\nlibrary;\nvoid main() {}',
        );
      }

      final output = await generateTestOptimizer(packageRoot: root.path);
      final firstContents = await output.readAsString();
      await generateTestOptimizer(packageRoot: root.path);
      final secondContents = await output.readAsString();

      expect(secondContents, firstContents);
      final targets =
          jsonDecode(
                await File(
                  path.join(root.path, testTargetsRelativePath),
                ).readAsString(),
              )
              as List<dynamic>;
      expect(targets, [
        'test/.test_optimizer.dart',
        'test/onplatform_test.dart',
        'test/retry_test.dart',
        'test/skip_test.dart',
        'test/skipped_test.dart',
        'test/tags_test.dart',
        'test/teston_test.dart',
        'test/timeout_test.dart',
      ]);
      for (final target in targets.skip(1)) {
        expect(firstContents, isNot(contains(path.basename(target as String))));
      }
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

  test('excludes only suites with inherited matching literal tags', () async {
    final root = Directory.systemTemp.createTempSync('test_optimizer_');
    addTearDown(() => root.deleteSync(recursive: true));
    final directory = Directory(path.join(root.path, 'test'))..createSync();
    final fixtures = {
      'excluded': "@test.Tags(['eval-live'])\nlibrary;",
      'unknown': '@Tags(suiteTags)\nlibrary;',
      'conditional': "@Tags([if (enabled) 'eval-live'])\nlibrary;",
      'other': "@Tags(['other'])\nlibrary;",
      'mixed': '@Timeout(Duration(minutes: 2))\nlibrary;',
      'bare': 'library;',
      'fixture': "const fixture = \"@Tags(['eval-live']) library;\";",
      'plain': '',
    };
    for (final entry in fixtures.entries) {
      File(
        path.join(directory.path, '${entry.key}_test.dart'),
      ).writeAsStringSync('${entry.value}\nvoid main() {}');
    }
    final output = await generateTestOptimizer(
      packageRoot: root.path,
      excludedSuiteTags: {'eval-live'},
    );
    final contents = await output.readAsString();
    expect(contents, isNot(contains('excluded_test.dart')));
    for (final name in ['bare', 'fixture', 'plain']) {
      expect(contents, contains("import '${name}_test.dart'"));
    }
    expect(
      jsonDecode(
        File(path.join(root.path, testTargetsRelativePath)).readAsStringSync(),
      ),
      [
        'test/.test_optimizer.dart',
        'test/conditional_test.dart',
        'test/mixed_test.dart',
        'test/other_test.dart',
        'test/unknown_test.dart',
      ],
    );
  });

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
