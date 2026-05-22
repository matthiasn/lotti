import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

typedef MediaProcessRunner =
    Future<ProcessResult> Function(String executable, List<String> arguments);

Future<ProcessResult> _runProcess(
  String executable,
  List<String> arguments,
) => Process.run(executable, arguments);

@visibleForTesting
const fileActionsChannelName = 'com.matthiasn.lotti/file_actions';

const _fileActionsChannel = MethodChannel(fileActionsChannelName);

enum MediaFilePlatform {
  macos,
  linux,
  windows,
  unsupported,
}

class MediaFileActions {
  const MediaFileActions({
    this.methodChannel = _fileActionsChannel,
    this.processRunner = _runProcess,
  });

  final MethodChannel methodChannel;
  final MediaProcessRunner processRunner;

  static MediaFilePlatform currentPlatform() {
    if (Platform.isMacOS) {
      return MediaFilePlatform.macos;
    }
    if (Platform.isLinux) {
      return MediaFilePlatform.linux;
    }
    if (Platform.isWindows) {
      return MediaFilePlatform.windows;
    }
    return MediaFilePlatform.unsupported;
  }

  Future<void> revealInFileManager(
    String filePath, {
    MediaFilePlatform? platform,
  }) async {
    if (filePath.trim().isEmpty) {
      throw ArgumentError.value(filePath, 'filePath', 'Must not be empty');
    }

    switch (platform ?? currentPlatform()) {
      case MediaFilePlatform.macos:
        await _invokeMacosFileAction('revealInFileManager', filePath);
      case MediaFilePlatform.windows:
        await _runChecked('explorer.exe', <String>['/select,"$filePath"']);
      case MediaFilePlatform.linux:
        await _revealOnLinux(filePath);
      case MediaFilePlatform.unsupported:
        throw UnsupportedError(
          'Revealing files is unsupported on this platform',
        );
    }
  }

  Future<void> _invokeMacosFileAction(String method, String filePath) async {
    await methodChannel.invokeMethod<bool>(method, <String, String>{
      'path': filePath,
    });
  }

  Future<void> _revealOnLinux(String filePath) async {
    final uri = Uri.file(filePath).toString();
    final didShowItem = await _tryRun('dbus-send', <String>[
      '--session',
      '--dest=org.freedesktop.FileManager1',
      '--type=method_call',
      '/org/freedesktop/FileManager1',
      'org.freedesktop.FileManager1.ShowItems',
      'array:string:$uri',
      'string:',
    ]);

    if (didShowItem) {
      return;
    }

    await _runChecked('xdg-open', <String>[File(filePath).parent.path]);
  }

  Future<bool> _tryRun(String executable, List<String> arguments) async {
    try {
      final result = await processRunner(executable, arguments);
      return result.exitCode == 0;
    } on Object {
      return false;
    }
  }

  Future<void> _runChecked(String executable, List<String> arguments) async {
    final result = await processRunner(executable, arguments);
    if (result.exitCode == 0) {
      return;
    }

    final stderr = '${result.stderr}'.trim();
    final stdout = '${result.stdout}'.trim();
    final message = stderr.isNotEmpty ? stderr : stdout;
    throw ProcessException(
      executable,
      arguments,
      message,
      result.exitCode,
    );
  }
}
