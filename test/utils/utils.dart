import 'package:lotti/utils/platform.dart';
import 'package:media_kit/media_kit.dart';

void ensureMpvInitialized() {
  if (isMacOS) {
    MediaKit.ensureInitialized(libmpv: '/opt/homebrew/bin/mpv');
  }
  if (isLinux || isWindows) {
    MediaKit.ensureInitialized();
  }
}

Future<void> waitUntil(
  bool Function() condition,
) async {
  while (!condition()) {
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
}

Future<void> waitUntilAsync(
  Future<bool> Function() condition,
) async {
  while (!await condition()) {
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
}

Future<void> waitSeconds(int seconds) async {
  await Future<void>.delayed(Duration(seconds: seconds));
}
