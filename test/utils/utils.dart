import 'package:lotti/utils/platform.dart';
import 'package:media_kit/src/libmpv/core/native_library.dart';

void ensureMpvInitialized() {
  if (isMacOS) {
    NativeLibrary.ensureInitialized(libmpv: '/opt/homebrew/bin/mpv');
  }
  if (isLinux || isWindows) {
    NativeLibrary.ensureInitialized();
  }
}
