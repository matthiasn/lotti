import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:super_clipboard/super_clipboard.dart';

/// The platform [SystemClipboard] (null where unsupported), wrapped in a
/// provider so clipboard access can be overridden in tests. Used by the
/// image-paste flow to detect and read pasteable images.
final Provider<SystemClipboard?> clipboardRepositoryProvider =
    Provider.autoDispose<SystemClipboard?>(
      clipboardRepository,
      name: 'clipboardRepositoryProvider',
    );
SystemClipboard? clipboardRepository(Ref ref) {
  return SystemClipboard.instance;
}
