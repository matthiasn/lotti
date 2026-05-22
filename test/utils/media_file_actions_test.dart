import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/utils/media_file_actions.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MediaFileActions', () {
    test('reveals files on macOS through the native channel', () async {
      const channel = MethodChannel(fileActionsChannelName);
      final calls = <MethodCall>[];

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            return true;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );

      await const MediaFileActions().revealInFileManager(
        '/tmp/audio.m4a',
        platform: MediaFilePlatform.macos,
      );

      expect(calls, hasLength(1));
      expect(calls.single.method, 'revealInFileManager');
      expect(calls.single.arguments, {'path': '/tmp/audio.m4a'});
    });

    test('reveals files on Windows with Explorer selection', () async {
      final runner = _RecordingProcessRunner();
      final actions = MediaFileActions(processRunner: runner.call);

      await actions.revealInFileManager(
        r'C:\Users\Test User\audio note.m4a',
        platform: MediaFilePlatform.windows,
      );

      expect(runner.calls, [
        const _ProcessCall(
          'explorer.exe',
          [r'/select,"C:\Users\Test User\audio note.m4a"'],
        ),
      ]);
    });

    test(
      'reveals files on Linux through FileManager1 when available',
      () async {
        final runner = _RecordingProcessRunner();
        final actions = MediaFileActions(processRunner: runner.call);

        await actions.revealInFileManager(
          '/home/test/audio.m4a',
          platform: MediaFilePlatform.linux,
        );

        expect(runner.calls, [
          const _ProcessCall(
            'dbus-send',
            [
              '--session',
              '--dest=org.freedesktop.FileManager1',
              '--type=method_call',
              '/org/freedesktop/FileManager1',
              'org.freedesktop.FileManager1.ShowItems',
              'array:string:file:///home/test/audio.m4a',
              'string:',
            ],
          ),
        ]);
      },
    );

    test('falls back to opening the parent folder on Linux', () async {
      final runner = _RecordingProcessRunner(exitCodes: [1, 0]);
      final actions = MediaFileActions(processRunner: runner.call);

      await actions.revealInFileManager(
        '/home/test/audio.m4a',
        platform: MediaFilePlatform.linux,
      );

      expect(runner.calls, [
        const _ProcessCall(
          'dbus-send',
          [
            '--session',
            '--dest=org.freedesktop.FileManager1',
            '--type=method_call',
            '/org/freedesktop/FileManager1',
            'org.freedesktop.FileManager1.ShowItems',
            'array:string:file:///home/test/audio.m4a',
            'string:',
          ],
        ),
        const _ProcessCall('xdg-open', ['/home/test']),
      ]);
    });

    test('throws when a process action fails', () async {
      final runner = _RecordingProcessRunner(exitCodes: [7]);
      final actions = MediaFileActions(processRunner: runner.call);

      await expectLater(
        actions.revealInFileManager(
          r'C:\Users\Test User\audio note.m4a',
          platform: MediaFilePlatform.windows,
        ),
        throwsA(isA<ProcessException>()),
      );
    });
  });
}

class _RecordingProcessRunner {
  _RecordingProcessRunner({this.exitCodes});

  final List<int>? exitCodes;
  final calls = <_ProcessCall>[];

  Future<ProcessResult> call(
    String executable,
    List<String> arguments,
  ) async {
    calls.add(_ProcessCall(executable, List<String>.from(arguments)));
    final index = calls.length - 1;
    final configuredExitCodes = exitCodes;
    final exitCode =
        configuredExitCodes != null && index < configuredExitCodes.length
        ? configuredExitCodes[index]
        : 0;
    return ProcessResult(index, exitCode, '', 'failed');
  }
}

@immutable
class _ProcessCall {
  const _ProcessCall(this.executable, this.arguments);

  final String executable;
  final List<String> arguments;

  @override
  bool operator ==(Object other) =>
      other is _ProcessCall &&
      other.executable == executable &&
      _listEquals(other.arguments, arguments);

  @override
  int get hashCode => Object.hash(executable, Object.hashAll(arguments));

  @override
  String toString() => '_ProcessCall($executable, $arguments)';
}

bool _listEquals(List<String> a, List<String> b) {
  if (a.length != b.length) {
    return false;
  }

  for (var index = 0; index < a.length; index += 1) {
    if (a[index] != b[index]) {
      return false;
    }
  }

  return true;
}
