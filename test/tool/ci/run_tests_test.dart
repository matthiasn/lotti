import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;

import '../../../tool/ci/run_tests.dart';

void main() {
  for (final status in [0, 17]) {
    test(
      'forwards all suites and selectors, preserving exit status $status',
      () async {
        final root = await Directory.systemTemp.createTemp('test_runner_');
        addTearDown(() => root.delete(recursive: true));
        await Directory(path.join(root.path, 'test')).create();
        await File(
          path.join(root.path, 'test/plain_test.dart'),
        ).writeAsString('void main() {}');
        await File(path.join(root.path, 'test/tagged_test.dart')).writeAsString(
          "@Tags(['performance'])\nlibrary;\nvoid main() {}",
        );
        // A process double records argv and its working directory; no Flutter
        // suite is launched recursively from this test.
        final executable = File(path.join(root.path, 'flutter'));
        await executable.writeAsString('''#!/bin/sh
printf '%s\\n' "\$@" > arguments.txt
pwd > working_directory.txt
exit $status
''');
        final permissions = await Process.run('chmod', ['+x', executable.path]);
        expect(permissions.exitCode, 0);
        final result = await runTestSuites(
          ['--exclude-tags', 'glados || performance', '--shard-index=3'],
          packageRoot: root.path,
          flutterExecutable: executable.path,
        );
        expect(result, status);
        expect(
          await File(path.join(root.path, 'arguments.txt')).readAsLines(),
          [
            'test',
            '--exclude-tags',
            'glados || performance',
            '--shard-index=3',
            'test/.test_optimizer.dart',
            'test/tagged_test.dart',
          ],
        );
        expect(
          (await File(
            path.join(root.path, 'working_directory.txt'),
          ).readAsString()).trim(),
          root.resolveSymbolicLinksSync(),
        );
      },
      skip: Platform.isWindows ? 'Process double uses a POSIX shell' : false,
    );
  }
}
