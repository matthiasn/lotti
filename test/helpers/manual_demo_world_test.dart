import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'manual_demo_world.dart';

void main() {
  final uri = Uri.parse('https://example.invalid/demo-cover.webp');

  test('returns the exact binary stdout from curl', () async {
    late String executable;
    late List<String> arguments;
    final downloader = ManualDemoMediaDownloader(
      run: (receivedExecutable, receivedArguments) async {
        executable = receivedExecutable;
        arguments = receivedArguments;
        return ProcessResult(1, 0, <int>[1, 2, 255], '');
      },
    );

    final bytes = await downloader(uri);

    expect(bytes, <int>[1, 2, 255]);
    expect(executable, 'curl');
    expect(
      arguments,
      containsAllInOrder([
        '--fail',
        '--location',
        '--max-time',
        '30',
        uri.toString(),
      ]),
    );
  });

  test('fetches each immutable URI only once per process', () async {
    var calls = 0;
    final downloader = ManualDemoMediaDownloader(
      run: (executable, arguments) async {
        calls++;
        return ProcessResult(1, 0, <int>[4, 5, 6], '');
      },
    );

    expect(await downloader(uri), <int>[4, 5, 6]);
    expect(await downloader(uri), <int>[4, 5, 6]);
    expect(calls, 1);
  });

  test('surfaces a failed curl process with its exit code', () async {
    final downloader = ManualDemoMediaDownloader(
      run: (executable, arguments) async =>
          ProcessResult(1, 22, <int>[], 'HTTP 404'),
    );

    await expectLater(
      downloader(uri),
      throwsA(
        isA<ProcessException>()
            .having((error) => error.executable, 'executable', 'curl')
            .having((error) => error.errorCode, 'errorCode', 22)
            .having(
              (error) => error.message,
              'message',
              contains('HTTP 404'),
            ),
      ),
    );
  });
}
