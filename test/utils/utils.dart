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
