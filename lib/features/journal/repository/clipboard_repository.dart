import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:super_clipboard/super_clipboard.dart';

part 'clipboard_repository.g.dart';

/// The platform [SystemClipboard] (null where unsupported), wrapped in a
/// provider so clipboard access can be overridden in tests. Used by the
/// image-paste flow to detect and read pasteable images.
@riverpod
SystemClipboard? clipboardRepository(Ref ref) {
  return SystemClipboard.instance;
}
