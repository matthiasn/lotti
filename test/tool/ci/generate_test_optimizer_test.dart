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
      'excluded_set': "@Tags({'eval-live'})\nlibrary;",
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
    expect(contents, isNot(contains('excluded_set_test.dart')));
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

  test(
    'partitions every suite exactly once before rendering imports',
    () async {
      final root = Directory.systemTemp.createTempSync('test_shards_');
      addTearDown(() => root.deleteSync(recursive: true));
      final directory = Directory(path.join(root.path, 'test'))..createSync();
      final names = <String>[];
      for (var i = 0; i < 12; i++) {
        final name = 'suite_${i}_test.dart';
        names.add(name);
        File(path.join(directory.path, name)).writeAsStringSync(
          '${i.isEven ? "@Timeout(Duration(minutes: 2))\nlibrary;" : ""}\n'
          '// ${'x' * (100 + i * 30)}\nvoid main() {}',
        );
      }
      final seen = <String>[];
      final rendered = <String>[];
      for (var shard = 0; shard < 3; shard++) {
        final output = await generateTestOptimizer(
          packageRoot: root.path,
          totalShards: 3,
          shardIndex: shard,
        );
        final bundle = output.readAsStringSync();
        final targets =
            (jsonDecode(
                      File(
                        path.join(root.path, testTargetsRelativePath),
                      ).readAsStringSync(),
                    )
                    as List<dynamic>)
                .cast<String>();
        final assigned = names
            .where(
              (name) =>
                  bundle.contains("import '$name'") ||
                  targets.contains('test/$name'),
            )
            .toList();
        expect(assigned, isNotEmpty);
        expect(assigned.length, lessThan(names.length));
        for (final name in assigned) {
          final annotated = int.parse(name.split('_')[1]).isEven;
          expect(targets.contains('test/$name'), annotated);
          expect(bundle.contains("import '$name'"), !annotated);
        }
        seen.addAll(assigned);
        rendered.add(bundle);
      }
      expect(seen, unorderedEquals(names));
      final again = await generateTestOptimizer(
        packageRoot: root.path,
        totalShards: 3,
        shardIndex: 1,
      );
      expect(again.readAsStringSync(), rendered[1]);
    },
  );

  for (final (total, index) in [(0, 0), (2, -1), (2, 2)]) {
    test('rejects invalid shard $index of $total', () async {
      await expectLater(
        generateTestOptimizer(
          packageRoot: '.',
          totalShards: total,
          shardIndex: index,
        ),
        throwsArgumentError,
      );
    });
  }

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
